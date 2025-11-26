import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../utils/constants.dart';
import 'foreground_service.dart';

/// Minimal BLE Service - just connect and subscribe to TX/RX
class BleService {
  // Singleton pattern
  static final BleService _instance = BleService._internal();
  factory BleService() => _instance;
  BleService._internal();

  BluetoothDevice? _connectedDevice;
  StreamSubscription<List<int>>? _rxSubscription;
  StreamSubscription<BluetoothConnectionState>? _deviceStateSubscription;
  bool _userDisconnected = false; // Track if disconnect was intentional
  Timer? _reconnectTimeoutTimer; // Timer to give up on reconnection
  BleWriter? _bleWriter; // Writer instance for handling queued writes

  // Streams
  final _connectionStateController = StreamController<bool>.broadcast();
  Stream<bool> get connectionState => _connectionStateController.stream;
  bool get isConnected => _connectedDevice != null;

  // Reconnecting state: device exists but not connected, and wasn't user-initiated disconnect
  bool get isReconnecting => _connectedDevice != null && !_userDisconnected;

  final _dataStreamController = StreamController<String>.broadcast();
  Stream<String> get dataStream => _dataStreamController.stream;

  final _scanResultsController = StreamController<List<ScanResult>>.broadcast();
  Stream<List<ScanResult>> get scanResults => _scanResultsController.stream;

  final _errorController = StreamController<String>.broadcast();
  Stream<String> get errors => _errorController.stream;

  /// Check if Bluetooth is available
  Future<bool> isBluetoothAvailable() async {
    if (await FlutterBluePlus.isSupported == false) {
      _errorController.add('Bluetooth not supported');
      return false;
    }
    var state = await FlutterBluePlus.adapterState.first;
    if (state != BluetoothAdapterState.on) {
      _errorController.add('Bluetooth is off');
      return false;
    }
    return true;
  }

  /// Start scan
  Future<void> startScan() async {
    if (!await isBluetoothAvailable()) return;

    FlutterBluePlus.scanResults.listen((results) {
      _scanResultsController.add(results);
    });

    await FlutterBluePlus.startScan(timeout: BleConstants.scanDuration);
  }

  /// Stop scan
  Future<void> stopScan() async {
    await FlutterBluePlus.stopScan();
  }

  /// Connect to device
  Future<bool> connect(BluetoothDevice device) async {
    try {
      // Disconnect any existing device
      if (_connectedDevice != null) {
        await disconnect();
      }

      // Mark as not user-disconnected (we're initiating a connection)
      _userDisconnected = false;

      // Cancel any existing reconnect timer from previous connections
      _cancelReconnectTimeout();

      // Connect with autoConnect for automatic reconnection
      // mtu: null is required when using autoConnect
      await device.connect(autoConnect: true, mtu: null);
      _connectedDevice = device;

      // Wait for actual connection (autoConnect returns immediately)
      await device.connectionState
          .where((state) => state == BluetoothConnectionState.connected)
          .first;

      // Listen to device connection state changes
      _deviceStateSubscription?.cancel();
      _deviceStateSubscription = device.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected) {
          _connectionStateController.add(false);
          // Start reconnect timeout timer when disconnected ungracefully
          if (!_userDisconnected) {
            _startReconnectTimeout();
          }
        } else if (state == BluetoothConnectionState.connected) {
          _connectionStateController.add(true);
          // Cancel timeout timer on successful reconnection
          _cancelReconnectTimeout();
        }
      });

      // Discover services
      List<BluetoothService> services = await device.discoverServices();

      // Find UART service
      for (var service in services) {
        if (service.uuid.toString().toUpperCase() == BleUuids.uartServiceUuid.toUpperCase()) {

          for (var char in service.characteristics) {
            String uuid = char.uuid.toString().toUpperCase();

            // TX characteristic (ESP32 -> App)
            if (uuid == BleUuids.txCharacteristicUuid.toUpperCase()) {
              await char.setNotifyValue(true);
              _rxSubscription = char.lastValueStream.listen((value) {
                if (value.isNotEmpty) {
                  _dataStreamController.add(String.fromCharCodes(value));
                }
              });
            }
          }
        }
      }

      _connectionStateController.add(true);

      // Initialize BLE writer for this device
      _bleWriter = BleWriter(device);

      // Start foreground service to keep connection alive
      await ForegroundService.start();

      return true;
    } catch (e) {
      _errorController.add('Connection error: $e');
      _connectedDevice = null;
      return false;
    }
  }

  /// Disconnect
  Future<void> disconnect() async {
    // Mark as user-initiated disconnect
    _userDisconnected = true;

    // Cancel reconnect timeout timer
    _cancelReconnectTimeout();

    await _rxSubscription?.cancel();
    await _deviceStateSubscription?.cancel();

    // Dispose BLE writer
    _bleWriter?.dispose();
    _bleWriter = null;

    if (_connectedDevice != null) {
      await _connectedDevice!.disconnect();
      _connectedDevice = null;
      _connectionStateController.add(false);

      // Stop foreground service
      await ForegroundService.stop();
    }
  }

  /// Send binary data (Uint8List) - primary method for protocol messages
  Future<bool> sendBytes(Uint8List data) async {
    if (_bleWriter == null) {
      _errorController.add('Not connected');
      return false;
    }

    try {
      return await _bleWriter!.sendBytes(data);
    } catch (e) {
      _errorController.add('Send error: $e');
      return false;
    }
  }

  /// Send string data - for backward compatibility or text-based commands
  Future<bool> sendData(String data) async {
    if (_bleWriter == null) {
      _errorController.add('Not connected');
      return false;
    }

    try {
      return await _bleWriter!.sendData(data);
    } catch (e) {
      _errorController.add('Send error: $e');
      return false;
    }
  }

  String? getDeviceName() => _connectedDevice?.platformName;

  /// Start reconnect timeout timer
  void _startReconnectTimeout() {
    _cancelReconnectTimeout(); // Cancel any existing timer
    _reconnectTimeoutTimer = Timer(BleConstants.reconnectTimeout, () {
      // Timeout reached - give up and disconnect
      print('BleService: Reconnect timeout reached, giving up');
      disconnect();
    });
  }

  /// Cancel reconnect timeout timer
  void _cancelReconnectTimeout() {
    _reconnectTimeoutTimer?.cancel();
    _reconnectTimeoutTimer = null;
  }

  void dispose() {
    _rxSubscription?.cancel();
    _deviceStateSubscription?.cancel();
    _reconnectTimeoutTimer?.cancel();
    _bleWriter?.dispose();
    _connectionStateController.close();
    _dataStreamController.close();
    _scanResultsController.close();
    _errorController.close();
  }
}

/// BLE Writer class - handles queued writes with MTU-aware chunking
class BleWriter {
  final BluetoothDevice device;
  BluetoothCharacteristic? _rxChar;

  final _writeQueue = StreamController<List<int>>();
  StreamSubscription? _queueSubscription;
  bool _writing = false;

  BleWriter(this.device) {
    _processQueue();
  }

  Future<void> _initRxChar() async {
    if (_rxChar != null) return;

    final services = await device.discoverServices();

    for (var s in services) {
      if (s.uuid.toString().toUpperCase() == BleUuids.uartServiceUuid.toUpperCase()) {
        for (var c in s.characteristics) {
          if (c.uuid.toString().toUpperCase() == BleUuids.rxCharacteristicUuid.toUpperCase()) {
            _rxChar = c;
            return;
          }
        }
      }
    }
    throw Exception("RX characteristic not found");
  }

  /// Send binary data (Uint8List) - primary method for protocol messages
  Future<bool> sendBytes(Uint8List data) async {
    _writeQueue.add(data);
    return true;
  }

  /// Send string data (for backward compatibility or text-based commands)
  Future<bool> sendData(String data) async {
    final bytes = utf8.encode(data);
    _writeQueue.add(bytes);
    return true;
  }

  void _processQueue() {
    _queueSubscription = _writeQueue.stream.listen((bytes) async {
      if (_writing) return;
      _writing = true;

      try {
        await _initRxChar();
        await _chunkAndWrite(bytes);
      } catch (e) {
        print("BLE write error: $e");
      }

      _writing = false;
    });
  }

  Future<void> _chunkAndWrite(List<int> bytes) async {
    // Dynamically read current MTU
    int currentMtu = await device.mtu.first;
    int maxPayload = currentMtu - 3; // BLE ATT overhead

    int index = 0;

    while (index < bytes.length) {
      final end = (index + maxPayload).clamp(0, bytes.length);
      final chunk = bytes.sublist(index, end);
      index = end;

      await _rxChar!.write(
        chunk,
        withoutResponse: !_rxChar!.properties.write,
      );

      await Future.delayed(const Duration(milliseconds: 5));
    }
  }

  void dispose() {
    _queueSubscription?.cancel();
    _writeQueue.close();
  }
}
