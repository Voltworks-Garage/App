import 'package:flutter/material.dart';

/// App-wide constants for Voltworks Garage

// App Information
class AppInfo {
  static const String appName = 'Voltworks Garage';
  static const String version = '1.0.0';
}

// BLE Service UUIDs (Nordic UART Service - can be customized for your ESP32)
class BleUuids {
  // Nordic UART Service UUID
  static const String uartServiceUuid = '6E400001-B5A3-F393-E0A9-E50E24DCCA9E';

  // TX Characteristic (ESP32 -> App, Notify)
  static const String txCharacteristicUuid = '6E400003-B5A3-F393-E0A9-E50E24DCCA9E';

  // RX Characteristic (App -> ESP32, Write)
  static const String rxCharacteristicUuid = '6E400002-B5A3-F393-E0A9-E50E24DCCA9E';

  // Device name filter (customize based on your ESP32 device name)
  static const String deviceNamePrefix = 'Voltworks';
}

// App Theme Colors
class AppColors {
  // Primary brand colors
  static const Color primary = Color(0xFF00D9FF); // Electric blue
  static const Color primaryDark = Color(0xFF0099CC);
  static const Color accent = Color(0xFFFFB800); // Warning/accent yellow

  // Status colors
  static const Color success = Color(0xFF00C853); // Green
  static const Color warning = Color(0xFFFFB800); // Yellow/Orange
  static const Color danger = Color(0xFFFF1744); // Red
  static const Color info = Color(0xFF2196F3); // Blue

  // UI colors
  static const Color background = Color(0xFF121212);
  static const Color surface = Color(0xFF1E1E1E);
  static const Color surfaceLight = Color(0xFF2C2C2C);

  // Text colors
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFB3B3B3);
  static const Color textDisabled = Color(0xFF666666);

  // Charging colors
  static const Color charging = Color(0xFF00C853);
  static const Color discharging = Color(0xFFFF5722);
  static const Color regenerating = Color(0xFF4CAF50);
  static const Color idle = Color(0xFF9E9E9E);
}

// Text Styles
class AppTextStyles {
  // Dashboard - Large, readable while riding
  static const TextStyle dashboardLarge = TextStyle(
    fontSize: 72,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
  );

  static const TextStyle dashboardMedium = TextStyle(
    fontSize: 48,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  static const TextStyle dashboardLabel = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w500,
    color: AppColors.textSecondary,
    letterSpacing: 1.2,
  );

  // Standard text styles
  static const TextStyle heading1 = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
  );

  static const TextStyle heading2 = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  static const TextStyle heading3 = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  static const TextStyle bodyLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.normal,
    color: AppColors.textPrimary,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.normal,
    color: AppColors.textPrimary,
  );

  static const TextStyle bodySmall = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.normal,
    color: AppColors.textSecondary,
  );

  static const TextStyle caption = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: AppColors.textSecondary,
    letterSpacing: 0.5,
  );
}

// Layout Constants
class AppLayout {
  static const double paddingSmall = 8.0;
  static const double paddingMedium = 16.0;
  static const double paddingLarge = 24.0;
  static const double paddingXLarge = 32.0;

  static const double borderRadiusSmall = 8.0;
  static const double borderRadiusMedium = 12.0;
  static const double borderRadiusLarge = 16.0;

  static const double cardElevation = 4.0;
}

// BLE Constants
class BleConstants {
  static const Duration scanDuration = Duration(seconds: 10);
  static const Duration connectionTimeout = Duration(seconds: 15);
  static const Duration reconnectDelay = Duration(seconds: 3);
  static const int maxReconnectAttempts = 3;
}

// Data Constants
class DataConstants {
  // Battery limits
  static const double minVoltage = 42.0;
  static const double maxVoltage = 58.8;
  static const double nominalVoltage = 52.0;

  // Temperature limits (Celsius)
  static const double minTemp = -10.0;
  static const double maxTemp = 60.0;
  static const double warningTemp = 45.0;
  static const double criticalTemp = 55.0;

  // Cell voltage limits
  static const double minCellVoltage = 3.0;
  static const double maxCellVoltage = 4.2;
  static const double nominalCellVoltage = 3.7;
}

// Message Types (for BLE protocol)
class MessageTypes {
  static const String soc = 'SOC';
  static const String voltage = 'VOLT';
  static const String current = 'CURR';
  static const String temperature = 'TEMP';
  static const String cell = 'CELL';
  static const String status = 'STATUS';
  static const String canMessage = 'CAN';
  static const String error = 'ERROR';
  static const String info = 'INFO';
  static const String auth = 'AUTH';
  static const String config = 'CONFIG';
  static const String get = 'GET';
  static const String reset = 'RESET';
}

// Status Values
class StatusValues {
  static const String idle = 'IDLE';
  static const String charging = 'CHARGING';
  static const String discharging = 'DISCHARGING';
  static const String balancing = 'BALANCING';
  static const String complete = 'COMPLETE';
  static const String error = 'ERROR';
}
