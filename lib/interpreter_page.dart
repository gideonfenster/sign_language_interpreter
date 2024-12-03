import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'bluetooth_manager.dart';
import 'app_drawer.dart';

class InterpreterPage extends StatefulWidget {
  InterpreterPage({Key? key}) : super(key: key);

  @override
  _InterpreterPageState createState() => _InterpreterPageState();
}

class _InterpreterPageState extends State<InterpreterPage> with SingleTickerProviderStateMixin {
  final int windowSize = 150;
  List<List<double>> dataWindow = [];
  bool _isMuted = false;
  FlutterTts flutterTts = FlutterTts();
  final SpeechToText _speechToText = SpeechToText();
  bool _speechEnabled = false;
  Timer? _inferenceTimer;
  Timer? uiUpdateTimer;
  String _lastWords = "Tap the microphone to start listening";
  String _interpretedString = "";
  List<String> predictionResults = [];
  List<DateTime> timestamps = [];

  Interpreter? _interpreter;
  String _predictionResult = '';
  int _dataWindowSize = 0;
  List<List<double>> _dataSnapshot = [];

  List<double> _probabilities = [];

  DateTime? _lastDataReceivedTime;

  bool _modelPaused = false;

  StreamSubscription<List<double>>? _dataSubscription;
  StreamSubscription<bool>? _connectionSubscription;
  bool _isConnected = false;

  int _dataReceivedCount = 0;
  int _dataReceivedPerSecond = 0;
  Timer? _dataCountTimer;

  Color _backgroundColor = Colors.white;
  Color _textColor = Colors.black;
  double _textSize = 24;

  @override
  void initState() {
    super.initState();
    _initSpeech();
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
        _lastDataReceivedTime = DateTime.now();

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

  void _initSpeech() async {
    _speechEnabled = await _speechToText.initialize();
    setState(() {});
  }

  void _startListening() async {
    await _speechToText.listen(onResult: _onSpeechResult);
    setState(() {});
  }

  void _stopListening() async {
    await _speechToText.stop();
    setState(() {});
  }

  void _onSpeechResult(SpeechRecognitionResult result) {
    setState(() {
      _lastWords = result.recognizedWords;
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

  Future<void> _speakText(String text) async {
    await flutterTts.speak(text);
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

    if (_modelPaused) {
      print("Model is paused");
      return;
    }

    if (_lastDataReceivedTime == null ||
        DateTime.now().difference(_lastDataReceivedTime!) > const Duration(milliseconds: 500)) {
      setState(() {
        _dataSnapshot.clear();
      });
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

      if (maxValue >= 0.8) {
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
          _dataSnapshot = snapshot;
          _probabilities = probabilities;
        });
        print('Predicted letter: $_predictionResult with confidence ${(maxValue * 100).toStringAsFixed(2)}%');

        predictionResults.add(_predictionResult);
        timestamps.add(DateTime.now());

        while (timestamps.isNotEmpty &&
            DateTime.now().difference(timestamps.first).inSeconds > 30) {
          predictionResults.removeAt(0);
          timestamps.removeAt(0);
        }
        String temp = "";
        for (String res in predictionResults) {
          temp = temp + res + " ";
        }
        if (temp.isNotEmpty) {
          temp = temp.substring(0, temp.length - 1);
        }

        setState(() {
          _interpretedString = temp;
        });

        if (_speechToText.isNotListening && !_isMuted) {
          _speakText(_predictionResult);
        }

        _modelPaused = true;
        Future.delayed(Duration(seconds: 1), () {
          setState(() {
            _modelPaused = false;
          });
        });
      } else {
        print('Prediction confidence below threshold: ${(maxValue * 100).toStringAsFixed(2)}%');
      }
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
        title: Text('ASL Interpreter',
          style: TextStyle(
              color: _textColor,
            )),
        backgroundColor: _backgroundColor,
        iconTheme: IconThemeData(
          color: _textColor,
        ),
      ),
      drawer: AppDrawer(
        backgroundColor: _backgroundColor,
        textColor: _textColor,
        textSize: _textSize,
        reloadSettings: _loadSettings,
      ),
      backgroundColor: _backgroundColor,
      body: Stack(
        children: [
          Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      'ASL Interpreter',
                      style: TextStyle(
                        fontSize: _textSize,
                        fontWeight: FontWeight.bold,
                        color: _textColor,
                      ),
                    ),
                    const SizedBox(height: 10),

                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(8),
                        color: _backgroundColor,
                      ),
                      child: Text(
                        _interpretedString,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: _textSize,
                          color: _textColor,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _isMuted = !_isMuted;
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                      ),
                      child: Text(
                        _isMuted ? "Unmute" : "Mute",
                        style: TextStyle(
                          fontSize: _textSize,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    Text(
                      'Speech-to-text',
                      style: TextStyle(
                        fontSize: _textSize,
                        fontWeight: FontWeight.bold,
                        color: _textColor,
                      ),
                    ),
                    const SizedBox(height: 10),

                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(8),
                        color: _backgroundColor,
                      ),
                      child: Text(
                        _lastWords,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: _textSize,
                          color: _textColor,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    ElevatedButton(
                      onPressed: _speechToText.isNotListening ? _startListening : _stopListening,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                      ),
                      child: Text(
                        _speechToText.isNotListening ? "Listen" : "Stop Listening",
                        style: TextStyle(
                          fontSize: _textSize,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          Positioned(
            top: 10,
            right: 10,
            child: Text(
              _isConnected
                  ? (_dataReceivedPerSecond > 0
                      ? 'Connected - Receiving Data'
                      : 'Connected - No Data')
                  : 'Bluetooth disconnected',
              style: TextStyle(
                color: _isConnected ? (_dataReceivedPerSecond > 0 ? Colors.green : Colors.orange) : Colors.red,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
