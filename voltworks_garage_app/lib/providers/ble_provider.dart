import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/ble_service.dart';

/// Provider for managing BLE state
class BleProvider extends ChangeNotifier {
  final BleService _bleService = BleService();

  // Stream subscriptions
  StreamSubscription? _scanResultsSub;
  StreamSubscription? _connectionStateSub;
  StreamSubscription? _dataStreamSub;
  StreamSubscription? _errorsSub;

  // State
  bool _isScanning = false;
  bool _isConnected = false;
  List<ScanResult> _scanResults = [];
  String? _connectedDeviceName;
  String? _lastError;
  List<String> _receivedMessages = [];

  // Getters
  bool get isScanning => _isScanning;
  bool get isConnected => _isConnected;
  bool get isReconnecting => _bleService.isReconnecting && !_isConnected;
  List<ScanResult> get scanResults => _scanResults;
  String? get connectedDeviceName => _connectedDeviceName;
  String? get lastError => _lastError;
  List<String> get receivedMessages => _receivedMessages;

  BleProvider() {
    _init();
  }

  /// Initialize provider and listen to streams
  void _init() {
    // Initialize with current connection state (important when provider is recreated)
    _isConnected = _bleService.isConnected;
    if (_isConnected) {
      _connectedDeviceName = _bleService.getDeviceName();
    }

    // Listen to scan results
    _scanResultsSub = _bleService.scanResults.listen((results) {
      _scanResults = results;
      notifyListeners();
    });

    // Listen to connection state changes
    _connectionStateSub = _bleService.connectionState.listen((connected) {
      _isConnected = connected;
      if (connected) {
        _connectedDeviceName = _bleService.getDeviceName();
        _lastError = null;
      } else {
        _connectedDeviceName = null;
      }
      notifyListeners();
    });

    // Listen to data stream
    _dataStreamSub = _bleService.dataStream.listen((data) {
      print('Received from device: $data');

      // Add timestamp to message
      final now = DateTime.now();
      final timestamp = '${now.hour.toString().padLeft(2, '0')}:'
                       '${now.minute.toString().padLeft(2, '0')}:'
                       '${now.second.toString().padLeft(2, '0')}';
      _receivedMessages.add('[$timestamp] $data');
      notifyListeners();
    });

    // Listen to errors
    _errorsSub = _bleService.errors.listen((error) {
      print('BLE Error: $error');
      _lastError = error;
      notifyListeners();
    });
  }

  /// Request Bluetooth permissions
  Future<bool> requestPermissions() async {
    try {
      // Request Bluetooth permissions
      Map<Permission, PermissionStatus> statuses = await [
        Permission.bluetooth,
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.location,
      ].request();

      // Check if all permissions granted
      bool allGranted = statuses.values.every((status) => status.isGranted);

      if (!allGranted) {
        _lastError = 'Bluetooth permissions not granted';
        notifyListeners();
      }

      return allGranted;
    } catch (e) {
      _lastError = 'Error requesting permissions: $e';
      notifyListeners();
      return false;
    }
  }

  /// Start scanning for devices
  Future<void> startScan() async {
    try {
      // Request permissions first
      if (!await requestPermissions()) {
        return;
      }

      _isScanning = true;
      _scanResults.clear();
      _lastError = null;
      notifyListeners();

      await _bleService.startScan();

      // Auto-stop after scan duration
      Future.delayed(const Duration(seconds: 10), () {
        if (_isScanning) {
          stopScan();
        }
      });
    } catch (e) {
      _lastError = 'Error starting scan: $e';
      _isScanning = false;
      notifyListeners();
    }
  }

  /// Stop scanning
  Future<void> stopScan() async {
    await _bleService.stopScan();
    _isScanning = false;
    notifyListeners();
  }

  /// Connect to a device
  Future<bool> connect(BluetoothDevice device) async {
    try {
      _lastError = null;
      notifyListeners();

      bool success = await _bleService.connect(device);

      if (!success && _lastError == null) {
        _lastError = 'Failed to connect to device';
        notifyListeners();
      }

      return success;
    } catch (e) {
      _lastError = 'Error connecting: $e';
      notifyListeners();
      return false;
    }
  }

  /// Disconnect from current device
  Future<void> disconnect() async {
    await _bleService.disconnect();
  }

  /// Send data to connected device
  Future<bool> sendData(String data) async {
    bool success = await _bleService.sendData(data);
    if (!success) {
      _lastError = 'Failed to send data';
      notifyListeners();
    }
    return success;
  }

  /// Clear error message
  void clearError() {
    _lastError = null;
    notifyListeners();
  }

  /// Clear received messages
  void clearMessages() {
    _receivedMessages.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    // Cancel all stream subscriptions
    _scanResultsSub?.cancel();
    _connectionStateSub?.cancel();
    _dataStreamSub?.cancel();
    _errorsSub?.cancel();

    // Don't dispose the BleService singleton - it should persist
    // Only dispose this provider's resources
    super.dispose();
  }
}
