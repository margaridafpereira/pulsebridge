/// A Bluetooth LE device found by a scan.
class BleDevice {
  const BleDevice({required this.address, this.name, required this.rssi, required this.heartRate});

  final String address;
  final String? name;

  /// Signal strength in dBm; closer to 0 is nearer.
  final int rssi;

  /// The device advertises the standard Heart Rate Service (0x180D).
  final bool heartRate;

  factory BleDevice.fromMap(Map<Object?, Object?> map) => BleDevice(
        address: map['address']! as String,
        name: map['name'] as String?,
        rssi: map['rssi']! as int,
        heartRate: map['heartRate'] as bool? ?? false,
      );
}

class BluetoothState {
  const BluetoothState({required this.supported, required this.enabled, required this.permitted});

  final bool supported;
  final bool enabled;
  final bool permitted;

  factory BluetoothState.fromMap(Map<Object?, Object?> map) => BluetoothState(
        supported: map['supported'] as bool? ?? false,
        enabled: map['enabled'] as bool? ?? false,
        permitted: map['permitted'] as bool? ?? false,
      );
}
