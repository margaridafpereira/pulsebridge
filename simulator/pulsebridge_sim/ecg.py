"""Synthetic ECG: each beat is a sum of Gaussian P, Q, R, S and T waves.

A simplified take on McSharry et al., "A dynamical model for generating
synthetic electrocardiogram signals" (IEEE TBME, 2003). It is good enough to
look like lead II on screen and to drive heart-rate logic, not for clinical use.
"""
from __future__ import annotations

import math
import random
from collections import deque
from dataclasses import dataclass

# (amplitude mV, offset from the R peak in s, width in s)
_WAVES = (
    (0.15, -0.20, 0.025),   # P
    (-0.12, -0.03, 0.010),  # Q
    (1.20, 0.00, 0.012),    # R
    (-0.25, 0.035, 0.012),  # S
    (0.30, 0.25, 0.045),    # T
)
_BEAT_REACH_S = 0.6


@dataclass(frozen=True)
class Beat:
    time_s: float
    bpm: int
    rr_ms: int


class EcgGenerator:
    """Produces ECG samples in microvolts, plus a Beat for every detected R peak.

    `heart_rate` can be changed while running, e.g. to simulate tachycardia.
    """

    def __init__(self, sample_rate: int = 250, heart_rate: float = 72.0,
                 noise_uv: float = 10.0, seed: int | None = None) -> None:
        self.sample_rate = sample_rate
        self.heart_rate = heart_rate
        self.noise_uv = noise_uv
        self._rng = random.Random(seed)
        self._index = 0
        self._beats: deque[float] = deque()
        self._next_beat = 0.5
        self._last_reported: float | None = None

    def _rr(self, t: float) -> float:
        # Respiratory sinus arrhythmia (~0.25 Hz) plus a little jitter.
        base = 60.0 / self.heart_rate
        return base * (1 + 0.04 * math.sin(2 * math.pi * 0.25 * t)) + self._rng.gauss(0, 0.01)

    def next_samples(self, count: int) -> tuple[list[int], list[Beat]]:
        samples: list[int] = []
        beats: list[Beat] = []
        for _ in range(count):
            t = self._index / self.sample_rate
            while self._next_beat < t + _BEAT_REACH_S:
                self._beats.append(self._next_beat)
                self._next_beat += self._rr(self._next_beat)
            while self._beats and self._beats[0] < t - _BEAT_REACH_S:
                self._beats.popleft()

            mv = 0.05 * math.sin(2 * math.pi * 0.3 * t)  # baseline wander
            for r_peak in self._beats:
                dt = t - r_peak
                for amplitude, offset, width in _WAVES:
                    mv += amplitude * math.exp(-((dt - offset) ** 2) / (2 * width ** 2))
            uv = mv * 1000 + self._rng.gauss(0, self.noise_uv)
            samples.append(max(-32768, min(32767, round(uv))))

            # Report each R peak once the sample clock passes it.
            for r_peak in self._beats:
                if r_peak <= t and (self._last_reported is None or r_peak > self._last_reported):
                    if self._last_reported is not None:
                        rr = r_peak - self._last_reported
                        beats.append(Beat(r_peak, round(60 / rr), round(rr * 1000)))
                    self._last_reported = r_peak
            self._index += 1
        return samples, beats
