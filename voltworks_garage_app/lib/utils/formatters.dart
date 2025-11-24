/// Utility functions for formatting data display
library;

class Formatters {
  /// Format voltage to 2 decimal places with V suffix
  static String voltage(double value) {
    return '${value.toStringAsFixed(2)} V';
  }

  /// Format current to 1 decimal place with A suffix
  /// Negative values indicate discharge
  static String current(double value) {
    return '${value.toStringAsFixed(1)} A';
  }

  /// Format temperature to 1 decimal place with °C suffix
  static String temperature(double value) {
    return '${value.toStringAsFixed(1)} °C';
  }

  /// Format State of Charge as percentage
  static String soc(double value) {
    return '${value.toStringAsFixed(0)}%';
  }

  /// Format power in watts
  static String power(double value) {
    if (value.abs() >= 1000) {
      return '${(value / 1000).toStringAsFixed(2)} kW';
    }
    return '${value.toStringAsFixed(0)} W';
  }

  /// Format time duration (for charging estimates)
  static String duration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);

    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }

  /// Format bytes as hex string (for CAN data)
  static String hexBytes(List<int> bytes) {
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase()).join(' ');
  }

  /// Format CAN ID
  static String canId(int id) {
    return '0x${id.toRadixString(16).toUpperCase().padLeft(8, '0')}';
  }

  /// Format timestamp
  static String timestamp(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:'
           '${time.minute.toString().padLeft(2, '0')}:'
           '${time.second.toString().padLeft(2, '0')}';
  }
}
