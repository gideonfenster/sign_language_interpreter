import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'bluetooth_page.dart';
import 'interpreter_page.dart';

// ASL Interpreter Page
class ASLInterpreterPage extends StatefulWidget {
  const ASLInterpreterPage({super.key});

  @override
  _ASLInterpreterPageState createState() => _ASLInterpreterPageState();
}

class _ASLInterpreterPageState extends State<ASLInterpreterPage> {
  FlutterTts flutterTts = FlutterTts();
  final SpeechToText _speechToText = SpeechToText();
  bool _speechEnabled = false;
  String _lastWords = "Tap the microphone to start listening";
  String _randomText = "Simulated input will appear here"; // Store the accumulated text
  int _itemCount = 0; // Track the number of items added

  // List of random text values
  final List<String> randomValues = [
    "hello",
    "goodbye",
    "please",
    "thank you",
    "yes",
    "no",
    "A",
    "B",
    "C",
    "D",
    "E",
    "F",
    "G",
    "H",
    "I",
    "J",
    "K"
  ];

  Timer? _timer; // Timer for appending values

  @override
  void initState() {
    super.initState();
    _initSpeech(); // Initialize speech recognition on startup
  }

  // Initialize speech-to-text
  void _initSpeech() async {
    _speechEnabled = await _speechToText.initialize();
    setState(() {});
  }

  // Start listening for speech input
  void _startListening() async {
    await _speechToText.listen(onResult: _onSpeechResult);
    setState(() {});
  }

  // Stop listening for speech input
  void _stopListening() async {
    await _speechToText.stop();
    setState(() {});
  }

  // Callback when speech is recognized
  void _onSpeechResult(SpeechRecognitionResult result) {
    setState(() {
      _lastWords = result.recognizedWords;
    });
  }

  // Generate and append random value every second
  void _simulateText() {
    // Reset before starting
    _randomText = "";
    _itemCount = 0;
    _timer?.cancel(); // Cancel any previous timer

    // Start the timer to append one value every second
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_itemCount < 5) {
        // Pick a random value
        final randomIndex = Random().nextInt(randomValues.length);
        final newWord = randomValues[randomIndex];

        // Append the new word to the randomText and speak it
        setState(() {
          _randomText += (_itemCount == 0 ? "" : " ") + newWord;
          _itemCount++;
        });

        _speakText(newWord); // Speak the newly added word
      } else {
        // Stop the timer after 5 items have been added
        timer.cancel();
      }
    });
  }

  // Speak the text aloud
  Future<void> _speakText(String text) async {
    await flutterTts.speak(text);
  }

  @override
  void dispose() {
    _timer?.cancel(); // Cancel the timer when the widget is disposed
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ASL Interpreter'),
      ),
      drawer: _buildDrawer(context),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Header for the top section
              const Text(
                'ASL Interpreter',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),

              // Text box for random generated words
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _randomText,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 24),
                ),
              ),
              const SizedBox(height: 20),

              // Simulate button
              ElevatedButton(
                onPressed: _simulateText,
                child: const Text("Simulate"),
              ),
              const SizedBox(height: 40), // Space between the two sections

              // Header for the bottom section
              const Text(
                'Speech-to-text',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),

              // Text box for speech recognition results
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _lastWords,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 24),
                ),
              ),
              const SizedBox(height: 20),

              // Listen button to start speech recognition
              ElevatedButton(
                onPressed: _speechToText.isNotListening ? _startListening : _stopListening,
                child: Text(_speechToText.isNotListening ? "Listen" : "Stop Listening"),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          const DrawerHeader(
            decoration: BoxDecoration(
              color: Colors.blue,
            ),
            child: Text('Menu'),
          ),
          // ListTile(
          //   title: const Text('ASL Interpreter'),
          //   onTap: () {
          //     Navigator.push(
          //       context,
          //       MaterialPageRoute(builder: (context) => const InterpreterPage()),
          //     );
          //   },
          // ),
          ListTile(
            title: const Text('TTS & STT Demo'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ASLInterpreterPage()),
              );
            },
          ),
          ListTile(
            title: const Text('Bluetooth Connection'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const BluetoothPage()),
              );
            },
          ),
        ],
      ),
    );
  }
}
