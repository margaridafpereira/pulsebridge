# Requirements

What the system has to do, one line each, with the tests that prove it in [traceability.md](traceability.md). The layout loosely follows IEC 62304 (software requirements), because that's how a real medical device would be specified. PulseBridge itself is a portfolio project, not a medical device.

How to read the status column:
- **Verified:** an automated test covers it.
- **Tried by hand:** checked on the emulator against the simulator, no automated test yet.
- **Not yet on hardware:** tested with a fake device in the test suite, never with the real thing.

## Talking to the device

| ID | The system shall… | Status |
|---|---|---|
| SRS-001 | exchange data with the ECG device using the frames in [protocol.md](protocol.md). | Verified (simulator, Kotlin) |
| SRS-002 | throw away frames with a bad CRC, version or length, and keep decoding what follows. | Verified (simulator, Kotlin) |
| SRS-003 | notice lost frames and lost ECG samples, and draw lost samples as a gap, never as a line. | Verified (Kotlin, Dart) |
| SRS-004 | reconnect by itself after the link drops, resume streaming, and tell the user while it's down. | Verified (Kotlin, Dart) |
| SRS-005 | (device) only stream after START_STREAM and acknowledge every command. | Verified (simulator) |
| SRS-006 | treat a device that's silent for 3 s as gone, and ping every second so a healthy link never looks silent. | Verified (Kotlin) |

## Bluetooth heart-rate sensors

| ID | The system shall… | Status |
|---|---|---|
| SRS-040 | connect to any sensor with the standard Heart Rate Service (0x180D), chosen in Settings instead of the ECG simulator, after a scan that lists nearby sensors. | Verified (Kotlin, Dart); not yet on hardware |
| SRS-041 | read heart rate, RR intervals, skin contact and battery as the Bluetooth spec defines them, and drop malformed notifications. | Verified (Kotlin) |
| SRS-042 | apply the same safety rules as the ECG link: silence over 5 s is a lost link, reconnect with backoff, lost skin contact raises "electrode off" and hides the heart rate. | Verified (Kotlin) |

## Monitoring

| ID | The system shall… | Status |
|---|---|---|
| SRS-010 | show the ECG live, less than 500 ms behind the device. | Tried by hand (no latency measurement yet) |
| SRS-011 | show the heart rate and alarm when it leaves the limits. | Verified (Dart) |
| SRS-012 | alarm on LEAD_OFF and LOW_BATTERY within 2 s, and never show a heart rate while an electrode is off. | Verified (Dart; timing tried by hand) |
| SRS-013 | keep recording with the app in the background, with a notification showing link state and heart rate. | Tried by hand |
| SRS-014 | flag premature beats (RR < 80 % of the median of the last 8) and irregular RR (normalised RMSSD > 0.15 over 20 beats), labelled as screening, not diagnosis. | Verified (Dart) |
| SRS-015 | let the patient log a symptom during a recording, pinned to that moment of the ECG. | Verified (Dart) |
| SRS-016 | save each recording with its raw ECG, gaps marked, heart rate and an event log. | Verified (Dart) |
| SRS-017 | jump to the ECG at any event in a saved recording. | Tried by hand |
| SRS-018 | find the beats in the ECG on the phone (Pan-Tompkins) and use that heart rate instead of the device's, with at least 97 % sensitivity and positive predictivity on MIT-BIH records 100, 119 and 201 (AAMI EC57 matching). The screen says where the rate comes from. | Verified (Dart, against MIT-BIH) |

## Data protection

| ID | The system shall… | Status |
|---|---|---|
| SRS-020 | encrypt everything at rest with AES-256-GCM, with the key made inside the Android Keystore, and reject tampered files. | Verified (Kotlin) |
| SRS-021 | lock the clinical area behind a 6-digit PIN (stored only as a salted PBKDF2 hash) or a fingerprint; pause entry after every 5 wrong PINs, 30 s doubling up to 15 min, for fingerprints too; remember failures across restarts; lock again 30 s after the app leaves the screen. | Verified (Dart, fingerprint with a fake); PIN tried by hand |
| SRS-022 | make a PDF report for one session, only when the user opens it from the clinical area: patient, summary, heart-rate trend, an ECG strip at real scale (25 mm/s, 10 mm/mV) at each symptom and alarm, and the event log. | Verified (Dart); preview and print tried by hand |
| SRS-023 | export one session as a FHIR R4 transaction Bundle (Patient, Device, heart rate per the vital-signs profile, ECG as SampledData with lost samples as "E", symptoms coded in SNOMED CT, a DiagnosticReport), shared as a file or sent to a server only over https, after confirmation. | Verified (Dart) |

## Firmware update

| ID | The system shall… | Status |
|---|---|---|
| SRS-030 | send a firmware image in chunks, each confirmed before the next, retrying an unanswered command and giving up after 8 tries. | Verified (Kotlin) |
| SRS-031 | resume after a lost link from what the device kept, without starting over. | Verified (simulator, Kotlin) |
| SRS-032 | (device) install only after checking size, CRC-32 and image header, and keep the running version otherwise. | Verified (simulator, Kotlin) |
| SRS-033 | call an update done only when the device restarts and reports the new version; never update during a recording. | Verified (simulator, Kotlin, Dart) |

## Usability and accessibility

| ID | The system shall… | Status |
|---|---|---|
| SRS-050 | be fully usable in English and Portuguese, following the phone or a choice in Settings, PDF report included. | Verified (Dart) |
| SRS-051 | work with TalkBack: labels on the heart rate, ECG, trend and buttons; alarms announced as soon as they appear; tap targets of at least 48 dp; text contrast to WCAG AA. | Verified (Dart, Flutter accessibility guidelines) |
| SRS-052 | lay out without overflow with text at 150 % and 200 %, and stop pulsing animations when the phone asks for reduced motion. | Verified (Dart, monitor and settings) |

More on the usability side in [usability.md](usability.md).
