"""Plays back real ECG recordings from the MIT-BIH Arrhythmia Database.

Reads the WFDB files directly (header, format 212 signal, MIT annotations) with
the standard library only. Download records with:

    python -m pulsebridge_sim.mitbih 100 119 201

Moody GB, Mark RG. The impact of the MIT-BIH Arrhythmia Database.
IEEE Eng in Med and Biol 20(3):45-50 (2001). PhysioNet, ODC-By 1.0 licence.
"""
from __future__ import annotations

import argparse
import urllib.request
from dataclasses import dataclass
from pathlib import Path

from .ecg import Beat

BASE_URL = "https://physionet.org/files/mitdb/1.0.0/"
DATA_DIR = Path(__file__).resolve().parent.parent / "data"

# Annotation codes that mark a beat (WFDB isqrs table).
_BEAT_CODES = {1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 25, 30, 34, 35, 38}
_SKIP, _NUM, _SUB, _CHN, _AUX = 59, 60, 61, 62, 63


@dataclass(frozen=True)
class Header:
    record: str
    sample_rate: int
    length: int
    gain: float       # ADC units per mV, first signal
    baseline: int     # ADC value for 0 mV, first signal
    signals: int
    lead: str


def read_header(path: Path) -> Header:
    lines = [line for line in path.read_text().splitlines() if line and not line.startswith("#")]
    record, signals, sample_rate, length = lines[0].split()[:4]
    fields = lines[1].split()
    if fields[1] != "212":
        raise ValueError(f"unsupported signal format {fields[1]}")
    gain = float(fields[2].split("(")[0].split("/")[0])
    baseline = int(fields[4])
    return Header(record, int(sample_rate.split("/")[0]), int(length), gain, baseline, int(signals), fields[-1])


def decode_212(data: bytes, signals: int, channel: int = 0) -> list[int]:
    """Format 212: pairs of 12-bit two's-complement samples packed into 3 bytes,
    channels interleaved."""
    values = []
    for i in range(0, len(data) - 2, 3):
        b0, b1, b2 = data[i], data[i + 1], data[i + 2]
        values.append(b0 | ((b1 & 0x0F) << 8))
        values.append(b2 | ((b1 & 0xF0) << 4))
    values = [v - 4096 if v & 0x800 else v for v in values]
    return values[channel::signals]


def decode_annotations(data: bytes) -> list[tuple[int, int]]:
    """MIT annotation format: returns (sample index, code) for every annotation."""
    result = []
    sample = 0
    i = 0
    while i + 1 < len(data):
        word = data[i] | (data[i + 1] << 8)
        code, value = word >> 10, word & 0x3FF
        i += 2
        if code == 0 and value == 0:
            break
        if code == _SKIP:
            # 32-bit interval stored as two 16-bit words, high word first.
            high = data[i] | (data[i + 1] << 8)
            low = data[i + 2] | (data[i + 3] << 8)
            interval = (high << 16) | low
            sample += interval - (1 << 32) if interval & 0x80000000 else interval
            i += 4
        elif code == _AUX:
            i += value + (value & 1)
        elif code not in (_NUM, _SUB, _CHN):  # those three only modify the next annotation
            sample += value
            result.append((sample, code))
    return result


class RecordPlayer:
    """Same interface as EcgGenerator: next_samples(count) -> (samples µV, beats).

    Resamples the record to the device's sample rate and loops at the end.
    Heart rate comes from the cardiologists' beat annotations, so arrhythmias
    in the recording show up as real RR irregularity.
    """

    def __init__(self, record_path: str | Path, sample_rate: int = 250) -> None:
        base = Path(record_path)
        header = read_header(base.with_suffix(".hea"))
        raw = decode_212(base.with_suffix(".dat").read_bytes(), header.signals)
        self.header = header
        self.sample_rate = sample_rate
        self._signal_uv = [(v - header.baseline) / header.gain * 1000 for v in raw]
        self._beat_times = [s / header.sample_rate
                            for s, code in decode_annotations(base.with_suffix(".atr").read_bytes())
                            if code in _BEAT_CODES]
        self._duration = len(self._signal_uv) / header.sample_rate
        self.rewind()

    def rewind(self) -> None:
        self._index = 0
        self._next_beat = 1  # first beat has no RR interval
        self._loop_offset = 0.0

    def next_samples(self, count: int) -> tuple[list[int], list[Beat]]:
        samples: list[int] = []
        beats: list[Beat] = []
        source_rate = self.header.sample_rate
        for _ in range(count):
            t = self._index / self.sample_rate - self._loop_offset
            if t >= self._duration:
                self._loop_offset += self._duration
                self._next_beat = 1
                t -= self._duration
            # Linear interpolation from the record's rate to ours.
            pos = t * source_rate
            i = int(pos)
            frac = pos - i
            a = self._signal_uv[i]
            b = self._signal_uv[min(i + 1, len(self._signal_uv) - 1)]
            samples.append(max(-32768, min(32767, round(a + (b - a) * frac))))

            while self._next_beat < len(self._beat_times) and self._beat_times[self._next_beat] <= t:
                rr = self._beat_times[self._next_beat] - self._beat_times[self._next_beat - 1]
                beats.append(Beat(self._loop_offset + self._beat_times[self._next_beat],
                                  min(255, round(60 / rr)), round(rr * 1000)))
                self._next_beat += 1
            self._index += 1
        return samples, beats


def download(records: list[str], target: Path = DATA_DIR) -> None:
    target.mkdir(parents=True, exist_ok=True)
    for record in records:
        for ext in ("hea", "dat", "atr"):
            path = target / f"{record}.{ext}"
            if not path.exists():
                print(f"downloading {path.name}")
                urllib.request.urlretrieve(f"{BASE_URL}{record}.{ext}", path)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(prog="pulsebridge_sim.mitbih", description="Download MIT-BIH records.")
    parser.add_argument("records", nargs="+", help="record numbers, e.g. 100 119 201")
    download(parser.parse_args().records)
