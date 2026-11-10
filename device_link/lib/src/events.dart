import 'dart:typed_data';

enum LinkState { connecting, connected, disconnected }

enum DeviceAlarm { leadOff, lowBattery, unknown }

/// Everything the device link reports, decoded from the native event maps.
sealed class DeviceEvent {
  const DeviceEvent();

  /// Returns null for event types this version does not know.
  static DeviceEvent? fromMap(Map<Object?, Object?> map) {
    switch (map['type']) {
      case 'link':
        return LinkChanged(
          LinkState.values.byName(map['state']! as String),
          map['reason'] as String?,
        );
      case 'hello':
        return DeviceInfo(
          map['deviceId']! as String,
          map['firmware']! as String,
          map['sampleRate']! as int,
        );
      case 'ecg':
        return EcgChunk(map['firstIndex']! as int, map['samples']! as Int32List);
      case 'heartRate':
        return HeartRateReading(map['bpm']! as int, map['rrMs']! as int);
      case 'battery':
        return BatteryLevel(map['percent']! as int);
      case 'alarm':
        return DeviceAlarmChanged(
          switch (map['code']) {
            'LEAD_OFF' => DeviceAlarm.leadOff,
            'LOW_BATTERY' => DeviceAlarm.lowBattery,
            _ => DeviceAlarm.unknown,
          },
          map['active']! as bool,
        );
      case 'ack':
        return CommandAck(map['ackedSeq']! as int, map['result']! as String);
      case 'gap':
        return SamplesLost(map['fromIndex']! as int, map['lostSamples']! as int);
      case 'stats':
        return LinkStats(
          crcErrors: map['crcErrors']! as int,
          skippedBytes: map['skippedBytes']! as int,
          lostFrames: map['lostFrames']! as int,
          lostSamples: map['lostSamples']! as int,
        );
      case 'firmware':
        return FirmwareProgress(
          switch (map['stage']) {
            'sending' => FirmwareStage.sending,
            'waiting_for_link' => FirmwareStage.waitingForLink,
            'verifying' => FirmwareStage.verifying,
            'restarting' => FirmwareStage.restarting,
            'done' => FirmwareStage.done,
            'cancelled' => FirmwareStage.cancelled,
            _ => FirmwareStage.failed,
          },
          map['sent']! as int,
          map['total']! as int,
          map['detail'] as String?,
        );
      default:
        return null;
    }
  }
}

class LinkChanged extends DeviceEvent {
  const LinkChanged(this.state, [this.reason]);
  final LinkState state;
  final String? reason;
}

class DeviceInfo extends DeviceEvent {
  const DeviceInfo(this.deviceId, this.firmware, this.sampleRate);
  final String deviceId;
  final String firmware;
  final int sampleRate;
}

/// ECG samples in microvolts. [firstIndex] counts samples since streaming started.
class EcgChunk extends DeviceEvent {
  const EcgChunk(this.firstIndex, this.samples);
  final int firstIndex;
  final Int32List samples;
}

class HeartRateReading extends DeviceEvent {
  const HeartRateReading(this.bpm, this.rrMs);
  final int bpm;
  final int rrMs;
}

class BatteryLevel extends DeviceEvent {
  const BatteryLevel(this.percent);
  final int percent;
}

class DeviceAlarmChanged extends DeviceEvent {
  const DeviceAlarmChanged(this.alarm, this.active);
  final DeviceAlarm alarm;
  final bool active;
}

class CommandAck extends DeviceEvent {
  const CommandAck(this.seq, this.result);
  final int seq;
  final String result;
}

/// ECG samples that never arrived; the trace must show a break here.
class SamplesLost extends DeviceEvent {
  const SamplesLost(this.fromIndex, this.lostSamples);
  final int fromIndex;
  final int lostSamples;
}

enum FirmwareStage { sending, waitingForLink, verifying, restarting, done, failed, cancelled }

/// Progress of a firmware update.
class FirmwareProgress extends DeviceEvent {
  const FirmwareProgress(this.stage, this.sent, this.total, [this.detail]);
  final FirmwareStage stage;
  final int sent;
  final int total;
  final String? detail;

  bool get finished => stage == FirmwareStage.done || stage == FirmwareStage.failed || stage == FirmwareStage.cancelled;
  double get fraction => total == 0 ? 0 : sent / total;
}

class LinkStats extends DeviceEvent {
  const LinkStats({
    required this.crcErrors,
    required this.skippedBytes,
    required this.lostFrames,
    required this.lostSamples,
  });
  final int crcErrors;
  final int skippedBytes;
  final int lostFrames;
  final int lostSamples;
}
