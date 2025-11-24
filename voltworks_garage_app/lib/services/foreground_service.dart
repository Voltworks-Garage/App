import 'package:flutter/services.dart';

/// Service to manage foreground notification for maintaining BLE connection in background
class ForegroundService {
  static const MethodChannel _channel =
      MethodChannel('com.voltworks.ble/foreground');

  /// Start foreground notification
  /// This keeps the app "active" from Android's perspective, preventing BLE disconnection
  static Future<void> start() async {
    try {
      await _channel.invokeMethod('startForeground');
      print('Foreground notification started');
    } on PlatformException catch (e) {
      print('Failed to start foreground notification: ${e.message}');
    }
  }

  /// Stop foreground notification
  static Future<void> stop() async {
    try {
      await _channel.invokeMethod('stopForeground');
      print('Foreground notification stopped');
    } on PlatformException catch (e) {
      print('Failed to stop foreground notification: ${e.message}');
    }
  }
}
