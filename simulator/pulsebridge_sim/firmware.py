"""Firmware images and the device side of the update (bootloader).

Image layout: b"PBFW", version as 16 bytes of NUL-padded ASCII, then the
program. The bootloader keeps a partial image across connections so a
transfer can resume, and installs only after the size, CRC-32 and header all
check out; otherwise the running firmware is kept.

Build an image:  python -m pulsebridge_sim.firmware 1.1.0 out.bin
"""
from __future__ import annotations

import argparse
import random
import struct
import zlib
from dataclasses import dataclass, field
from enum import IntEnum
from pathlib import Path

MAGIC = b"PBFW"
HEADER = struct.Struct(">4s16s")
MAX_CHUNK = 512


class FwState(IntEnum):
    IDLE = 0
    RECEIVING = 1
    INSTALLED = 2   # verified; the device restarts into the new version
    REJECTED = 3    # nothing installed, the running version stays


def build_image(version: str, size: int = 96 * 1024, seed: int = 1) -> bytes:
    body = random.Random(seed).randbytes(size - HEADER.size)
    return HEADER.pack(MAGIC, version.encode("ascii")) + body


def image_version(image: bytes) -> str | None:
    if len(image) < HEADER.size:
        return None
    magic, version = HEADER.unpack_from(image)
    return version.rstrip(b"\0").decode("ascii", "replace") if magic == MAGIC else None


@dataclass(frozen=True)
class FwBegin:
    size: int
    crc32: int
    version: str

    def pack(self) -> bytes:
        v = self.version.encode()
        return struct.pack(f">IIB{len(v)}s", self.size, self.crc32, len(v), v)

    @classmethod
    def unpack(cls, data: bytes) -> FwBegin:
        size, crc, n = struct.unpack_from(">IIB", data)
        return cls(size, crc, data[9:9 + n].decode())


@dataclass(frozen=True)
class FwChunk:
    offset: int
    data: bytes

    def pack(self) -> bytes:
        return struct.pack(">I", self.offset) + self.data

    @classmethod
    def unpack(cls, data: bytes) -> FwChunk:
        return cls(struct.unpack_from(">I", data)[0], data[4:])


@dataclass(frozen=True)
class FwStatus:
    state: FwState
    received: int
    detail: str = ""

    def pack(self) -> bytes:
        d = self.detail.encode()[:255]
        return struct.pack(f">BIB{len(d)}s", self.state, self.received, len(d), d)

    @classmethod
    def unpack(cls, data: bytes) -> FwStatus:
        state, received, n = struct.unpack_from(">BIB", data)
        return cls(FwState(state), received, data[6:6 + n].decode())


@dataclass
class Bootloader:
    """Firmware update state that outlives a connection, as flash would."""
    running: str
    corrupt_flash: bool = False     # fault: one byte is stored wrong, so the CRC fails
    pending: FwBegin | None = None
    buffer: bytearray = field(default_factory=bytearray)

    def begin(self, request: FwBegin) -> FwStatus:
        if request.size <= HEADER.size or request.size > 4 * 1024 * 1024:
            return FwStatus(FwState.REJECTED, 0, f"bad image size {request.size}")
        if request != self.pending:
            self.pending, self.buffer = request, bytearray()
        # Same image as before: keep what arrived, the app resumes from there.
        return FwStatus(FwState.RECEIVING, len(self.buffer), f"receiving {request.version}")

    def chunk(self, chunk: FwChunk) -> FwStatus:
        if self.pending is None:
            return FwStatus(FwState.REJECTED, 0, "no update in progress")
        if len(chunk.data) > MAX_CHUNK:
            return FwStatus(FwState.REJECTED, len(self.buffer), "chunk too large")
        if chunk.offset == len(self.buffer):
            room = self.pending.size - len(self.buffer)
            self.buffer += chunk.data[:room]
        # A repeated or early chunk changes nothing; the status tells the app where to go on.
        return FwStatus(FwState.RECEIVING, len(self.buffer))

    def commit(self) -> FwStatus:
        request = self.pending
        if request is None:
            return FwStatus(FwState.REJECTED, 0, "no update in progress")
        if len(self.buffer) != request.size:
            return FwStatus(FwState.RECEIVING, len(self.buffer), "image incomplete")
        image = bytearray(self.buffer)
        if self.corrupt_flash:
            image[len(image) // 2] ^= 0x01
        self.pending, self.buffer = None, bytearray()
        if zlib.crc32(image) != request.crc32:
            return FwStatus(FwState.REJECTED, 0, f"checksum mismatch, kept {self.running}")
        if image_version(bytes(image)) != request.version:
            return FwStatus(FwState.REJECTED, 0, f"not a PulseBridge {request.version} image, kept {self.running}")
        self.running = request.version
        return FwStatus(FwState.INSTALLED, request.size, f"installed {request.version}, restarting")

    def abort(self) -> FwStatus:
        self.pending, self.buffer = None, bytearray()
        return FwStatus(FwState.IDLE, 0, "update cancelled")


def main() -> None:
    parser = argparse.ArgumentParser(description="Build a PulseBridge firmware image")
    parser.add_argument("version")
    parser.add_argument("output", type=Path)
    parser.add_argument("--size", type=int, default=96 * 1024)
    args = parser.parse_args()
    image = build_image(args.version, args.size)
    args.output.write_bytes(image)
    print(f"{args.output}: {len(image)} bytes, CRC-32 {zlib.crc32(image):08x}")


if __name__ == "__main__":
    main()
