import 'dart:async';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter/material.dart';
import 'bluetooth_manager.dart';
import 'interpreter_page.dart';
import 'app_drawer.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BluetoothPage extends StatefulWidget {
  const BluetoothPage({super.key});

  @override
  _BluetoothPageState createState() => _BluetoothPageState();
}

class _BluetoothPageState extends State<BluetoothPage> {
  List<ScanResult> scanResults = [];
  late StreamSubscription<List<ScanResult>> subscription;
  bool isScanning = false;

  Color _backgroundColor = Colors.white;
  Color _textColor = Colors.black;
  double _textSize = 24;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    FlutterBluePlus.setLogLevel(LogLevel.verbose, color: false);
  }

  Future<void> _loadSettings() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      int bgColorValue = prefs.getInt('backgroundColor') ?? Colors.white.value;
      int textColorValue = prefs.getInt('textColor') ?? Colors.black.value;
      double textSize = prefs.getDouble('textSize') ?? 24;

      _backgroundColor = Color(bgColorValue);
      _textColor = Color(textColorValue);
      _textSize = textSize;
    });
  }

  @override
  void dispose() {
    subscription.cancel();
    super.dispose();
  }

  Future<void> _startScan() async {
    if (await FlutterBluePlus.isSupported == false) {
      print("Bluetooth not supported by this device");
      return;
    }

    setState(() {
      isScanning = true;
      scanResults.clear();
    });

    await FlutterBluePlus.adapterState
        .where((state) => state == BluetoothAdapterState.on)
        .first;

    subscription = FlutterBluePlus.scanResults.listen(
      (results) {
        setState(() {
          scanResults = results;
        });
      },
      onError: (e) => print(e),
    );

    await FlutterBluePlus.startScan(
      timeout: const Duration(seconds: 5),
    );

    await FlutterBluePlus.isScanning.where((val) => val == false).first;

    setState(() {
      isScanning = false;
    });

    await subscription.cancel();
  }

  void _connectToDevice(BluetoothDevice device) async {
    final bluetoothManager = BluetoothManager();
    await bluetoothManager.connect(device);
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => InterpreterPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bluetoothManager = BluetoothManager();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: _backgroundColor,
        iconTheme: IconThemeData(
          color: _textColor,
        ),
        title: Text('Bluetooth Connection',
          style: TextStyle(
              color: _textColor,
            )),
      ),
      drawer: AppDrawer(
        backgroundColor: _backgroundColor,
        textColor: _textColor,
        textSize: _textSize,
        reloadSettings: _loadSettings,
      ),
      backgroundColor: _backgroundColor,
      body: Column(
        children: [
          if (isScanning)
            Padding(
              padding: EdgeInsets.all(16),
              child: Text('Scanning for devices...',
                style: TextStyle(
                        fontSize: _textSize,
                        color: _textColor,
                      )),
            ),
          if (!isScanning && scanResults.isEmpty)
            Padding(
              padding: EdgeInsets.all(16),
              child: Text('No devices found. Please scan again.',
                style: TextStyle(
                        fontSize: _textSize,
                        color: _textColor,
                      )),
            ),
          if (!isScanning && scanResults.isNotEmpty)
            Expanded(
              child: ListView.separated(
                itemCount: scanResults.length,
                separatorBuilder: (BuildContext context, int index) => Divider(color: _textColor),
                itemBuilder: (context, index) {
                  final device = scanResults[index].device;
                  final rssi = scanResults[index].rssi;
                  return ListTile(
                    title: Text(device.name.isNotEmpty ? device.name : 'Unknown Device',
                      style: TextStyle(
                        fontSize: _textSize,
                        color: _textColor,
                      )),
                    subtitle: Text(device.remoteId.toString(),
                      style: TextStyle(
                        fontSize: _textSize - 4,
                        color: _textColor,
                      )),
                    trailing: Text('$rssi dBm', 
                      style: TextStyle(
                        fontSize: _textSize - 4,
                        color: _textColor,
                      )),
                    onTap: () {
                      _connectToDevice(device);
                    },
                  );
                },
              ),
            ),
        ],
      ),
      floatingActionButton: isScanning
          ? null
          : FloatingActionButton(
              onPressed: _startScan,
              tooltip: 'Scan Again',
              child: const Icon(Icons.refresh),
            ),
    );
  }
}
