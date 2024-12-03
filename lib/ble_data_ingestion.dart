import 'dart:async';
import 'package:flutter/material.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'bluetooth_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_drawer.dart';

class BLEDataIngestionPage extends StatefulWidget {
  const BLEDataIngestionPage({Key? key}) : super(key: key);

  @override
  _BLEDataIngestionPageState createState() => _BLEDataIngestionPageState();
}

class _BLEDataIngestionPageState extends State<BLEDataIngestionPage> {
  final int windowSize = 150;
  List<List<double>> dataWindow = [];

  Interpreter? _interpreter;
  String _predictionResult = '';
  int _dataWindowSize = 0;
  List<double> _probabilities = [];

  int _dataReceivedCount = 0;
  int _dataReceivedPerSecond = 0;
  Timer? _dataCountTimer;

  StreamSubscription<List<double>>? _dataSubscription;
  StreamSubscription<bool>? _connectionSubscription;
  bool _isConnected = false;

  Timer? uiUpdateTimer;
  Timer? _inferenceTimer;

  Color _backgroundColor = Colors.white;
  Color _textColor = Colors.black;
  double _textSize = 24;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadModel().then((_) {
      print('Model loaded, starting timers');
      _startTimers();
    });

    final bluetoothManager = BluetoothManager();
    _isConnected = bluetoothManager.isConnected;

    _connectionSubscription = bluetoothManager.connectionStream.listen((status) {
      setState(() {
        _isConnected = status;
      });
    });

    _dataSubscription = bluetoothManager.dataStream.listen((dataPoints) {
      setState(() {
        dataWindow.add(dataPoints);
        if (dataWindow.length > windowSize) {
          dataWindow.removeAt(0);
        }
        _dataWindowSize = dataWindow.length;
        _dataReceivedCount++;
      });
    });
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

  void _startTimers() {
    _inferenceTimer = Timer.periodic(Duration(milliseconds: 100), (timer) {
      _runModel();
    });

    uiUpdateTimer = Timer.periodic(Duration(milliseconds: 100), (timer) {
      setState(() {});
    });

    _dataCountTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      setState(() {
        _dataReceivedPerSecond = _dataReceivedCount;
        _dataReceivedCount = 0;
      });
    });
  }

  @override
  void dispose() {
    _dataSubscription?.cancel();
    _connectionSubscription?.cancel();
    uiUpdateTimer?.cancel();
    _inferenceTimer?.cancel();
    _dataCountTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadModel() async {
    try {
      print('Loading model...');
      _interpreter = await Interpreter.fromAsset('assets/asl_model.tflite');
      print('Model loaded successfully');
    } catch (e) {
      print('Error loading model: $e');
    }
  }

  void _runModel() async {
    if (_interpreter == null) {
      print("Interpreter is null");
      return;
    }

    if (dataWindow.length < windowSize) {
      print('Not enough data to run the model');
      return;
    }

    List<List<List<double>>> inputData = [dataWindow];

    var outputShape = _interpreter!.getOutputTensor(0).shape;
    print('Output tensor shape: $outputShape');

    List<List<double>> outputData = List.generate(
      outputShape[0],
      (_) => List.filled(outputShape[1], 0.0),
    );

    try {
      _interpreter!.run(inputData, outputData);

      List<double> probabilities = outputData[0];

      double maxValue = -double.infinity;
      int predictedIndex = -1;
      for (int i = 0; i < probabilities.length; i++) {
        if (probabilities[i] > maxValue) {
          maxValue = probabilities[i];
          predictedIndex = i;
        }
      }

      String predictedLetter = String.fromCharCode(65 + predictedIndex);

      int snapshotSize = 5;
      List<List<double>> snapshot = [];
      if (dataWindow.length >= snapshotSize) {
        snapshot = dataWindow.sublist(dataWindow.length - snapshotSize);
      } else {
        snapshot = List.from(dataWindow);
      }

      setState(() {
        _predictionResult = predictedLetter;
        _dataWindowSize = dataWindow.length;
        _probabilities = probabilities;
      });
      print('Predicted letter: $_predictionResult');
    } catch (e) {
      print('Error running model inference: $e');
    }
  }

  List<String> _getAlphabetLetters() {
    return List.generate(26, (index) => String.fromCharCode(65 + index));
  }

  @override
  Widget build(BuildContext context) {
    List<String> alphabetLetters = _getAlphabetLetters();

    return Scaffold(
      appBar: AppBar(
        title: Text('BLE Data Ingestion',
          style: TextStyle(
                color: _textColor,
              )),
        iconTheme: IconThemeData(
          color: _textColor,
        ),
        backgroundColor: _backgroundColor,
      ),
      drawer: AppDrawer(
        backgroundColor: _backgroundColor,
        textColor: _textColor,
        textSize: _textSize,
        reloadSettings: _loadSettings,
      ),
      backgroundColor: _backgroundColor,
      body: Center(
        child: _isConnected
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Prediction Result: $_predictionResult',
                    style: TextStyle(fontSize: _textSize + 4, color: _textColor),
                  ),
                  SizedBox(height: 10),
                  Text(
                    'Data Window Size: $_dataWindowSize',
                    style: TextStyle(fontSize: _textSize, color: _textColor),
                  ),
                  SizedBox(height: 10),
                  Text(
                    'Data Received per Second: $_dataReceivedPerSecond',
                    style: TextStyle(fontSize: _textSize, fontWeight: FontWeight.bold, color: _textColor),
                  ),
                  SizedBox(height: 20),
                  Text(
                    'Letter Probabilities:',
                    style: TextStyle(fontSize: _textSize, color: _textColor),
                  ),
                  SizedBox(height: 10),
                  Expanded(
                    child: _probabilities.isNotEmpty
                        ? ListView.builder(
                            itemCount: _probabilities.length,
                            itemBuilder: (context, index) {
                              String letter = alphabetLetters[index];
                              double probability = _probabilities[index];
                              return ListTile(
                                leading: Text(
                                  letter,
                                  style: TextStyle(fontSize:  _textSize - 2, color: _textColor),
                                ),
                                title: LinearProgressIndicator(
                                  value: probability,
                                  minHeight: 10,
                                ),
                                trailing: Text(
                                  '${(probability * 100).toStringAsFixed(2)}%',
                                  style: TextStyle(fontSize: _textSize - 2, color: _textColor),
                                ),
                              );
                            },
                          )
                        : Text(
                            'Running inference...',
                            style: TextStyle(fontSize: _textSize - 2, color: _textColor),
                          ),
                  ),
                ],
              )
            : Text(
                'Connecting...',
                style: TextStyle(fontSize: _textSize + 4, color: _textColor),
              ),
      ),
    );
  }
}
