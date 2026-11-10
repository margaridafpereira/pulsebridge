"""Simulated ECG device that speaks the PulseBridge protocol over TCP.

Behaves like the real hardware would: one client at a time, HELLO on connect,
streaming only after START_STREAM, an ACK for every command, a draining
battery, firmware updates through a bootloader, and optional faults (dropped
or corrupted frames, lost link, lead-off episodes, a link that drops during a
firmware transfer, a flash write error) for testing the app's error handling.
"""
from __future__ import annotations

import asyncio
import logging
import random
import time
from dataclasses import dataclass

from . import protocol as p
from . import firmware as fw
from .ecg import EcgGenerator
from .mitbih import RecordPlayer

log = logging.getLogger("pulsebridge.device")

FRAMES_PER_SECOND = 10
LOW_BATTERY_PERCENT = 15
LEAD_OFF_DURATION_S = 3.0


@dataclass
class DeviceConfig:
    device_id: str = "PB-SIM-0001"
    firmware: str = "1.0.0"
    sample_rate: int = 250
    heart_rate: float = 72.0
    battery: float = 100.0
    battery_drain_per_min: float = 0.5
    drop_rate: float = 0.0          # probability of silently dropping a frame
    corrupt_rate: float = 0.0       # probability of flipping a byte in a frame
    disconnect_after: float | None = None  # seconds after connect, simulated time
    lead_off_every: float | None = None    # seconds between lead-off episodes
    speed: float = 1.0              # >1 runs faster than real time (tests, demos)
    seed: int | None = None
    record: str | None = None       # MIT-BIH record path; synthetic ECG when unset
    fw_drop_after: int | None = None  # fault: drop the link once after this many firmware bytes
    fw_corrupt: bool = False        # fault: flash write error, so the image fails its CRC
    boot_seconds: float = 2.0       # restart time after installing firmware


class Device:
    def __init__(self, config: DeviceConfig) -> None:
        self.cfg = config
        self.battery = config.battery
        self._record = RecordPlayer(config.record, config.sample_rate) if config.record else None
        self._rng = random.Random(config.seed)
        self._seq = 0
        self._client_connected = False
        self._low_battery_alarm = False
        self.bootloader = fw.Bootloader(config.firmware, corrupt_flash=config.fw_corrupt)
        self._booting_until = 0.0
        self._fw_dropped = False

    async def serve(self, host: str = "0.0.0.0", port: int = 7878) -> asyncio.Server:
        server = await asyncio.start_server(self._handle_client, host, port)
        log.info("listening on %s", ", ".join(str(s.getsockname()) for s in server.sockets))
        return server

    async def _handle_client(self, reader: asyncio.StreamReader, writer: asyncio.StreamWriter) -> None:
        peer = writer.get_extra_info("peername")
        if time.monotonic() < self._booting_until:
            log.info("rejecting %s: restarting after a firmware update", peer)
            writer.close()
            return
        if self._client_connected:
            log.warning("rejecting %s: a client is already connected", peer)
            writer.close()
            return
        self._client_connected = True
        log.info("client connected: %s", peer)

        stream_task: asyncio.Task | None = None
        watchdog = asyncio.create_task(self._link_loss(writer)) if self.cfg.disconnect_after else None
        decoder = p.FrameDecoder()
        try:
            self._send(writer, p.MessageType.HELLO,
                       p.Hello(self.cfg.device_id, self.bootloader.running, self.cfg.sample_rate).pack())
            self._send(writer, p.MessageType.BATTERY, p.Battery(int(self.battery)).pack())
            await writer.drain()

            while data := await reader.read(4096):
                for frame in decoder.feed(data):
                    if frame.type == p.MessageType.START_STREAM:
                        if stream_task and not stream_task.done():
                            self._ack(writer, frame, p.AckResult.INVALID_STATE)
                        else:
                            self._ack(writer, frame, p.AckResult.OK)
                            stream_task = asyncio.create_task(self._stream(writer))
                    elif frame.type == p.MessageType.STOP_STREAM:
                        if stream_task and not stream_task.done():
                            stream_task.cancel()
                            self._ack(writer, frame, p.AckResult.OK)
                        else:
                            self._ack(writer, frame, p.AckResult.INVALID_STATE)
                    elif frame.type == p.MessageType.PING:
                        self._ack(writer, frame, p.AckResult.OK)
                    elif frame.type in (p.MessageType.FW_BEGIN, p.MessageType.FW_CHUNK,
                                        p.MessageType.FW_COMMIT, p.MessageType.FW_ABORT):
                        streaming = stream_task is not None and not stream_task.done()
                        self._firmware(writer, frame, streaming)
                    else:
                        self._ack(writer, frame, p.AckResult.UNKNOWN_COMMAND)
                await writer.drain()
        except (ConnectionError, asyncio.IncompleteReadError):
            pass
        finally:
            for task in (stream_task, watchdog):
                if task:
                    task.cancel()
            writer.close()
            self._client_connected = False
            log.info("client disconnected: %s (decoder: %d CRC errors)", peer, decoder.crc_errors)

    async def _stream(self, writer: asyncio.StreamWriter) -> None:
        loop = asyncio.get_running_loop()
        if self._record:
            self._record.rewind()
            generator = self._record
        else:
            generator = EcgGenerator(self.cfg.sample_rate, self.cfg.heart_rate, seed=self._rng.random())
        per_frame = self.cfg.sample_rate // FRAMES_PER_SECOND
        interval = per_frame / self.cfg.sample_rate
        sample_index = 0
        lead_off = False
        deadline = loop.time()
        log.info("streaming started")
        try:
            while True:
                sim_time = sample_index / self.cfg.sample_rate
                samples, beats = generator.next_samples(per_frame)

                lead_off_now = self._in_lead_off(sim_time)
                if lead_off_now != lead_off:
                    lead_off = lead_off_now
                    self._send(writer, p.MessageType.ALARM, p.Alarm(p.AlarmCode.LEAD_OFF, lead_off).pack())
                if lead_off:
                    # Electrode off the skin: no cardiac signal, just noise.
                    samples = [round(self._rng.gauss(0, 40)) for _ in samples]
                    beats = []

                self._send(writer, p.MessageType.ECG_SAMPLES, p.EcgSamples(sample_index, tuple(samples)).pack())
                for beat in beats:
                    self._send(writer, p.MessageType.HEART_RATE, p.HeartRate(beat.bpm, beat.rr_ms).pack())
                sample_index += per_frame
                self._drain_battery(writer, interval)
                await writer.drain()

                deadline += interval / self.cfg.speed
                await asyncio.sleep(max(0.0, deadline - loop.time()))
        finally:
            log.info("streaming stopped after %d samples", sample_index)

    def _in_lead_off(self, sim_time: float) -> bool:
        every = self.cfg.lead_off_every
        return bool(every) and sim_time >= every and sim_time % every < LEAD_OFF_DURATION_S

    def _drain_battery(self, writer: asyncio.StreamWriter, seconds: float) -> None:
        before = int(self.battery)
        self.battery = max(0.0, self.battery - self.cfg.battery_drain_per_min * seconds / 60)
        if int(self.battery) != before:
            self._send(writer, p.MessageType.BATTERY, p.Battery(int(self.battery)).pack())
        if self.battery <= LOW_BATTERY_PERCENT and not self._low_battery_alarm:
            self._low_battery_alarm = True
            self._send(writer, p.MessageType.ALARM, p.Alarm(p.AlarmCode.LOW_BATTERY, True).pack())

    def _firmware(self, writer: asyncio.StreamWriter, frame: p.Frame, streaming: bool) -> None:
        """Firmware commands are acknowledged with FW_STATUS, which also tells
        the app how many bytes the device holds."""
        boot = self.bootloader
        if streaming and frame.type != p.MessageType.FW_ABORT:
            status = fw.FwStatus(fw.FwState.REJECTED, len(boot.buffer), "stop streaming before updating")
        elif frame.type == p.MessageType.FW_BEGIN:
            status = boot.begin(fw.FwBegin.unpack(frame.payload))
        elif frame.type == p.MessageType.FW_CHUNK:
            status = boot.chunk(fw.FwChunk.unpack(frame.payload))
            drop = self.cfg.fw_drop_after
            if drop is not None and not self._fw_dropped and status.received >= drop:
                self._fw_dropped = True
                log.warning("simulating link loss during the firmware transfer at %d bytes", status.received)
                writer.transport.abort()
                return
        elif frame.type == p.MessageType.FW_COMMIT:
            status = boot.commit()
        else:
            status = boot.abort()
        self._send(writer, p.MessageType.FW_STATUS, status.pack())
        if status.state == fw.FwState.INSTALLED:
            log.info("firmware %s installed, restarting", boot.running)
            asyncio.get_running_loop().call_later(0.3, self._restart, writer)
        elif status.state == fw.FwState.REJECTED:
            log.warning("firmware update rejected: %s", status.detail)

    def _restart(self, writer: asyncio.StreamWriter) -> None:
        self._booting_until = time.monotonic() + self.cfg.boot_seconds / self.cfg.speed
        writer.transport.abort()

    async def _link_loss(self, writer: asyncio.StreamWriter) -> None:
        await asyncio.sleep(self.cfg.disconnect_after / self.cfg.speed)
        log.warning("simulating link loss")
        writer.transport.abort()

    def _ack(self, writer: asyncio.StreamWriter, command: p.Frame, result: p.AckResult) -> None:
        self._send(writer, p.MessageType.ACK, p.Ack(command.seq, result).pack())

    def _send(self, writer: asyncio.StreamWriter, msg_type: p.MessageType, payload: bytes) -> None:
        self._seq = (self._seq + 1) & 0xFFFF
        data = bytearray(p.encode(p.Frame(msg_type, self._seq, payload)))
        if self._rng.random() < self.cfg.drop_rate:
            return  
        if self._rng.random() < self.cfg.corrupt_rate:
            data[self._rng.randrange(len(p.SYNC), len(data))] ^= 0xFF
        writer.write(bytes(data))
