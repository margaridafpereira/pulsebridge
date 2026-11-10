import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../sessions/session_repository.dart';

/// How the app reaches the device.
enum DeviceConnectionKind {
  /// The PulseBridge ECG simulator over TCP: ECG, heart rate, alarms.
  simulator,

  /// A standard Bluetooth LE heart-rate sensor: heart rate and RR intervals only.
  bluetooth,
}

class AppSettings {
  const AppSettings({
    this.connection = DeviceConnectionKind.simulator,
    this.host = '10.0.2.2',
    this.port = 7878,
    this.bleAddress,
    this.bleName,
    this.hrLow = 40,
    this.hrHigh = 130,
    this.fhirServer = '',
    this.language = 'system',
  });

  final DeviceConnectionKind connection;

  /// The emulator reaches the PC running the simulator at 10.0.2.2.
  final String host;
  final int port;

  /// The last Bluetooth sensor used, offered first next time.
  final String? bleAddress;
  final String? bleName;
  final int hrLow;
  final int hrHigh;

  /// Base URL of a FHIR R4 server for exports; empty when none is set.
  final String fhirServer;

  /// 'system' follows the phone; 'en' or 'pt' forces a language.
  final String language;

  AppSettings copyWith({
    DeviceConnectionKind? connection,
    String? host,
    int? port,
    String? Function()? bleAddress,
    String? Function()? bleName,
    int? hrLow,
    int? hrHigh,
    String? fhirServer,
    String? language,
  }) =>
      AppSettings(
        connection: connection ?? this.connection,
        host: host ?? this.host,
        port: port ?? this.port,
        bleAddress: bleAddress != null ? bleAddress() : this.bleAddress,
        bleName: bleName != null ? bleName() : this.bleName,
        hrLow: hrLow ?? this.hrLow,
        hrHigh: hrHigh ?? this.hrHigh,
        fhirServer: fhirServer ?? this.fhirServer,
        language: language ?? this.language,
      );

  Map<String, Object?> toJson() => {
        'connection': connection.name,
        'host': host,
        'port': port,
        'bleAddress': bleAddress,
        'bleName': bleName,
        'hrLow': hrLow,
        'hrHigh': hrHigh,
        'fhirServer': fhirServer,
        'language': language,
      };

  factory AppSettings.fromJson(Map<String, Object?> json) {
    const d = AppSettings();
    return AppSettings(
      connection: DeviceConnectionKind.values.asNameMap()[json['connection']] ?? d.connection,
      host: json['host'] as String? ?? d.host,
      port: json['port'] as int? ?? d.port,
      bleAddress: json['bleAddress'] as String?,
      bleName: json['bleName'] as String?,
      hrLow: json['hrLow'] as int? ?? d.hrLow,
      hrHigh: json['hrHigh'] as int? ?? d.hrHigh,
      fhirServer: json['fhirServer'] as String? ?? d.fhirServer,
      language: json['language'] as String? ?? d.language,
    );
  }
}

final blobStoreProvider = Provider<BlobStore>((ref) => const KeystoreBlobStore());

final settingsProvider = AsyncNotifierProvider<SettingsController, AppSettings>(SettingsController.new);

/// Settings live in the same encrypted store as the sessions.
class SettingsController extends AsyncNotifier<AppSettings> {
  static const file = 'settings.json';

  @override
  Future<AppSettings> build() async {
    final bytes = await ref.watch(blobStoreProvider).read(file);
    if (bytes == null) return const AppSettings();
    return AppSettings.fromJson(jsonDecode(utf8.decode(bytes)) as Map<String, Object?>);
  }

  Future<void> save(AppSettings settings) async {
    state = AsyncData(settings);
    await ref.read(blobStoreProvider).write(file, utf8.encode(jsonEncode(settings.toJson())));
  }
}
