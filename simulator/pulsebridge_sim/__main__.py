"""Run the simulated device: python -m pulsebridge_sim [options]"""
from __future__ import annotations

import argparse
import asyncio
import logging

from .device import Device, DeviceConfig


def parse_args(argv: list[str] | None = None) -> tuple[argparse.Namespace, DeviceConfig]:
    parser = argparse.ArgumentParser(prog="pulsebridge_sim", description="Simulated PulseBridge ECG device.")
    parser.add_argument("--host", default="0.0.0.0")
    parser.add_argument("--port", type=int, default=7878)
    parser.add_argument("--heart-rate", type=float, default=72.0, help="mean heart rate in bpm")
    parser.add_argument("--sample-rate", type=int, default=250, help="ECG samples per second")
    parser.add_argument("--battery", type=float, default=100.0, help="starting battery percent")
    parser.add_argument("--battery-drain", type=float, default=0.5, help="percent per minute while streaming")
    parser.add_argument("--drop-rate", type=float, default=0.0, help="probability of dropping a frame")
    parser.add_argument("--corrupt-rate", type=float, default=0.0, help="probability of corrupting a frame")
    parser.add_argument("--disconnect-after", type=float, help="drop the link N seconds after connect")
    parser.add_argument("--lead-off-every", type=float, help="simulate a lead-off episode every N seconds")
    parser.add_argument("--speed", type=float, default=1.0, help="time multiplier, e.g. 10 for 10x")
    parser.add_argument("--seed", type=int, help="seed for reproducible runs")
    parser.add_argument("--record", help="play a MIT-BIH record instead of synthetic ECG, e.g. data/119")
    parser.add_argument("--firmware", default="1.0.0", help="firmware version the device starts with")
    parser.add_argument("--fw-drop-after", type=int, metavar="BYTES",
                        help="drop the link once during a firmware update, after BYTES (tests resume)")
    parser.add_argument("--fw-corrupt", action="store_true",
                        help="simulate a flash write error, so a firmware image fails its checksum")
    args = parser.parse_args(argv)
    config = DeviceConfig(
        sample_rate=args.sample_rate, heart_rate=args.heart_rate, battery=args.battery,
        battery_drain_per_min=args.battery_drain, drop_rate=args.drop_rate,
        corrupt_rate=args.corrupt_rate, disconnect_after=args.disconnect_after,
        lead_off_every=args.lead_off_every, speed=args.speed, seed=args.seed, record=args.record,
        firmware=args.firmware, fw_drop_after=args.fw_drop_after, fw_corrupt=args.fw_corrupt,
    )
    return args, config


async def main(argv: list[str] | None = None) -> None:
    args, config = parse_args(argv)
    server = await Device(config).serve(args.host, args.port)
    async with server:
        await server.serve_forever()


if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(name)s: %(message)s")
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        pass
