# PulseBridge device protocol, version 1

The device and the app exchange binary frames over a byte stream. Today the stream is TCP. A future BLE or USB serial link will carry the same frames.

## Frame

All integers are big-endian.

| Offset | Size | Field | Notes |
|---|---|---|---|
| 0 | 2 | sync | `0xA5 0x5A` |
| 2 | 1 | version | `1` |
| 3 | 1 | type | see below |
| 4 | 2 | seq | sender's sequence number, +1 per frame, wraps at 65535 |
| 6 | 2 | length | payload length in bytes, at most 1024 |
| 8 | n | payload | |
| 8+n | 2 | crc | CRC-16/CCITT-FALSE over `version..payload` |

CRC-16/CCITT-FALSE uses polynomial `0x1021` and initial value `0xFFFF`, with no reflection and no final XOR. Its check value for `"123456789"` is `0x29B1`.

### Receiver rules

- Discard bytes until a sync pattern is found.
- Reject a frame whose version is unknown, whose length is over 1024 or whose CRC does not match. Then resume the search **one byte after** the rejected sync, so a corrupt frame never hides the next valid one.
- A jump in `seq` means frames were lost. A jump in `first_index` of `ECG_SAMPLES` gives the exact number of lost samples.

## Messages: device to app

| Type | Name | Payload |
|---|---|---|
| `0x01` | HELLO | `u16 sample_rate`, `u8 id_len`, `id` (UTF-8), `u8 fw_len`, `firmware` (UTF-8) |
| `0x10` | ECG_SAMPLES | `u32 first_index`, then `i16` samples in µV |
| `0x11` | HEART_RATE | `u8 bpm`, `u16 rr_ms` |
| `0x12` | BATTERY | `u8 percent` |
| `0x13` | ALARM | `u8 code`, `u8 active` (1 raised, 0 cleared) |
| `0x14` | FW_STATUS | `u8 state`, `u32 received`, `u8 len`, `detail` (UTF-8) |
| `0x7F` | ACK | `u16 acked_seq`, `u8 result` |

Alarm codes: `1` LEAD_OFF, `2` LOW_BATTERY.

ACK results:
- `0` OK;
- `1` UNKNOWN_COMMAND;
- `2` INVALID_STATE (for example START while already streaming).

## Messages: app to device

| Type | Name | Payload |
|---|---|---|
| `0x20` | START_STREAM | empty |
| `0x21` | STOP_STREAM | empty |
| `0x22` | PING | empty |
| `0x30` | FW_BEGIN | `u32 size`, `u32 crc32`, `u8 len`, `version` (UTF-8) |
| `0x31` | FW_CHUNK | `u32 offset`, then up to 512 image bytes |
| `0x32` | FW_COMMIT | empty |
| `0x33` | FW_ABORT | empty |

The device answers every command with an ACK that carries the command's `seq`. The firmware commands are the exception: they get a FW_STATUS instead (see below).

## Session

1. The app connects. The device accepts one client at a time and closes any other connection straight away.
2. The device sends HELLO, then BATTERY.
3. The app sends START_STREAM. The device sends ACK, then ECG_SAMPLES (10 frames per second, `first_index` starting at 0), HEART_RATE on every beat after the first, BATTERY whenever the whole-percent value changes, and ALARM on every change.
4. The app sends STOP_STREAM. The device sends ACK and stops streaming.
5. If the link drops, the app reconnects and starts again from step 2.

## Firmware update

The short version: send the image in small pieces, let the device tell you how much it has, and only switch versions once everything checks out.

**Image file.** `b"PBFW"`, then the version as 16 bytes of NUL-padded ASCII, then the program. The simulator builds one with `python -m pulsebridge_sim.firmware 1.1.0 out.bin`; the app ships `pulsebridge-1.1.0.bin`.

**FW_STATUS states:** `0` IDLE, `1` RECEIVING, `2` INSTALLED, `3` REJECTED. `received` is how many image bytes the device holds right now, which is what makes resuming work.

**The dance:**

1. App sends **FW_BEGIN** with size, CRC-32 and version. If the device already has part of *that same image* (same size, CRC and version), it keeps it and answers RECEIVING with `received` > 0. Anything else starts from zero.
2. App sends **FW_CHUNK** at offset `received`, waits for the FW_STATUS, sends the next one. A chunk at the wrong offset changes nothing; the status just tells the app where to carry on.
3. When `received == size`, app sends **FW_COMMIT**. The device checks size, CRC-32 and the header (magic + version).
   - All good: INSTALLED, then the device closes the link and restarts (~2 s). Its next HELLO carries the new version, and only then does the app call the update done.
   - Anything wrong: REJECTED with a reason, and the old firmware keeps running.
4. **FW_ABORT** throws away the partial image.

**Rules that keep it safe:**

- No update while streaming: the device answers REJECTED, and the app doesn't even offer it during a recording.
- No answer within 1.5 s? The app resends the last command (duplicates are harmless). After 8 tries it gives up.
- Link drops mid-transfer? The app waits, reconnects, sends FW_BEGIN again and continues from what the device kept.
- CRC-32 catches broken images, not malicious ones. A real device would check a signature (e.g. ECDSA) in its bootloader; that's out of scope here.

Simulator faults to try it out: `--fw-drop-after BYTES` (drops the link once mid-transfer) and `--fw-corrupt` (a "flash write error", so the CRC fails at commit).
