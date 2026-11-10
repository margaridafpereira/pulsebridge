import 'package:device_link/device_link_method_channel.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final platform = MethodChannelDeviceLink();
  final calls = <MethodCall>[];

  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      platform.methodChannel,
      (call) async {
        calls.add(call);
        return call.method == 'isStreaming' ? true : null;
      },
    );
  });

  test('connect passes host and port', () async {
    await platform.connect('10.0.2.2', 7878);
    expect(calls.single.method, 'connect');
    expect(calls.single.arguments, {'host': '10.0.2.2', 'port': 7878});
  });

  test('isStreaming returns the native value', () async {
    expect(await platform.isStreaming(), isTrue);
  });
}
