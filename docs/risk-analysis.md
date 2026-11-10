# Risk analysis

What could go wrong, how bad it would be, and what the software does about it. Loosely shaped after ISO 14971. Each control points to the requirement that implements it ([requirements.md](requirements.md)).

Scales, kept simple:
- **Severity (S):** 1 negligible · 3 serious · 5 critical.
- **Probability (P):** 1 improbable · 3 occasional · 5 frequent.
- Risk = S × P. Six or below is acceptable.

| ID | What could go wrong | Harm | S | P before | What we do about it | P after | Status |
|---|---|---|---|---|---|---|---|
| HAZ-001 | Corrupt data shown as real ECG | Wrong reading | 4 | 3 | CRC check, frame dropped (SRS-002) | 1 | Verified |
| HAZ-002 | Samples lost but the trace looks continuous | Missed arrhythmia | 4 | 3 | Gaps detected and drawn as breaks; "E" in the FHIR export; grey bands in the PDF (SRS-003, SRS-023) | 1 | Verified |
| HAZ-003 | Link lost while the screen keeps showing old values | Patient thinks they're monitored | 5 | 3 | Silence timeout, red NOT MONITORING banner (announced by TalkBack), heart rate cleared, trace dimmed, automatic reconnect (SRS-004, SRS-006, SRS-051) | 1 | Verified |
| HAZ-004 | Electrode off, noise read as signal | Missed or false alarm | 4 | 3 | LEAD_OFF alarm, heart rate hidden (SRS-012) | 1 | Verified |
| HAZ-005 | Device battery dies mid-recording | Gap in monitoring | 3 | 3 | LOW_BATTERY alarm (SRS-012) | 1 | Verified |
| HAZ-006 | Android kills the app in the background | Recording stops silently | 4 | 4 | Foreground service with a permanent notification (SRS-013) | 1 | Tried by hand |
| HAZ-007 | Lost or stolen phone exposes health data | Privacy breach | 3 | 3 | Encryption at rest; clinical area behind PIN or fingerprint, with lockout and relock (SRS-020, SRS-021) | 1 | Verified |
| HAZ-008 | Two apps connected to one device | Conflicting commands | 2 | 2 | Device takes one client at a time (SRS-005) | 1 | Verified |
| HAZ-009 | An exported report leaves the phone unencrypted | Privacy breach | 3 | 2 | Only on an explicit tap, from the locked area, one session at a time. After sharing, the file is the recipient's responsibility (residual, stated) (SRS-022) | 1 | Verified |
| HAZ-010 | A printed strip at the wrong scale gets measured | Wrong reading | 4 | 2 | Strips at 25 mm/s and 10 mm/mV with a 1 mV calibration pulse; scale printed above (SRS-022) | 1 | Verified (PDF checked visually) |
| HAZ-011 | The device's heart rate is wrong and nobody notices | Missed tachy/bradycardia | 4 | 2 | The phone finds the beats itself in the ECG and shows that rate, validated on MIT-BIH (SRS-018) | 1 | Verified |
| HAZ-012 | The phone's QRS detector misses beats (noise, AF) | Wrong heart rate | 3 | 3 | Search-back for missed beats, T-wave rejection, restart after gaps; ≥ 97 % on MIT-BIH incl. atrial fibrillation; labelled as screening (SRS-018, SRS-014) | 2 | Verified |
| HAZ-013 | A Bluetooth sensor loses skin contact or goes quiet | Stale or false heart rate | 4 | 3 | Contact loss raises "electrode off" and hides the rate; 5 s of silence counts as a lost link (SRS-042) | 1 | Verified (not yet on hardware) |
| HAZ-014 | A firmware update interrupts monitoring | Gap in monitoring | 4 | 2 | No update during a recording, refused by both app and device (SRS-033) | 1 | Verified |
| HAZ-015 | A broken or wrong image gets installed | Device unusable | 5 | 2 | Size, CRC-32 and header checked before switching; old version kept on any failure; resume instead of a half-written image (SRS-031, SRS-032) | 1 | Verified |
| HAZ-016 | A malicious image gets installed | Device compromised | 5 | 1 | Out of scope: CRC-32 checks integrity, not origin. A real device would verify a signature in its bootloader | 1 | Open (documented limitation) |
| HAZ-017 | Health data sent to the wrong place or in clear text | Privacy breach | 3 | 2 | https only, an explicit confirmation naming the server, a warning about public test servers (SRS-023) | 1 | Verified |
| HAZ-018 | A user misreads the screen (language, small text, screen reader) | Missed alarm | 4 | 2 | Portuguese and English, large text without overflow, TalkBack labels and live announcements for alarms (SRS-050 to SRS-052) | 1 | Verified |
