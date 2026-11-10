# Usability

A light take on IEC 62366-1 (usability engineering for medical devices): who uses the app, where, what could go wrong because of the interface, and what we did about it.

## Who and where

| | Patient | Clinician |
|---|---|---|
| **Who** | Adult wearing the monitor at home, any age, maybe not tech-savvy, maybe with poor eyesight. Portuguese or English. | Cardiologist or nurse reviewing recordings. |
| **Where** | At home, out and about, sometimes stressed or unwell when looking at the screen. | Clinic, often on the patient's phone or with a printed report. |
| **Does** | Connects the device, starts and stops recordings, logs symptoms, notices alarms. | Unlocks the clinical area, reviews the ECG at each symptom, exports a PDF or FHIR file. |

## Things on screen that matter for safety

- **Is it actually monitoring?** The Live / Lost / Offline pill in the top bar, always visible. If the link drops during a recording, a big red **NOT MONITORING** banner appears and the heart rate disappears, so an old number never looks current.
- **The heart rate:** huge, colour-coded (green normal, red outside the limits, grey when not live), with a HIGH / LOW label so colour isn't the only signal. It also says whether the number comes from the ECG or from the sensor.
- **Alarms** (electrode off, low battery): banners with an icon, a title and what to do next ("Check lead placement").
- **Rhythm indicators** are always labelled as screening, never as a diagnosis, in the app, the PDF and the FHIR export.

## What could go wrong because of the interface

| Scenario | What could happen | What the app does | Risk ref |
|---|---|---|---|
| Patient glances at the screen after the link dropped | Thinks they're monitored | Red banner, heart rate cleared, ECG dimmed, TalkBack announces it | HAZ-003 |
| Patient with low vision uses large text | Labels cut off or overlapping, alarm missed | Layout tested at 150 % and 200 %; big numbers shrink to fit instead of clipping | HAZ-018 |
| Blind patient uses TalkBack | Can't tell the heart rate or that an alarm appeared | Spoken labels ("Heart rate 72 beats per minute"), alarms announced as soon as they appear | HAZ-018 |
| Phone is in Portuguese | Misunderstands an English warning | Every screen and the PDF in Portuguese; stored data stays neutral and is translated on display | HAZ-018 |
| Patient taps the wrong symptom | Wrong diary entry | Big targets with icon and text; a confirmation snackbar names the symptom | — |
| Someone starts a firmware update mid-recording | Monitoring gap | The button is disabled during a recording, with the reason shown | HAZ-014 |
| Clinician sends data to a public test server | Privacy breach | Confirmation dialog naming the server; warning text in Settings; https only | HAZ-017 |
| Someone picks up an unlocked phone | Sees health data | Clinical area locks 30 s after the app leaves the screen | HAZ-007 |

## Accessibility checklist

- [x] Tap targets ≥ 48 dp (Flutter `androidTapTargetGuideline`, automated)
- [x] Every tappable thing has a label (`labeledTapTargetGuideline`, automated)
- [x] Text contrast WCAG AA (`textContrastGuideline`, automated)
- [x] Works at 150 % and 200 % text without overflow (automated, monitor and settings)
- [x] Screen-reader labels on the custom-drawn parts: ECG, trend, heart rate, battery, PIN dots
- [x] Alarms are live regions, so TalkBack reads them without moving focus
- [x] Colour is never the only signal (HIGH / LOW text, icons on every banner)
- [x] Pulsing animations stop when the phone asks for reduced motion
- [x] Portuguese and English, with proper plurals
- [ ] Summative test with real users (would be the next step in a real project)
- [ ] TalkBack walkthrough on a physical phone
