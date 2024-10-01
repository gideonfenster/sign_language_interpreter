import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:flutter_tts/flutter_tts.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'Sign Language Detection',
      home: MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final SpeechToText _speechToText = SpeechToText();
  FlutterTts flutterTts = FlutterTts();
  bool _speechEnabled = false;
  String _lastWords = 'Tap the microphone to start listening';

  @override
  void initState() {
    super.initState();
    _initSpeech();
  }

  /// This has to happen only once per app
  void _initSpeech() async {
    _speechEnabled = await _speechToText.initialize();
    await flutterTts.awaitSpeakCompletion(true);
    setState(() {});
  }

  /// Each time to start a speech recognition session
  void _startListening() async {
    await _speechToText.listen(onResult: _onSpeechResult);
    setState(() {});
  }

  /// Manually stop the active speech recognition session
  /// Note that there are also timeouts that each platform enforces
  /// and the SpeechToText plugin supports setting timeouts on the
  /// listen method.
  void _stopListening() async {
    await _speechToText.stop();
    setState(() {});
  }

  /// This is the callback that the SpeechToText plugin calls when
  /// the platform returns recognized words.
  void _onSpeechResult(SpeechRecognitionResult result) {
    setState(() {
      _lastWords = result.recognizedWords;
    });
  }

  Future _startSpeaking() async {
    await flutterTts.speak(_lastWords);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sign Language Interpreter'),
      ),
      body: Stack(
        children: <Widget>[
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(16),
                child: const Text(
                  'Recognized words:',
                  style: TextStyle(fontSize: 20.0),
                ),
              ),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  child: Text(_lastWords),
                ),
              ),
            ],
          ),
          Padding(
            padding: EdgeInsets.all(16.0),
            child:
              Align(
                alignment: Alignment.bottomRight,
                child: 
                  FloatingActionButton(
                    onPressed:
                        // If not yet listening for speech start, otherwise stop
                        _speechToText.isNotListening ? _startListening : _stopListening,
                    tooltip: 'Listen',
                    child: Icon(_speechToText.isNotListening ? Icons.mic_off : Icons.mic),
                  ),
              ),
          ),
          Padding(
            padding: EdgeInsets.all(16.0),
            child:
              Align(
                alignment: Alignment.bottomLeft,
                child: 
                  FloatingActionButton(
                    onPressed:
                        _startSpeaking,
                    tooltip: 'Speak',
                    child: const Icon(Icons.volume_up),
                  ),
              ),
          )
        ],
      ),
    );
  }
}