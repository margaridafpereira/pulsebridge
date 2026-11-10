# Traceability

Which test proves which requirement. If a line says "Manual", someone checked it on the emulator and there's no automated test yet.

The test suites live in:
- **Simulator (Python):** `simulator/tests/`
- **Kotlin:** `device_link/android/src/test/kotlin/`
- **Dart, plugin:** `device_link/test/`
- **Dart, app:** `app/test/` (`widget_test`, `clinical_test`, `features_test`, `usability_test`, `qrs_validation_test`)

| Requirement | Tests |
|---|---|
| SRS-001 | Python: `test_protocol` (round trips, payloads, CRC check value). Kotlin: `ProtocolTest.encodesExactlyLikeThePythonSimulator`, `parsesEveryMessageFromThePythonSimulator`, `crcMatchesStandardCheckValue`. The Kotlin tests decode frames produced by the Python simulator byte for byte. |
| SRS-002 | Python: `test_corrupt_frame_is_rejected_and_next_frame_survives`, `test_wrong_version_is_rejected`, `test_garbage_before_frame_is_skipped`, `test_corrupted_frames_are_caught_by_crc`. Kotlin: `ProtocolTest.rejectsCorruptFrameAndKeepsTheNextOne`, `rejectsUnknownVersion`, `skipsGarbageBeforeAFrame`, `refusesOversizedPayload`. |
| SRS-003 | Python: `test_dropped_frames_leave_sequence_gaps`. Kotlin: `DeviceSessionTest.reportsLostEcgSamples`, `countsLostFramesFromSequenceGaps`. Dart: `EcgBuffer marks lost samples as a gap instead of drawing through them`. |
| SRS-004 | Kotlin: `DeviceSessionTest.reconnectsAndResumesStreamingAfterLinkLoss`. Dart: `link loss while recording means not monitoring`, `shows the not-monitoring banner when the link drops during recording`. |
| SRS-005 | Python: `test_does_not_stream_before_start`, `test_start_twice_is_rejected`, `test_stop_ends_the_stream`, `test_unknown_command_is_nacked`, `test_second_client_is_rejected`. Kotlin: `DeviceSessionTest.startStreamingSendsTheCommand`. |
| SRS-006 | Kotlin: `DeviceSessionTest.keepsTheLinkAliveWithPings`, `silentDeviceIsTreatedAsLinkLoss`. |
| SRS-011 | Dart: `flags heart rate outside the limits`. |
| SRS-012 | Python (device side): `test_lead_off_raises_and_clears_alarm`, `test_low_battery_alarm`. Dart: `shows heart rate and drops it when an electrode comes off`. Kotlin (bridge): `DeviceLinkPluginTest.alarmsUseTheirName`. |
| SRS-013 | Manual: app sent to background during recording; `dumpsys` shows `DeviceService` with `isForeground=true`, `types=connectedDevice`; the notification updates the heart rate (see [images/background.png](images/background.png)). |
| SRS-014 | Dart: `RhythmAnalyzer regular sinus rhythm has no premature beats and is regular`, `a short RR followed by a compensatory pause counts as premature`, `random RR intervals are flagged irregular`. |
| SRS-015 | Dart: `a recording with a symptom is saved encrypted when stopped`, `recorder keeps gaps and the repository round-trips through the store` (symptom at 30 000 ms). |
| SRS-016 | Dart: `recorder keeps gaps and the repository round-trips through the store`, `an empty recording is not saved`. |
| SRS-017 | Manual: tapping "Palpitations" at 0:50 moves the review strip to 0:47–0:53 (see [images/session-review.png](images/session-review.png)). |
| SRS-018 | Dart: `qrs_validation_test` runs the detector over MIT-BIH 100, 119 and 201 and compares each beat with the cardiologists' annotations (±150 ms, AAMI EC57): Se 99.96 / 100 / 97.5 %, +P 100 / 99.55 / 99.9 %. Also `finds every beat of a regular rhythm at the right rate`, `restarts learning after lost samples instead of bridging them`, `with ECG arriving, the rate comes from our own QRS detection`. |
| SRS-020 | Kotlin: `SecureStoreTest.roundTrips`, `storesCiphertextNotPlaintext`, `sameDataEncryptsDifferentlyEachTime`, `detectsTampering`, `wrongKeyCannotRead`, `rejectsPathTraversal`, `listsAndDeletes`. |
| SRS-021 | Dart: `PBKDF2-HMAC-SHA256 matches published vectors`, `stores a salted hash, never the PIN`, `rejects PINs that are not 6 digits`, `wrong PIN keeps it locked; the right one opens it`, `five wrong PINs pause entry, even for the right PIN, and the pause doubles`, `failures survive an app restart`, `biometrics must be confirmed to turn on, then unlock`, `biometrics do not bypass a lockout`, `ClinicalGate asks for a new PIN twice, then shows the clinical area, and locks again`. Manual: PIN creation, wrong PIN and lock button on the emulator (see [images/lock.png](images/lock.png)). The fingerprint prompt itself is not yet verified on a device. |
| SRS-022 | Dart: `builds a PDF with the session, the profile and a strip per symptom`, `works with no profile, no events and no ECG`. Manual: preview and share sheet on the emulator (see [images/report.png](images/report.png)). |
| SRS-023 | Dart: `is a transaction bundle whose references all resolve inside it`, `maps the patient`, `heart rate follows the vital-signs profile with LOINC 8867-4 and UCUM /min`, `the ECG is lead II in µV, with lost samples as E`, `symptoms are coded in SNOMED CT when known, text otherwise`, `a diagnostic report lists every result`, `sending refuses plain http`, `sending posts the bundle and reads the created locations` (against a local test server). |
| SRS-030 | Kotlin: `FirmwareUpdaterTest.sendsTheImageAndConfirmsTheNewVersionAfterRestart`, `retriesWhenAnAnswerIsLost`, `aDeviceThatStopsAnsweringFails`, `cancelSendsAbort`. |
| SRS-031 | Python: `test_resumes_the_same_image_where_it_stopped`, `test_repeated_and_early_chunks_change_nothing`. Kotlin: `FirmwareUpdaterTest.resumesFromWhatTheDeviceKeptAfterALinkLoss` (only the missing half is sent again). |
| SRS-032 | Python: `test_installs_a_verified_image`, `test_a_corrupted_image_is_rejected_and_the_old_version_kept`, `test_an_image_for_another_version_is_rejected`, `test_oversized_chunks_are_refused`, `test_commit_before_the_end_does_not_install`. Kotlin: `FirmwareUpdaterTest.aCorruptedImageFailsAndTheDeviceKeepsItsFirmware`. |
| SRS-033 | Python: `test_update_then_restart_with_the_new_version`, `test_refuses_to_update_while_streaming`. Kotlin: `FirmwareUpdaterTest.sendsTheImageAndConfirmsTheNewVersionAfterRestart`. Dart: `no update while recording`, `firmware progress arrives from the native side`, `versions compare numerically`. |
| SRS-040 | Kotlin: `BleHeartRateSessionTest.connectsAndReportsTheSensor`. Dart: `the connection type and sensor survive a save`, `a heart-rate-only recording is kept`, `without ECG (a Bluetooth sensor), the device rate is used`. Not yet tried with a real sensor. |
| SRS-041 | Kotlin: `HeartRateMeasurementTest.parsesAn8BitRateWithoutContactSupport`, `parsesA16BitRate`, `readsSkinContact`, `skipsEnergyAndConvertsRrFrom1024ths`, `rejectsATruncatedValue`; `BleHeartRateSessionTest.emitsOneBeatPerRrInterval`, `malformedNotificationsAreDropped`. |
| SRS-042 | Kotlin: `BleHeartRateSessionTest.lostSkinContactRaisesLeadOffAndSuppressesTheRate`, `silentSensorCountsAsLostAndReconnects`, `aDroppedLinkIsReportedWithItsReason`. |
| SRS-050 | Dart: `the monitor speaks Portuguese`, `plurals follow the language`, `stored English event texts are shown translated`. The string table (`app/tool/l10n_table.py`) refuses to build if a key is missing in either language. |
| SRS-051 | Dart: `the monitor meets tap-target, label and contrast guidelines` (Flutter's `androidTapTargetGuideline`, `labeledTapTargetGuideline`, `textContrastGuideline`), `the heart rate and alarms are announced to screen readers`. |
| SRS-052 | Dart: `nothing overflows with 1.5x / 2.0x text on the monitor`, `… in settings` (these found five real overflows, now fixed). |
