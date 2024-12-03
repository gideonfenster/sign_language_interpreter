import 'package:flutter/material.dart';
import 'settings_page.dart';
import 'interpreter_page.dart';
import 'bluetooth_page.dart';
import 'ble_data_ingestion.dart';

class AppDrawer extends StatelessWidget {
  final Color backgroundColor;
  final Color textColor;
  final double textSize;
  final VoidCallback reloadSettings;

  const AppDrawer({
    Key? key,
    required this.backgroundColor,
    required this.textColor,
    required this.textSize,
    required this.reloadSettings,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Container(
        color: backgroundColor,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                color: backgroundColor,
              ),
              child: Text(
                'Menu',
                style: TextStyle(
                  color: textColor,
                  fontSize: textSize + 4,
                ),
              ),
            ),
            ListTile(
              title: Text(
                'ASL Interpreter',
                style: TextStyle(
                  color: textColor,
                  fontSize: textSize,
                ),
              ),
              onTap: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => InterpreterPage()),
                );
              },
            ),
            ListTile(
              title: Text(
                'Bluetooth Connection',
                style: TextStyle(
                  color: textColor,
                  fontSize: textSize,
                ),
              ),
              onTap: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const BluetoothPage()),
                );
              },
            ),
            ListTile(
              title: Text(
                'BLE & ML Metrics',
                style: TextStyle(
                  color: textColor,
                  fontSize: textSize,
                ),
              ),
              onTap: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const BLEDataIngestionPage()),
                );
              },
            ),
            ListTile(
              title: Text(
                'Settings',
                style: TextStyle(
                  color: textColor,
                  fontSize: textSize,
                ),
              ),
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SettingsPage()),
                );
                reloadSettings();
              },
            ),
          ],
        ),
      ),
    );
  }
}
