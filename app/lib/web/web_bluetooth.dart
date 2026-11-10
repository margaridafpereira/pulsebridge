// Web Bluetooth exists only in browsers; elsewhere a stub reports it as absent.
export 'web_bluetooth_stub.dart' if (dart.library.js_interop) 'web_bluetooth_web.dart';
