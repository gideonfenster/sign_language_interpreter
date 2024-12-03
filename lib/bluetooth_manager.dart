import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';

class BluetoothManager {
  static final BluetoothManager _instance = BluetoothManager._internal();
  factory BluetoothManager() => _instance;
  BluetoothManager._internal();

  BluetoothDevice? _device;
  BluetoothCharacteristic? _targetCharacteristic;
  StreamSubscription<List<int>>? _notificationSubscription;
  StreamSubscription<BluetoothConnectionState>? _connectionSubscription;
  bool isConnected = false;

  final StreamController<List<double>> _dataStreamController = StreamController.broadcast();
  final StreamController<bool> _connectionStreamController = StreamController.broadcast();

  Stream<List<double>> get dataStream => _dataStreamController.stream;
  Stream<bool> get connectionStream => _connectionStreamController.stream;

  final int windowSize = 150;

  Future<void> connect(BluetoothDevice device) async {
    _device = device;
    try {
      print("Connecting to device...");
      await _device!.connect();
      isConnected = true;
      _connectionStreamController.add(true);
      print("Connected to device");

      _connectionSubscription = _device!.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected) {
          print("Device disconnected");
          isConnected = false;
          _connectionStreamController.add(false);
          _cleanup();
        }
      });

      await _discoverServices();
    } catch (e) {
      print("Connection error: $e");
      isConnected = false;
      _connectionStreamController.add(false);
    }
  }

  Future<void> _discoverServices() async {
    if (_device == null) return;
    List<BluetoothService> services = await _device!.discoverServices();
    for (BluetoothService service in services) {
      if (service.uuid == Guid('A07498CA-AD5B-474E-940D-16F1FBE7E8CD')) {
        for (BluetoothCharacteristic c in service.characteristics) {
          if (c.uuid == Guid('51FF12BB-3ED8-46E5-B4F9-D64E2FEC021B') && c.properties.notify) {
            _targetCharacteristic = c;
            await _startListening();
            return;
          }
        }
      }
    }
    print("Target characteristic not found");
  }

  Future<void> _startListening() async {
    if (_targetCharacteristic == null) return;
    await _targetCharacteristic!.setNotifyValue(true);
    _notificationSubscription = _targetCharacteristic!.value.listen((value) {
      _processData(value);
    });
  }

  void _processData(List<int> value) {
    if (value.length >= 24) {
      ByteData byteData = ByteData.sublistView(Uint8List.fromList(value));
      List<double> dataPoints = [];
      for (int i = 0; i < 24; i += 4) {
        double dataPoint = byteData.getFloat32(i, Endian.little);
        dataPoints.add(dataPoint);
      }
      _dataStreamController.add(dataPoints);
    } else {
      print("Received data of unexpected length: ${value.length}");
    }
  }

  Future<void> disconnect() async {
    await _notificationSubscription?.cancel();
    await _connectionSubscription?.cancel();
    await _targetCharacteristic?.setNotifyValue(false);
    await _device?.disconnect();
    isConnected = false;
    _connectionStreamController.add(false);
    _cleanup();
  }

  void _cleanup() {
    _notificationSubscription = null;
    _connectionSubscription = null;
    _targetCharacteristic = null;
    _device = null;
  }

  void dispose() {
    _dataStreamController.close();
    _connectionStreamController.close();
  }
}
