import unittest

from pulsebridge_sim import protocol as p


def frame(seq=1, msg_type=p.MessageType.PING, payload=b""):
    return p.encode(p.Frame(msg_type, seq, payload))


class Crc16Test(unittest.TestCase):
    def test_standard_check_value(self):
        # Published check value for CRC-16/CCITT-FALSE.
        self.assertEqual(p.crc16(b"123456789"), 0x29B1)


class EncodeDecodeTest(unittest.TestCase):
    def test_round_trip(self):
        original = p.Frame(p.MessageType.ECG_SAMPLES, 42, b"\x00\x01\x02")
        self.assertEqual(p.FrameDecoder().feed(p.encode(original)), [original])

    def test_frame_split_byte_by_byte(self):
        decoder = p.FrameDecoder()
        frames = []
        for byte in frame(seq=7):
            frames += decoder.feed(bytes([byte]))
        self.assertEqual([f.seq for f in frames], [7])

    def test_garbage_before_frame_is_skipped(self):
        decoder = p.FrameDecoder()
        frames = decoder.feed(b"\x00\xA5\x13\xFF" + frame(seq=3))
        self.assertEqual([f.seq for f in frames], [3])
        self.assertEqual(decoder.skipped_bytes, 4)

    def test_corrupt_frame_is_rejected_and_next_frame_survives(self):
        bad = bytearray(frame(seq=1, payload=b"abc"))
        bad[9] ^= 0xFF
        decoder = p.FrameDecoder()
        frames = decoder.feed(bytes(bad) + frame(seq=2))
        self.assertEqual([f.seq for f in frames], [2])
        self.assertEqual(decoder.crc_errors, 1)

    def test_wrong_version_is_rejected(self):
        bad = bytearray(frame(seq=1))
        bad[2] = 99
        self.assertEqual(p.FrameDecoder().feed(bytes(bad)), [])

    def test_oversized_payload_cannot_be_encoded(self):
        with self.assertRaises(ValueError):
            p.encode(p.Frame(p.MessageType.ECG_SAMPLES, 1, bytes(p.MAX_PAYLOAD + 1)))

    def test_sequence_number_wraps(self):
        decoded = p.FrameDecoder().feed(frame(seq=0x10001))
        self.assertEqual(decoded[0].seq, 1)


class PayloadTest(unittest.TestCase):
    def test_round_trips(self):
        for payload in (
            p.Hello("PB-SIM-0001", "1.0.0", 250),
            p.EcgSamples(1000, (0, -150, 1200, 32767, -32768)),
            p.HeartRate(72, 833),
            p.Battery(87),
            p.Alarm(p.AlarmCode.LEAD_OFF, True),
            p.Ack(513, p.AckResult.INVALID_STATE),
        ):
            with self.subTest(payload=type(payload).__name__):
                self.assertEqual(type(payload).unpack(payload.pack()), payload)


if __name__ == "__main__":
    unittest.main()
