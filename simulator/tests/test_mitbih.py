import unittest

from pulsebridge_sim import mitbih

RECORD_119 = mitbih.DATA_DIR / "119"


def annotation(code, delta):
    word = (code << 10) | delta
    return bytes([word & 0xFF, word >> 8])


class DecodeTest(unittest.TestCase):
    def test_format_212_unpacks_two_signed_12_bit_samples(self):
        # 0x123 and -2 (0xFFE): b0 = 0x23, b1 = 0xF1, b2 = 0xFE
        self.assertEqual(mitbih.decode_212(bytes([0x23, 0xF1, 0xFE]), signals=1), [0x123, -2])

    def test_format_212_picks_the_requested_channel(self):
        data = bytes([0x0A, 0x00, 0x14])  # channel 0 = 10, channel 1 = 20
        self.assertEqual(mitbih.decode_212(data, signals=2, channel=1), [20])

    def test_annotations_accumulate_time_and_skip_aux(self):
        data = (annotation(1, 100) + annotation(63, 3) + b"abc\x00"   # beat, then 3-byte aux padded to 4
                + annotation(5, 250) + annotation(59, 0) + bytes([0, 0, 0x10, 0x27])  # skip 10000
                + annotation(1, 5) + annotation(0, 0))
        self.assertEqual(mitbih.decode_annotations(data), [(100, 1), (350, 5), (10355, 1)])


@unittest.skipUnless(RECORD_119.with_suffix(".dat").exists(),
                     "run: python -m pulsebridge_sim.mitbih 119")
class RecordPlayerTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.player = mitbih.RecordPlayer(RECORD_119, sample_rate=250)

    def setUp(self):
        self.player.rewind()

    def test_header(self):
        self.assertEqual((self.player.header.sample_rate, self.player.header.lead), (360, "MLII"))

    def test_signal_is_in_a_plausible_microvolt_range(self):
        samples, _ = self.player.next_samples(250 * 10)
        self.assertGreater(max(samples) - min(samples), 500)
        self.assertLess(max(abs(s) for s in samples), 6000)

    def test_heart_rate_comes_from_annotations(self):
        _, beats = self.player.next_samples(250 * 60)
        self.assertGreater(len(beats), 40)
        self.assertTrue(all(30 < b.bpm < 200 for b in beats))
        # Record 119 has ventricular bigeminy: short and long RR intervals alternate.
        rr = [b.rr_ms for b in beats]
        self.assertGreater(max(rr) - min(rr), 300)

    def test_rewind_restarts_playback(self):
        first, _ = self.player.next_samples(100)
        self.player.rewind()
        again, _ = self.player.next_samples(100)
        self.assertEqual(first, again)


if __name__ == "__main__":
    unittest.main()
