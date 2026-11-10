import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pulsebridge/monitor/qrs_detector.dart';

/// MIT-BIH records downloaded by the simulator (`python -m pulsebridge_sim.mitbih 100 119 201`).
final dataDir = Directory('../simulator/data');

/// Annotation codes that mark a beat (WFDB isqrs table).
const beatCodes = {1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 25, 30, 34, 35, 38};

class Record {
  Record(this.fs, this.microvolts, this.beats);
  final int fs;
  final List<double> microvolts;
  final List<int> beats;
}

/// Minimal WFDB reader: header, format 212 (first signal), MIT annotations.
Record readRecord(String name) {
  final header = File('${dataDir.path}/$name.hea').readAsLinesSync();
  final first = header[0].split(RegExp(r'\s+'));
  final signals = int.parse(first[1]);
  final fs = int.parse(first[2].split('/')[0]);
  final sig = header[1].split(RegExp(r'\s+'));
  final gain = double.parse(sig[2].split(RegExp(r'[(/]'))[0]);
  final baseline = int.parse(sig[4]);

  final dat = File('${dataDir.path}/$name.dat').readAsBytesSync();
  final raw = <int>[];
  for (var i = 0; i + 2 < dat.length; i += 3) {
    raw.add(dat[i] | ((dat[i + 1] & 0x0F) << 8));
    raw.add(dat[i + 2] | ((dat[i + 1] & 0xF0) << 4));
  }
  final uv = <double>[];
  for (var i = 0; i < raw.length; i += signals) {
    final v = raw[i] & 0x800 != 0 ? raw[i] - 4096 : raw[i];
    uv.add((v - baseline) / gain * 1000);
  }

  final atr = File('${dataDir.path}/$name.atr').readAsBytesSync();
  final beats = <int>[];
  var sample = 0;
  for (var i = 0; i + 1 < atr.length;) {
    final word = atr[i] | (atr[i + 1] << 8);
    final code = word >> 10, value = word & 0x3FF;
    i += 2;
    if (code == 0 && value == 0) break;
    if (code == 59) {
      final high = atr[i] | (atr[i + 1] << 8), low = atr[i + 2] | (atr[i + 3] << 8);
      sample += (high << 16) | low;
      i += 4;
    } else if (code == 63) {
      i += value + (value & 1);
    } else if (code < 60) {
      sample += value;
      if (beatCodes.contains(code)) beats.add(sample);
    }
  }
  return Record(fs, uv, beats);
}

/// Linear resampling to the rate the device streams at, as the simulator does.
Int16List resample(List<double> x, int from, int to) {
  final n = x.length * to ~/ from;
  final out = Int16List(n);
  for (var i = 0; i < n; i++) {
    final t = i * from / to;
    final k = t.floor();
    final f = t - k;
    final v = k + 1 < x.length ? x[k] * (1 - f) + x[k + 1] * f : x[k];
    out[i] = v.round().clamp(-32768, 32767);
  }
  return out;
}

/// AAMI EC57 beat-by-beat comparison: a detection within 150 ms of a reference
/// beat is a true positive. The first 10 s (learning) are excluded.
({int tp, int fn, int fp}) compare(List<int> reference, List<int> detected, int fs) {
  final window = (0.150 * fs).round();
  final start = 10 * fs;
  final ref = reference.where((r) => r >= start).toList();
  final det = detected.where((d) => d >= start).toList();
  var tp = 0, i = 0, j = 0;
  while (i < ref.length && j < det.length) {
    final diff = det[j] - ref[i];
    if (diff.abs() <= window) {
      tp++;
      i++;
      j++;
    } else if (diff < 0) {
      j++;
    } else {
      i++;
    }
  }
  return (tp: tp, fn: ref.length - tp, fp: det.length - tp);
}

void main() {
  const rate = 250;
  final records = {'100': 'normal sinus rhythm', '119': 'ventricular bigeminy', '201': 'atrial fibrillation'};
  final available = records.keys.where((r) => File('${dataDir.path}/$r.dat').existsSync()).toList();

  group('QRS detector against MIT-BIH annotations (AAMI EC57)', () {
    var totalTp = 0, totalFn = 0, totalFp = 0;

    for (final name in available) {
      test('record $name (${records[name]})', () {
        final record = readRecord(name);
        final signal = resample(record.microvolts, record.fs, rate);
        final reference = [for (final b in record.beats) b * rate ~/ record.fs];
        final detected = <int>[];
        final detector = QrsDetector(sampleRate: rate, onBeat: detected.add);
        for (var i = 0; i < signal.length; i++) {
          detector.add(i, signal[i]);
        }

        final r = compare(reference, detected, rate);
        totalTp += r.tp;
        totalFn += r.fn;
        totalFp += r.fp;
        final se = r.tp / (r.tp + r.fn), ppv = r.tp / (r.tp + r.fp);
        // ignore: avoid_print
        print('MIT-BIH $name: ${r.tp + r.fn} beats, Se ${(100 * se).toStringAsFixed(2)} %, '
            '+P ${(100 * ppv).toStringAsFixed(2)} % (FN ${r.fn}, FP ${r.fp})');
        expect(se, greaterThan(0.97), reason: 'sensitivity');
        expect(ppv, greaterThan(0.97), reason: 'positive predictivity');
      });
    }

    tearDownAll(() {
      if (totalTp == 0) return;
      // ignore: avoid_print
      print('Gross: Se ${(100 * totalTp / (totalTp + totalFn)).toStringAsFixed(2)} %, '
          '+P ${(100 * totalTp / (totalTp + totalFp)).toStringAsFixed(2)} %');
    });
  }, skip: available.isEmpty ? 'MIT-BIH records not downloaded' : null);
}
