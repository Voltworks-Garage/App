import 'dart:async';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../utils/constants.dart';
import 'foreground_service.dart';

/// BLE Service for managing Bluetooth Low Energy connections
class BleService {
  // Singleton pattern
  static final BleService _instance = BleService._internal();
  factory BleService() => _instance;
  BleService._internal();

  // Current connected device
  BluetoothDevice? _connectedDevice;
  BluetoothCharacteristic? _txCharacteristic; // ESP32 -> App
  BluetoothCharacteristic? _rxCharacteristic; // App -> ESP32

  // Connection state subscription
  StreamSubscription<BluetoothConnectionState>? _connectionStateSubscription;

  // Characteristic data subscription
  StreamSubscription<List<int>>? _characteristicSubscription;

  // Connection state
  final _connectionStateController = StreamController<bool>.broadcast();
  Stream<bool> get connectionState => _connectionStateController.stream;
  bool get isConnected {
    final connected = _connectedDevice != null;
    print('BleService.isConnected getter called: $connected (device: $_connectedDevice)');
    return connected;
  }

  // Data stream from device
  final _dataStreamController = StreamController<String>.broadcast();
  Stream<String> get dataStream => _dataStreamController.stream;

  // Scan results
  final _scanResultsController = StreamController<List<ScanResult>>.broadcast();
  Stream<List<ScanResult>> get scanResults => _scanResultsController.stream;
  final List<ScanResult> _discoveredDevices = [];

  // Error messages
  final _errorController = StreamController<String>.broadcast();
  Stream<String> get errors => _errorController.stream;

  /// Check if Bluetooth is available and enabled
  Future<bool> isBluetoothAvailable() async {
    try {
      if (await FlutterBluePlus.isSupported == false) {
        _errorController.add('Bluetooth is not supported on this device');
        return false;
      }

      // Check if adapter is on
      var state = await FlutterBluePlus.adapterState.first;
      if (state != BluetoothAdapterState.on) {
        _errorController.add('Bluetooth is turned off. Please enable Bluetooth.');
        return false;
      }

      return true;
    } catch (e) {
      _errorController.add('Error checking Bluetooth: $e');
      return false;
    }
  }

  /// Start scanning for BLE devices (shows ALL devices)
  Future<void> startScan() async {
    try {
      // Check Bluetooth availability
      if (!await isBluetoothAvailable()) {
        return;
      }

      // Clear previous results
      _discoveredDevices.clear();

      // Listen to scan results
      FlutterBluePlus.scanResults.listen((results) {
        _discoveredDevices.clear();
        _discoveredDevices.addAll(results);
        _scanResultsController.add(List.from(_discoveredDevices));
      });

      // Start scanning - no filters, show everything
      await FlutterBluePlus.startScan(
        timeout: BleConstants.scanDuration,
      );
    } catch (e) {
      _errorController.add('Error starting scan: $e');
    }
  }

  /// Stop scanning
  Future<void> stopScan() async {
    try {
      await FlutterBluePlus.stopScan();
    } catch (e) {
      _errorController.add('Error stopping scan: $e');
    }
  }

  /// Connect to a BLE device
  Future<bool> connect(BluetoothDevice device) async {
    try {
      // Disconnect from any existing device
      if (_connectedDevice != null) {
        await disconnect();
      }

      // Connect to device
      // Note: Cannot use autoConnect because ESP32 initiates MTU changes
      // Connection will be maintained by not calling disconnect() when app backgrounds
      await device.connect(
        timeout: BleConstants.connectionTimeout,
      );
      _connectedDevice = device;

      // Cancel any existing connection state subscription
      await _connectionStateSubscription?.cancel();

      // Listen to connection state
      _connectionStateSubscription = device.connectionState.listen((state) {
        print('BleService: Connection state changed to $state');
        if (state == BluetoothConnectionState.disconnected) {
          _handleDisconnection();
        }
      });

      // Discover services
      List<BluetoothService> services = await device.discoverServices();

      // Find UART service and characteristics
      bool foundUartService = false;

      for (var service in services) {
        // Check if this is the UART service
        if (service.uuid.toString().toUpperCase() ==
            BleUuids.uartServiceUuid.toUpperCase()) {
          foundUartService = true;

          for (var characteristic in service.characteristics) {
            String charUuid = characteristic.uuid.toString().toUpperCase();

            // TX Characteristic (receive data from ESP32)
            if (charUuid == BleUuids.txCharacteristicUuid.toUpperCase()) {
              _txCharacteristic = characteristic;

              // Cancel any existing characteristic subscription
              await _characteristicSubscription?.cancel();

              // Subscribe to notifications
              await characteristic.setNotifyValue(true);
              _characteristicSubscription = characteristic.lastValueStream.listen((value) {
                if (value.isNotEmpty) {
                  String data = String.fromCharCodes(value);
                  _dataStreamController.add(data);
                }
              });
            }

            // RX Characteristic (send data to ESP32)
            if (charUuid == BleUuids.rxCharacteristicUuid.toUpperCase()) {
              _rxCharacteristic = characteristic;
            }
          }
        }
      }

      // Check if we found the required characteristics
      if (foundUartService && _txCharacteristic != null && _rxCharacteristic != null) {
        // Start foreground notification to keep connection alive in background
        await ForegroundService.start();
        _connectionStateController.add(true);
        return true;
      } else {
        // UART service not found, disconnect
        if (!foundUartService) {
          _errorController.add('Device does not support UART service. Not a compatible device.');
        } else {
          _errorController.add('UART service found but characteristics missing.');
        }
        await disconnect();
        return false;
      }
    } catch (e) {
      _errorController.add('Error connecting to device: $e');
      await disconnect();
      return false;
    }
  }

  /// Disconnect from current device
  Future<void> disconnect() async {
    try {
      // Cancel connection state subscription
      await _connectionStateSubscription?.cancel();
      _connectionStateSubscription = null;

      // Cancel characteristic data subscription
      await _characteristicSubscription?.cancel();
      _characteristicSubscription = null;

      if (_connectedDevice != null) {
        await _connectedDevice!.disconnect();
        _handleDisconnection();
      }
    } catch (e) {
      _errorController.add('Error disconnecting: $e');
    }
  }

  /// Handle disconnection
  void _handleDisconnection() {
    print('BleService._handleDisconnection() called!');
    print('  Stack trace: ${StackTrace.current}');
    _connectedDevice = null;
    _txCharacteristic = null;
    _rxCharacteristic = null;
    _connectionStateController.add(false);

    // Stop foreground notification when disconnected
    ForegroundService.stop();
  }

  /// Send data to connected device
  Future<bool> sendData(String data) async {
    try {
      if (_rxCharacteristic == null) {
        _errorController.add('Not connected to a device');
        return false;
      }

      // Convert string to bytes and send
      List<int> bytes = data.codeUnits;
      await _rxCharacteristic!.write(bytes, withoutResponse: false);
      return true;
    } catch (e) {
      _errorController.add('Error sending data: $e');
      return false;
    }
  }

  /// Get connected device name
  String? getDeviceName() {
    return _connectedDevice?.platformName;
  }

  /// Dispose streams
  void dispose() {
    _connectionStateSubscription?.cancel();
    _characteristicSubscription?.cancel();
    _connectionStateController.close();
    _dataStreamController.close();
    _scanResultsController.close();
    _errorController.close();
  }
}
