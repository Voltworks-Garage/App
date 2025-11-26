import 'dart:io' show Platform;
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

/// Service to manage foreground notification for maintaining BLE connection in background
/// Uses flutter_foreground_task for proper Android foreground service implementation
class ForegroundService {
  static bool _isRunning = false;

  /// Initialize foreground service (call once at app startup)
  static Future<void> initialize() async {
    if (!Platform.isAndroid) {
      // Only needed on Android
      return;
    }

    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'voltworks_ble_channel',
        channelName: 'BLE Connection',
        channelDescription: 'Maintains connection to motorcycle',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.nothing(),
      ),
    );
  }

  /// Start foreground notification
  /// This keeps the app "active" from Android's perspective, preventing BLE disconnection
  static Future<void> start() async {
    if (!Platform.isAndroid) {
      // iOS doesn't need foreground service (uses bluetooth-central background mode)
      return;
    }

    if (_isRunning) {
      return;
    }

    try {
      // Check notification permission (Android 13+)
      final NotificationPermission permission = await FlutterForegroundTask.requestNotificationPermission();

      if (permission == NotificationPermission.granted) {
        // Start the foreground service
        await FlutterForegroundTask.startService(
          serviceId: 1,
          notificationTitle: 'Voltworks Garage',
          notificationText: 'Connected to motorcycle BMS',
          callback: _foregroundTaskCallback,
        );

        _isRunning = true;
        print('ForegroundService: Started successfully');
      }
    } catch (e) {
      print('ForegroundService: Failed to start: $e');
    }
  }

  /// Stop foreground notification
  static Future<void> stop() async {
    if (!Platform.isAndroid) {
      return;
    }

    if (!_isRunning) {
      return;
    }

    try {
      await FlutterForegroundTask.stopService();
      _isRunning = false;
      print('ForegroundService: Stopped');
    } catch (e) {
      print('ForegroundService: Failed to stop: $e');
    }
  }

  /// Update notification text
  static Future<void> updateNotification(String text) async {
    if (!Platform.isAndroid || !_isRunning) {
      return;
    }

    await FlutterForegroundTask.updateService(
      notificationTitle: 'Voltworks Garage',
      notificationText: text,
    );
  }

  /// Check if service is running
  static bool get isRunning => _isRunning;
}

/// Callback function for foreground task
/// This is called periodically by the foreground service
@pragma('vm:entry-point')
void _foregroundTaskCallback() {
  // This callback is required but we don't need to do anything here
  // The foreground service just needs to be running to keep the app alive
}
