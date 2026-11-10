"""PulseBridge wire protocol: framing, CRC and message payloads.

Frame layout, all integers big-endian:

    offset  size  field
    0       2     sync      0xA5 0x5A
    2       1     version   PROTOCOL_VERSION
    3       1     type      MessageType
    4       2     seq       sender's sequence number, wraps at 65535
    6       2     length    payload length in bytes (max MAX_PAYLOAD)
    8       n     payload
    8+n     2     crc       CRC-16/CCITT-FALSE over version..payload

See docs/protocol.md for the full specification.
"""
from __future__ import annotations

import struct
from dataclasses import dataclass
from enum import IntEnum

SYNC = b"\xA5\x5A"
PROTOCOL_VERSION = 1
MAX_PAYLOAD = 1024

_HEADER = struct.Struct(">BBHH")
_CRC = struct.Struct(">H")
FRAME_OVERHEAD = len(SYNC) + _HEADER.size + _CRC.size


class MessageType(IntEnum):
    # Device -> app
    HELLO = 0x01
    ECG_SAMPLES = 0x10
    HEART_RATE = 0x11
    BATTERY = 0x12
    ALARM = 0x13
    FW_STATUS = 0x14
    ACK = 0x7F
    # App -> device
    START_STREAM = 0x20
    STOP_STREAM = 0x21
    PING = 0x22
    FW_BEGIN = 0x30
    FW_CHUNK = 0x31
    FW_COMMIT = 0x32
    FW_ABORT = 0x33


class AckResult(IntEnum):
    OK = 0
    UNKNOWN_COMMAND = 1
    INVALID_STATE = 2


class AlarmCode(IntEnum):
    LEAD_OFF = 1
    LOW_BATTERY = 2


def crc16(data: bytes) -> int:
    """CRC-16/CCITT-FALSE (poly 0x1021, init 0xFFFF, no reflection, no xorout)."""
    crc = 0xFFFF
    for byte in data:
        crc ^= byte << 8
        for _ in range(8):
            crc = ((crc << 1) ^ 0x1021) if crc & 0x8000 else crc << 1
            crc &= 0xFFFF
    return crc


@dataclass(frozen=True)
class Frame:
    type: int
    seq: int
    payload: bytes = b""


def encode(frame: Frame) -> bytes:
    if len(frame.payload) > MAX_PAYLOAD:
        raise ValueError(f"payload too large: {len(frame.payload)} > {MAX_PAYLOAD}")
    body = _HEADER.pack(PROTOCOL_VERSION, frame.type, frame.seq & 0xFFFF, len(frame.payload)) + frame.payload
    return SYNC + body + _CRC.pack(crc16(body))


class FrameDecoder:
    """Turns a byte stream into frames.

    Bytes arrive in arbitrary chunks. Anything that is not a valid frame is
    skipped and the decoder resynchronises on the next sync pattern, so one
    corrupt frame never takes the following ones down with it.
    """

    def __init__(self) -> None:
        self._buf = bytearray()
        self.crc_errors = 0
        self.skipped_bytes = 0

    def feed(self, data: bytes) -> list[Frame]:
        self._buf += data
        frames: list[Frame] = []
        while True:
            start = self._buf.find(SYNC)
            if start < 0:
                # A trailing 0xA5 may be the first half of the next sync.
                keep = 1 if self._buf.endswith(SYNC[:1]) else 0
                self._skip(len(self._buf) - keep)
                return frames
            self._skip(start)

            if len(self._buf) < len(SYNC) + _HEADER.size:
                return frames
            version, msg_type, seq, length = _HEADER.unpack_from(self._buf, len(SYNC))
            if version != PROTOCOL_VERSION or length > MAX_PAYLOAD:
                self._skip(1)
                continue

            total = FRAME_OVERHEAD + length
            if len(self._buf) < total:
                return frames
            body = bytes(self._buf[len(SYNC):total - _CRC.size])
            (crc,) = _CRC.unpack_from(self._buf, total - _CRC.size)
            if crc != crc16(body):
                self.crc_errors += 1
                self._skip(1)
                continue

            frames.append(Frame(msg_type, seq, body[_HEADER.size:]))
            del self._buf[:total]

    def _skip(self, n: int) -> None:
        if n:
            self.skipped_bytes += n
            del self._buf[:n]


# --- Payloads ---------------------------------------------------------------

@dataclass(frozen=True)
class Hello:
    device_id: str
    firmware: str
    sample_rate: int

    def pack(self) -> bytes:
        device_id, firmware = self.device_id.encode(), self.firmware.encode()
        return struct.pack(f">HB{len(device_id)}sB{len(firmware)}s",
                           self.sample_rate, len(device_id), device_id, len(firmware), firmware)

    @classmethod
    def unpack(cls, data: bytes) -> Hello:
        (sample_rate, id_len) = struct.unpack_from(">HB", data)
        device_id = data[3:3 + id_len].decode()
        fw_len = data[3 + id_len]
        firmware = data[4 + id_len:4 + id_len + fw_len].decode()
        return cls(device_id, firmware, sample_rate)


@dataclass(frozen=True)
class EcgSamples:
    first_index: int            # index of the first sample since streaming started
    samples: tuple[int, ...]    # microvolts, int16

    def pack(self) -> bytes:
        return struct.pack(f">I{len(self.samples)}h", self.first_index, *self.samples)

    @classmethod
    def unpack(cls, data: bytes) -> EcgSamples:
        count = (len(data) - 4) // 2
        first_index, *samples = struct.unpack(f">I{count}h", data)
        return cls(first_index, tuple(samples))


@dataclass(frozen=True)
class HeartRate:
    bpm: int
    rr_ms: int

    def pack(self) -> bytes:
        return struct.pack(">BH", self.bpm, self.rr_ms)

    @classmethod
    def unpack(cls, data: bytes) -> HeartRate:
        return cls(*struct.unpack(">BH", data))


@dataclass(frozen=True)
class Battery:
    percent: int

    def pack(self) -> bytes:
        return struct.pack(">B", self.percent)

    @classmethod
    def unpack(cls, data: bytes) -> Battery:
        return cls(*struct.unpack(">B", data))


@dataclass(frozen=True)
class Alarm:
    code: AlarmCode
    active: bool

    def pack(self) -> bytes:
        return struct.pack(">BB", self.code, self.active)

    @classmethod
    def unpack(cls, data: bytes) -> Alarm:
        code, active = struct.unpack(">BB", data)
        return cls(AlarmCode(code), bool(active))


@dataclass(frozen=True)
class Ack:
    acked_seq: int
    result: AckResult

    def pack(self) -> bytes:
        return struct.pack(">HB", self.acked_seq, self.result)

    @classmethod
    def unpack(cls, data: bytes) -> Ack:
        acked_seq, result = struct.unpack(">HB", data)
        return cls(acked_seq, AckResult(result))
