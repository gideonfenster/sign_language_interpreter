import 'dart:ffi';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'ble_data_ingestion.dart';

// BLE Demo Page
class BLEDemoPage extends StatefulWidget {
  const BLEDemoPage({super.key});

  @override
  _BLEDemoPageState createState() => _BLEDemoPageState();
}

class _BLEDemoPageState extends State<BLEDemoPage> {
  List<ScanResult> scanResults = [];
  late StreamSubscription<List<ScanResult>> subscription;
  bool isScanning = false;
  BluetoothDevice? device = null;

  @override
  void initState() {
    super.initState();
    FlutterBluePlus.setLogLevel(LogLevel.verbose, color:false);
  }

  @override
  void dispose() {
    // Cleanup: cancel subscription when scanning stops
    FlutterBluePlus.cancelWhenScanComplete(subscription);
    super.dispose();
  }

  // Start scanning for BLE devices
  Future<void> _startScan() async {
    if (await FlutterBluePlus.isSupported == false) {
      print("Bluetooth not supported by this device");
      return;
    }

    List<BluetoothDevice> devs = FlutterBluePlus.connectedDevices;
    print("Connected devices:");
    for (var d in devs) {
        print(d);
    }

    List<Guid> withServices = [Guid("180F")]; 
    List<BluetoothDevice> sys_devs = await FlutterBluePlus.systemDevices(withServices);
    print("System Devices:");
    for (var d in sys_devs) {
      if(d.platformName == "DESKTOP-4UIEFFB") {
        setState(() {
          device = d;
        });
        return;
      }
    }

    setState(() {
      isScanning = true;
    });
    // Wait for Bluetooth to be enabled & permission granted
    await FlutterBluePlus.adapterState
        .where((state) => state == BluetoothAdapterState.on)
        .first;

    // Listen to scan results
    subscription = FlutterBluePlus.onScanResults.listen(
      (results) {
        if (results.isNotEmpty) {
          setState(() {
            scanResults = results;
          });
          ScanResult r = results.last;
        }
      },
      onError: (e) => print(e),
    );

    FlutterBluePlus.cancelWhenScanComplete(subscription);

    await FlutterBluePlus.adapterState.where((val) => val == BluetoothAdapterState.on).first;

    await FlutterBluePlus.startScan(
      withNames: ['DESKTOP-4UIEFFB'],
      timeout: const Duration(seconds: 30),
    );

    // Wait for scanning to stop
    await FlutterBluePlus.isScanning.where((val) => val == false).first;

    // Stop scanning and update the UI
    setState(() {
      isScanning = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('BLE Demo'),
      ),
      body: Column(
        children: [
          if (isScanning)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Scanning for devices...'),
            ),
          if (device != null)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: ElevatedButton(
                onPressed: () {
                  // Navigator logic inside onPressed callback
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => BLEDataIngestionPage(device: device!),
                    ),
                  );
                },
                child: const Text('Go to Data Ingestion'),
              ),
            ),
          if (!isScanning && scanResults.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('No devices found.'),
            ),
          if (!isScanning && scanResults.isNotEmpty)
            Expanded(
              child: ListView.builder(
                itemCount: scanResults.length,
                itemBuilder: (context, index) {
                  final device = scanResults[index].device;
                  final rssi = scanResults[index].rssi;
                  return ListTile(
                    title: Text(device.name.isNotEmpty ? device.name : 'Unknown Device'),
                    subtitle: Text(device.remoteId.toString()),
                    trailing: Text('$rssi dBm'),
                    onTap: () { Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => BLEDataIngestionPage(device: device),
                        ),
                      );
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