import unittest

from pulsebridge_sim.ecg import EcgGenerator


class EcgGeneratorTest(unittest.TestCase):
    def test_same_seed_gives_same_signal(self):
        a, _ = EcgGenerator(seed=1).next_samples(500)
        b, _ = EcgGenerator(seed=1).next_samples(500)
        self.assertEqual(a, b)

    def test_heart_rate_matches_setting(self):
        for target in (50, 72, 140):
            with self.subTest(target=target):
                generator = EcgGenerator(heart_rate=target, seed=2)
                _, beats = generator.next_samples(250 * 30)
                mean_bpm = sum(b.bpm for b in beats) / len(beats)
                self.assertAlmostEqual(mean_bpm, target, delta=target * 0.05)

    def test_r_peaks_look_like_lead_ii(self):
        samples, _ = EcgGenerator(seed=3, noise_uv=0).next_samples(250 * 5)
        self.assertGreater(max(samples), 1000)   # R wave around 1.2 mV
        self.assertLess(max(samples), 1500)
        self.assertLess(min(samples), -150)      # S wave below baseline

    def test_heart_rate_can_change_while_running(self):
        generator = EcgGenerator(heart_rate=60, seed=4)
        generator.next_samples(250 * 10)
        generator.heart_rate = 150
        generator.next_samples(250 * 5)
        _, beats = generator.next_samples(250 * 10)
        self.assertGreater(sum(b.bpm for b in beats) / len(beats), 140)


if __name__ == "__main__":
    unittest.main()
