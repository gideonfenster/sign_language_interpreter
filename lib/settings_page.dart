import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({Key? key}) : super(key: key);

  @override
  _SettingsPageState createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final List<Color> _lightColors = [
    Colors.white,
    Colors.blue.shade100,
    Colors.green.shade100,
    Colors.yellow.shade100,
    Colors.red.shade100,
    Colors.grey.shade300,
    Colors.orange.shade100,
    Colors.purple.shade100,
  ];
  final List<Color> _darkColors = [
    Colors.black,
    Colors.blue.shade900,
    Colors.green.shade900,
    Colors.yellow.shade900,
    Colors.red.shade900,
    Colors.grey.shade900,
    Colors.orange.shade900,
    Colors.purple.shade900,
  ];

  final List<double> _textSizes = [16, 18, 20, 22, 24, 26, 28, 30, 32, 36, 40];

  Color _selectedBackgroundColor = Colors.white;
  Color _selectedTextColor = Colors.black;
  double _selectedTextSize = 24;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      int bgColorValue = prefs.getInt('backgroundColor') ?? Colors.white.value;
      int textColorValue = prefs.getInt('textColor') ?? Colors.black.value;
      double textSize = prefs.getDouble('textSize') ?? 24;

      _selectedBackgroundColor = Color(bgColorValue);
      _selectedTextColor = Color(textColorValue);
      _selectedTextSize = textSize;
    });
  }

  Future<void> _saveSettings() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setInt('backgroundColor', _selectedBackgroundColor.value);
    await prefs.setInt('textColor', _selectedTextColor.value);
    await prefs.setDouble('textSize', _selectedTextSize);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Settings',
          style: TextStyle(
              color: _selectedTextColor,
            )),
        iconTheme: IconThemeData(
          color: _selectedTextColor,
        ),
        backgroundColor: _selectedBackgroundColor,
      ),
      body: Container(
        color: _selectedBackgroundColor,
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            const Text(
              'Background Color',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            Wrap(
              children: _lightColors.map((color) {
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedBackgroundColor = color;
                    });
                    _saveSettings();
                  },
                  child: Container(
                    margin: const EdgeInsets.all(4),
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: color,
                      border: Border.all(
                        color: _selectedBackgroundColor == color
                            ? Colors.black
                            : Colors.transparent,
                        width: 3,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            const Text(
              'Text Color',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            Wrap(
              children: _darkColors.map((color) {
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedTextColor = color;
                    });
                    _saveSettings();
                  },
                  child: Container(
                    margin: const EdgeInsets.all(4),
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: color,
                      border: Border.all(
                        color: _selectedTextColor == color
                            ? Colors.black
                            : Colors.transparent,
                        width: 3,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            const Text(
              'Text Size',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            Wrap(
              children: _textSizes.map((size) {
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedTextSize = size;
                    });
                    _saveSettings();
                  },
                  child: Container(
                    margin: const EdgeInsets.all(4),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _selectedTextSize == size
                          ? Colors.grey.shade300
                          : Colors.grey.shade200,
                      border: Border.all(
                        color: _selectedTextSize == size
                            ? Colors.black
                            : Colors.transparent,
                        width: 3,
                      ),
                    ),
                    child: Text(
                      size.toInt().toString(),
                      style: TextStyle(fontSize: size),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
