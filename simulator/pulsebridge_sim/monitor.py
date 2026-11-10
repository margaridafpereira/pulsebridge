"""Minimal command-line client: python -m pulsebridge_sim.monitor [--seconds N]

Connects to the device, starts streaming and prints what arrives. 
"""
from __future__ import annotations

import argparse
import asyncio

from . import protocol as p


async def monitor(host: str, port: int, seconds: float) -> None:
    reader, writer = await asyncio.open_connection(host, port)
    decoder = p.FrameDecoder()
    writer.write(p.encode(p.Frame(p.MessageType.START_STREAM, 1)))
    await writer.drain()

    expected_index = None
    last_seq = None
    samples = lost_samples = seq_gaps = 0
    loop = asyncio.get_running_loop()
    end = loop.time() + seconds
    try:
        while (remaining := end - loop.time()) > 0:
            try:
                data = await asyncio.wait_for(reader.read(4096), remaining)
            except asyncio.TimeoutError:
                break
            if not data:
                print("link lost")
                break
            for frame in decoder.feed(data):
                if last_seq is not None and frame.seq != (last_seq + 1) & 0xFFFF:
                    seq_gaps += 1
                last_seq = frame.seq
                if frame.type == p.MessageType.HELLO:
                    print("hello:", p.Hello.unpack(frame.payload))
                elif frame.type == p.MessageType.ECG_SAMPLES:
                    ecg = p.EcgSamples.unpack(frame.payload)
                    if expected_index is not None and ecg.first_index > expected_index:
                        lost_samples += ecg.first_index - expected_index
                    expected_index = ecg.first_index + len(ecg.samples)
                    samples += len(ecg.samples)
                elif frame.type == p.MessageType.HEART_RATE:
                    hr = p.HeartRate.unpack(frame.payload)
                    print(f"heart rate: {hr.bpm} bpm (RR {hr.rr_ms} ms)")
                elif frame.type == p.MessageType.BATTERY:
                    print(f"battery: {p.Battery.unpack(frame.payload).percent}%")
                elif frame.type == p.MessageType.ALARM:
                    alarm = p.Alarm.unpack(frame.payload)
                    print(f"alarm: {alarm.code.name} {'ON' if alarm.active else 'cleared'}")
                elif frame.type == p.MessageType.ACK:
                    print("ack:", p.Ack.unpack(frame.payload))
    finally:
        writer.close()
    print(f"\n{samples} samples, {lost_samples} lost, {seq_gaps} sequence gaps, "
          f"{decoder.crc_errors} CRC errors, {decoder.skipped_bytes} bytes skipped")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(prog="pulsebridge_sim.monitor")
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", type=int, default=7878)
    parser.add_argument("--seconds", type=float, default=10.0)
    args = parser.parse_args()
    asyncio.run(monitor(args.host, args.port, args.seconds))
