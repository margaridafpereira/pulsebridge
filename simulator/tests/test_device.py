import asyncio
import unittest

from pulsebridge_sim import protocol as p
from pulsebridge_sim.device import Device, DeviceConfig


class Client:
    def __init__(self, reader, writer):
        self.reader, self.writer = reader, writer
        self.decoder = p.FrameDecoder()
        self.pending: list[p.Frame] = []
        self.seq = 0

    async def send(self, msg_type) -> int:
        self.seq += 1
        self.writer.write(p.encode(p.Frame(msg_type, self.seq)))
        await self.writer.drain()
        return self.seq

    async def next(self, msg_type, timeout=2.0) -> p.Frame:
        loop = asyncio.get_running_loop()
        end = loop.time() + timeout
        while True:
            for i, frame in enumerate(self.pending):
                if frame.type == msg_type:
                    return self.pending.pop(i)
            data = await asyncio.wait_for(self.reader.read(4096), end - loop.time())
            if not data:
                raise ConnectionError("link closed")
            self.pending += self.decoder.feed(data)

    async def collect(self, seconds) -> list[p.Frame]:
        loop = asyncio.get_running_loop()
        end = loop.time() + seconds
        frames, self.pending = self.pending, []
        while (remaining := end - loop.time()) > 0:
            try:
                data = await asyncio.wait_for(self.reader.read(4096), remaining)
            except asyncio.TimeoutError:
                break
            if not data:
                break
            frames += self.decoder.feed(data)
        return frames


class DeviceTest(unittest.IsolatedAsyncioTestCase):
    async def start(self, **overrides) -> Client:
        config = DeviceConfig(speed=20, seed=1, **overrides)
        self.device = Device(config)
        self.server = await self.device.serve("127.0.0.1", 0)
        port = self.server.sockets[0].getsockname()[1]
        client = Client(*await asyncio.open_connection("127.0.0.1", port))
        self.addAsyncCleanup(self.stop, client)
        return client

    async def stop(self, client):
        client.writer.close()
        self.server.close()
        await self.server.wait_closed()

    async def test_sends_hello_and_battery_on_connect(self):
        client = await self.start()
        hello = p.Hello.unpack((await client.next(p.MessageType.HELLO)).payload)
        self.assertEqual(hello.sample_rate, 250)
        battery = p.Battery.unpack((await client.next(p.MessageType.BATTERY)).payload)
        self.assertEqual(battery.percent, 100)

    async def test_does_not_stream_before_start(self):
        client = await self.start()
        frames = await client.collect(0.3)
        self.assertNotIn(p.MessageType.ECG_SAMPLES, {f.type for f in frames})

    async def test_start_streams_contiguous_samples_and_heart_rate(self):
        client = await self.start()
        seq = await client.send(p.MessageType.START_STREAM)
        ack = p.Ack.unpack((await client.next(p.MessageType.ACK)).payload)
        self.assertEqual(ack, p.Ack(seq, p.AckResult.OK))

        frames = await client.collect(0.5)  # about 10 s of simulated time
        ecg = [p.EcgSamples.unpack(f.payload) for f in frames if f.type == p.MessageType.ECG_SAMPLES]
        self.assertGreater(len(ecg), 20)
        for prev, cur in zip(ecg, ecg[1:]):
            self.assertEqual(cur.first_index, prev.first_index + len(prev.samples))
        rates = [p.HeartRate.unpack(f.payload).bpm for f in frames if f.type == p.MessageType.HEART_RATE]
        self.assertTrue(rates)
        self.assertTrue(all(55 < bpm < 90 for bpm in rates), rates)

    async def test_start_twice_is_rejected(self):
        client = await self.start()
        await client.send(p.MessageType.START_STREAM)
        await client.next(p.MessageType.ACK)
        seq = await client.send(p.MessageType.START_STREAM)
        ack = p.Ack.unpack((await client.next(p.MessageType.ACK)).payload)
        self.assertEqual(ack, p.Ack(seq, p.AckResult.INVALID_STATE))

    async def test_stop_ends_the_stream(self):
        client = await self.start()
        await client.send(p.MessageType.START_STREAM)
        await client.next(p.MessageType.ACK)
        seq = await client.send(p.MessageType.STOP_STREAM)
        ack = p.Ack.unpack((await client.next(p.MessageType.ACK)).payload)
        self.assertEqual(ack, p.Ack(seq, p.AckResult.OK))
        await client.collect(0.1)  # drain frames already in flight
        frames = await client.collect(0.3)
        self.assertNotIn(p.MessageType.ECG_SAMPLES, {f.type for f in frames})

    async def test_unknown_command_is_nacked(self):
        client = await self.start()
        seq = await client.send(0x55)
        ack = p.Ack.unpack((await client.next(p.MessageType.ACK)).payload)
        self.assertEqual(ack, p.Ack(seq, p.AckResult.UNKNOWN_COMMAND))

    async def test_second_client_is_rejected(self):
        await self.start()
        port = self.server.sockets[0].getsockname()[1]
        reader, writer = await asyncio.open_connection("127.0.0.1", port)
        self.assertEqual(await asyncio.wait_for(reader.read(), 2), b"")
        writer.close()

    async def test_corrupted_frames_are_caught_by_crc(self):
        client = await self.start(corrupt_rate=0.3)
        await client.send(p.MessageType.START_STREAM)
        await client.collect(0.5)
        self.assertGreater(client.decoder.crc_errors + client.decoder.skipped_bytes, 0)

    async def test_dropped_frames_leave_sequence_gaps(self):
        client = await self.start(drop_rate=0.2)
        await client.send(p.MessageType.START_STREAM)
        frames = await client.collect(0.5)
        gaps = sum(1 for a, b in zip(frames, frames[1:]) if b.seq != (a.seq + 1) & 0xFFFF)
        self.assertGreater(gaps, 0)

    async def test_link_loss_closes_the_connection(self):
        client = await self.start(disconnect_after=2)
        with self.assertRaises(ConnectionError):
            await client.next(p.MessageType.ECG_SAMPLES, timeout=2)

    async def test_lead_off_raises_and_clears_alarm(self):
        client = await self.start(lead_off_every=4)
        await client.send(p.MessageType.START_STREAM)
        frames = await client.collect(0.5)
        alarms = [p.Alarm.unpack(f.payload) for f in frames if f.type == p.MessageType.ALARM]
        self.assertIn(p.Alarm(p.AlarmCode.LEAD_OFF, True), alarms)
        self.assertIn(p.Alarm(p.AlarmCode.LEAD_OFF, False), alarms)

    async def test_low_battery_alarm(self):
        client = await self.start(battery=16, battery_drain_per_min=30)
        await client.send(p.MessageType.START_STREAM)
        frames = await client.collect(0.5)
        alarms = [p.Alarm.unpack(f.payload) for f in frames if f.type == p.MessageType.ALARM]
        self.assertIn(p.Alarm(p.AlarmCode.LOW_BATTERY, True), alarms)


if __name__ == "__main__":
    unittest.main()
