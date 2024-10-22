import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'package:tflite_flutter/tflite_flutter.dart';

class BLEDataIngestionPage extends StatefulWidget {
  const BLEDataIngestionPage({Key? key, required this.device}) : super(key: key);
  final BluetoothDevice device;

  @override
  _BLEDataIngestionPageState createState() => _BLEDataIngestionPageState();
}

class _BLEDataIngestionPageState extends State<BLEDataIngestionPage> {
  BluetoothCharacteristic? targetCharacteristic;
  StreamSubscription<List<int>>? notificationSubscription;
  List<List<double>> dataWindow = []; // Stores the last 3 seconds of data
  bool _isConnecting = false;
  bool _isConnected = false;
  Timer? uiUpdateTimer;
  Timer? _inferenceTimer;

  Interpreter? _interpreter;
  String _predictionResult = '';
  int _dataWindowSize = 0;
  List<List<double>> _dataSnapshot = [];

  // **New variable to store probabilities**
  List<double> _probabilities = [];

  @override
  void initState() {
    super.initState();
    _loadModel().then((_) {
      print('Model loaded, starting timers');
      _startTimers();
    });
    _connect(widget.device);
  }

  void _startTimers() {
    // Start a timer to run the model every second
    _inferenceTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      _runModel();
    });
    // Start a timer to update the UI every second
    uiUpdateTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      setState(() {
        // Trigger UI update
      });
    });
  }

  @override
  void dispose() {
    notificationSubscription?.cancel();
    uiUpdateTimer?.cancel();
    _inferenceTimer?.cancel();
    _disconnect();
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

  void _connect(BluetoothDevice device) async {
    if (_isConnecting) return;
    _isConnecting = true;

    try {
      print("Connecting to device...");
      await device.connect();
      setState(() {
        _isConnected = true;
      });
      print("Connected to device");

      // Listen for disconnection
      device.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected) {
          print("Device disconnected");
          setState(() {
            _isConnected = false;
            targetCharacteristic = null;
            dataWindow.clear();
            _predictionResult = '';
            _dataWindowSize = 0;
            _dataSnapshot.clear();
            _probabilities.clear();
          });
          notificationSubscription?.cancel();
        }
      });

      // Discover services and characteristics
      await _discoverServices(device);
    } catch (e) {
      print("Connection error: $e");
    } finally {
      _isConnecting = false;
    }
  }

  Future<void> _discoverServices(BluetoothDevice device) async {
    List<BluetoothService> services = await device.discoverServices();
    for (BluetoothService service in services) {
      if (service.uuid == Guid('A07498CA-AD5B-474E-940D-16F1FBE7E8CD')) {
        for (BluetoothCharacteristic c in service.characteristics) {
          if (c.uuid == Guid('51FF12BB-3ED8-46E5-B4F9-D64E2FEC021B') && c.properties.notify) {
            targetCharacteristic = c;
            _startListening();
            return;
          }
        }
      }
    }
    print("Target characteristic not found");
  }

  void _startListening() async {
    if (targetCharacteristic == null) return;
    // Enable notifications
    await targetCharacteristic!.setNotifyValue(true);

    // Listen to the value changes
    notificationSubscription = targetCharacteristic!.value.listen((value) {
      _processData(value);
    });
  }

  void _processData(List<int> value) {
    // Parse the byte array into six float values
    if (value.length >= 24) { // Each float is 4 bytes, 6 floats = 24 bytes
      ByteData byteData = ByteData.sublistView(Uint8List.fromList(value));
      List<double> dataPoints = [];
      for (int i = 0; i < 24; i += 4) {
        double dataPoint = byteData.getFloat32(i, Endian.little);
        dataPoints.add(dataPoint);
      }
      // Add dataPoints to dataWindow
      setState(() {
        dataWindow.add(dataPoints);
        // Keep only the last 60 samples (3 seconds at 20 Hz)
        if (dataWindow.length > 60) {
          dataWindow.removeAt(0);
        }
        _dataWindowSize = dataWindow.length;
      });
    } else {
      print("Received data of unexpected length: ${value.length}");
    }
  }

  void _runModel() async {
    if (_interpreter == null) {
      print("Interpreter is null");
      return;
    }

    // Check if dataWindow has enough data
    if (dataWindow.length < 60) {
      print('Not enough data to run the model');
      return;
    }

    // Prepare input tensor
    int timeSteps = 60;
    int numFeatures = 6;

    // Reshape dataWindow into [1, 60, 6]
    List<List<List<double>>> inputData = [dataWindow];

    // Create output buffer
    var outputShape = _interpreter!.getOutputTensor(0).shape;
    print('Output tensor shape: $outputShape'); // Should print [1, 26]

    // Create output buffer matching the output shape
    List<List<double>> outputData = List.generate(
      outputShape[0],
      (_) => List.filled(outputShape[1], 0.0),
    );

    // Run inference
    try {
      _interpreter!.run(inputData, outputData);

      // Since outputData is now List<List<double>>, access the first element
      List<double> probabilities = outputData[0];

      // Find the predicted class
      double maxValue = -double.infinity;
      int predictedIndex = -1;
      for (int i = 0; i < probabilities.length; i++) {
        if (probabilities[i] > maxValue) {
          maxValue = probabilities[i];
          predictedIndex = i;
        }
      }

      // Map index to letter (assuming A-Z corresponds to indices 0-25)
      String predictedLetter = String.fromCharCode(65 + predictedIndex);

      // Take a snapshot of the last 5 data points
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
        _probabilities = probabilities; // **Store probabilities for display**
      });
      print('Predicted letter: $_predictionResult');
    } catch (e) {
      print('Error running model inference: $e');
    }
  }

  void _disconnect() async {
    if (_isConnected) {
      try {
        await widget.device.disconnect();
        print("Disconnected from device");
      } catch (e) {
        print("Error disconnecting: $e");
      }
    }
  }

  // **Helper function to get the alphabet letters**
  List<String> _getAlphabetLetters() {
    return List.generate(26, (index) => String.fromCharCode(65 + index));
  }

  @override
  Widget build(BuildContext context) {
    List<String> alphabetLetters = _getAlphabetLetters();

    return Scaffold(
      appBar: AppBar(
        title: Text('BLE Data Ingestion'),
      ),
      body: Center(
        child: _isConnected
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Prediction Result: $_predictionResult',
                    style: TextStyle(fontSize: 24),
                  ),
                  SizedBox(height: 10),
                  Text(
                    'Data Window Size: $_dataWindowSize',
                    style: TextStyle(fontSize: 20),
                  ),
                  SizedBox(height: 10),
                  // **Display the probabilities**
                  Text(
                    'Letter Probabilities:',
                    style: TextStyle(fontSize: 20),
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
                                  style: TextStyle(fontSize: 18),
                                ),
                                title: LinearProgressIndicator(
                                  value: probability,
                                  minHeight: 10,
                                ),
                                trailing: Text(
                                  '${(probability * 100).toStringAsFixed(2)}%',
                                  style: TextStyle(fontSize: 16),
                                ),
                              );
                            },
                          )
                        : Text(
                            'Running inference...',
                            style: TextStyle(fontSize: 18),
                          ),
                  ),
                ],
              )
            : Text(
                'Connecting...',
                style: TextStyle(fontSize: 24),
              ),
      ),
    );
  }
}
