"""Exports a MIT-BIH excerpt for the app's in-browser demo device.

python -m pulsebridge_sim.demo_asset data/119 ../app/assets/demo/mitbih119.bin --minutes 5

Layout (little-endian): u32 sample_rate, u32 n_samples, i16 samples[n] (µV),
u32 n_beats, then per beat u32 sample index and u16 RR in ms.
"""
from __future__ import annotations

import argparse
import struct
from pathlib import Path

from .mitbih import RecordPlayer


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("record")
    parser.add_argument("output", type=Path)
    parser.add_argument("--minutes", type=float, default=5)
    parser.add_argument("--rate", type=int, default=250)
    args = parser.parse_args()

    player = RecordPlayer(args.record, args.rate)
    total = int(args.minutes * 60 * args.rate)
    samples: list[int] = []
    beats: list[tuple[int, int]] = []
    while len(samples) < total:
        chunk, chunk_beats = player.next_samples(args.rate // 10)

        samples += [max(-32768, min(32767, int(v))) for v in chunk]
        for b in chunk_beats:
            beats.append((round(b.time_s * args.rate), b.rr_ms))
    samples = samples[:total]
    beats = [(i, rr) for i, rr in beats if i < total]

    out = bytearray(struct.pack("<II", args.rate, len(samples)))
    out += struct.pack(f"<{len(samples)}h", *samples)
    out += struct.pack("<I", len(beats))
    for i, rr in beats:
        out += struct.pack("<IH", i, min(rr, 65535))
    args.output.write_bytes(out)
    print(f"{args.output}: {len(samples)} samples, {len(beats)} beats, {len(out) // 1024} KB")


if __name__ == "__main__":
    main()
