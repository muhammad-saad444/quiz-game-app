import 'dart:async';
import 'dart:math';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:vosk_flutter_2/vosk_flutter_2.dart';
import 'package:record/record.dart'; // 👈 Added custom recorder import
import 'package:permission_handler/permission_handler.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class GameController extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  int _currentNumber = 0;
  int _score = 0;
  int _timeLeft = 20;
  int _questionCount = 0;
  Timer? _timer;
  bool _isGameActive = false;
  bool _isListening = false;
  bool _hasStarted = false;
  bool _isPaused = false;
  bool _isCountingDown = false;
  bool _canAcceptSpeech = false;
  int _countdownValue = 0;
  String _lastResult = "";

  int _digits = 1;
  int _hopValue = 1;
  final int _maxQuestions = 30;

  // Vosk Core Engine Engine Components
  final VoskFlutterPlugin _vosk = VoskFlutterPlugin.instance();
  Model? _model;
  Recognizer? _recognizer;
  bool _isSpeechInitialized = false;

  // Manual Stream Controller Properties
  final AudioRecorder _audioRecorder = AudioRecorder();
  StreamSubscription<Uint8List>? _audioStreamSubscription;

  // Getters
  int get currentNumber => _currentNumber;
  int get score => _score;
  int get timeLeft => _timeLeft;
  int get questionCount => _questionCount;
  bool get isGameActive => _isGameActive;
  bool get isListening => _isListening;
  bool get isPaused => _isPaused;
  bool get isCountingDown => _isCountingDown;
  int get countdownValue => _countdownValue;
  String get lastResult => _lastResult;

  String get _categoryKey => "digits_${_digits}_hop_${_hopValue}";

  void togglePause() {
    if (!_isGameActive || _isCountingDown) return;
    _isPaused = !_isPaused;
    if (_isPaused) {
      _timer?.cancel();
      _timer = null;
      _stopAudioStream();
      _isListening = false;
      saveGameStateToFirestore();
    } else {
      if (_hasStarted) {
        _startTimer();
        startListening();
      }
    }
    notifyListeners();
  }

  void resetAndStop({bool shouldNotify = false}) {
    _isGameActive = false;
    _isPaused = false;
    _isCountingDown = false;
    _timer?.cancel();
    _timer = null;
    _stopAudioStream();
    _isListening = false;
    _hasStarted = false;
    _timeLeft = 20;
    _score = 0;
    _questionCount = 0;
    _lastResult = "";
    if (shouldNotify) notifyListeners();
  }

  Future<bool> initializeSpeech() async {
    if (_isSpeechInitialized) return true;
    try {
      // 1. Check permissions safely in the background
      final hasPermission = await _audioRecorder.hasPermission();
      if (!hasPermission) {
        debugPrint("❌ Mic permission rejected by native OS layer during warm up.");
        return false;
      }

      debugPrint("⏳ Loading offline voice model asset in background...");

      // 2. Load and extract the dictionary model
      final modelPath = await ModelLoader().loadFromAssets(
          'assets/models/vosk-model-small-en-us-0.15.zip'
      );
      _model = await _vosk.createModel(modelPath);

      // 3. Register the restricted digit grammar
      _recognizer = await _vosk.createRecognizer(
          model: _model!,
          sampleRate: 16000,
          grammar: [
            'one', 'two', 'three', 'four', 'five', 'six', 'seven', 'eight', 'nine', 'zero', 'and',
            '0', '1', '2', '3', '4', '5', '6', '7', '8', '9',
            'ten', 'eleven', 'twelve', 'thirteen', 'fourteen', 'fifteen', 'sixteen', 'seventeen', 'eighteen', 'nineteen',
            'twenty', 'thirty', 'forty', 'fifty', 'sixty', 'seventy', 'eighty', 'ninety',
            'hundred', 'thousand', 'million' // 👈 ADDED SCALE DICTIONARY TARGETS
          ]
      );

      _isSpeechInitialized = true;
      debugPrint("✅ Vosk Offline Voice Engine Is Fully Warmed Up & Ready!");
      notifyListeners(); // Let the UI know it can unlock the mic button now
      return true;
    } catch (e) {
      debugPrint("Offline speech model loading failure: $e");
      _isSpeechInitialized = false;
      return false;
    }
  }

  void startNewGame(int digits, int hopValue) async {
    resetAndStop(shouldNotify: false);
    _digits = digits;
    _hopValue = hopValue;
    _isGameActive = true;

    User? currentUser = _auth.currentUser;
    if (currentUser != null) {
      try {
        DocumentSnapshot userDoc = await _db.collection('users').doc(currentUser.uid).get();
        if (userDoc.exists && userDoc.data() != null) {
          Map<String, dynamic> data = userDoc.data() as Map<String, dynamic>;

          if (data['scoreHistory'] != null && data['scoreHistory'][_categoryKey] != null) {
            Map<String, dynamic> history = data['scoreHistory'][_categoryKey] as Map<String, dynamic>;
            int savedQuestion = history['currentQuestion'] ?? 0;

            if (savedQuestion < _maxQuestions) {
              _questionCount = savedQuestion;
              _score = history['totalScore'] ?? 0;
            }
          }
        }
      } catch (e) {
        debugPrint("Error looking up session data: $e");
      }
    }

    _generateNewNumberOnly();
  }

  void pressPlayButton() async {
    if (!_isGameActive || _isListening || _isPaused || _isCountingDown) return;

    _isCountingDown = true;
    _countdownValue = 3;
    notifyListeners();

    while (_countdownValue > 0) {
      await Future.delayed(const Duration(seconds: 1));
      if (!_isGameActive || _isPaused) return;
      _countdownValue--;
      notifyListeners();
    }

    _isCountingDown = false;
    _hasStarted = true;
    notifyListeners();
    startListening();
  }

  void _generateNewNumberOnly() async {
    if (!_isGameActive || _questionCount >= _maxQuestions) {
      _stopGame();
      return;
    }

    final Random random = Random();
    int min = _digits == 1 ? 1 : pow(10, _digits - 1).toInt();
    int max = pow(10, _digits).toInt() - 1;

    int target;
    int attempts = 0;
    do {
      target = min + random.nextInt(max - min + 1);
      attempts++;
      if (attempts > 100) break;
    } while (target % _hopValue != 0);

    _currentNumber = target;
    _timeLeft = 20;
    _lastResult = "";
    if (_isGameActive) notifyListeners();

    if (_isGameActive && _hasStarted && !_isPaused) {
      // Gives the underlying hardware a 600ms breathing room window to flush out historical voice remnants
      await Future.delayed(const Duration(milliseconds: 600));
      if (_isGameActive && !_isPaused) startListening();
    }
  }

  void startListening() async {
    if (!_isGameActive || _isListening || _isPaused || _isCountingDown) return;

    _isListening = true;
    _startTimer();
    notifyListeners();

    try {
      // 👇 FORCE A WAIT TO ENSURE PERMISSIONS AND BINARIES ARE SECURED FIRST
      if (!_isSpeechInitialized) {
        bool dynamicInit = await initializeSpeech();
        if (!dynamicInit) {
          _isListening = false;
          notifyListeners();
          return;
        }
      }

      _audioStreamSubscription?.cancel();

      final RecordConfig recordConfig = const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: 16000,
        numChannels: 1,
      );

      // Fire up the native recorder stream bridge
      final audioStream = await _audioRecorder.startStream(recordConfig);
      debugPrint("🎙️ Native mic streaming has successfully started!");
      _canAcceptSpeech = true;

      _audioStreamSubscription = audioStream.listen((Uint8List chunk) async {
        if (_recognizer != null && _isListening && !_isPaused) {
          final isFound = await _recognizer!.acceptWaveformBytes(chunk);

          final String jsonString = isFound
              ? await _recognizer!.getResult()
              : await _recognizer!.getPartialResult();

          debugPrint("🎙️ Raw Vosk Matrix Output: $jsonString");

          final Map<String, dynamic> parsed = jsonDecode(jsonString);
          String spokenText = parsed['text'] ?? parsed['partial'] ?? '';

          if (spokenText.isNotEmpty) {
            debugPrint("🎯 Parsed Spoken Text: '$spokenText' (isFinal: $isFound)");
            onSpeechResult(spokenText, isFound);
          }
        }
      });

    } catch (e) {
      debugPrint("Manual stream track init failure: $e");
      _isListening = false;
      notifyListeners();
    }
  }

  void onSpeechResult(String spokenText, bool isFinal) {
    if (!_isGameActive || !_isListening || _isPaused || !_canAcceptSpeech) return;

    // Clean up spaces and formatting for raw string verification
    String cleanSpoken = spokenText.toLowerCase().replaceAll(',', '').replaceAll(' ', '').trim();
    String targetDigit = _currentNumber.toString();

    if (cleanSpoken.isEmpty) return;

    // 1. Single-digit mapping definitions
    final numberWords = {
      'zero': '0', '0': '0',
      'one': '1', '1': '1',
      'two': '2', '2': '2',
      'three': '3', '3': '3',
      'four': '4', '4': '4',
      'five': '5', '5': '5',
      'six': '6', '6': '6',
      'seven': '7', '7': '7',
      'eight': '8', '8': '8',
      'nine': '9', '9': '9'
    };

    // 2. Tens and teens mapping definitions
    final tensWords = {
      'ten': 10, 'eleven': 11, 'twelve': 12, 'thirteen': 13, 'fourteen': 14,
      'fifteen': 15, 'sixteen': 16, 'seventeen': 17, 'eighteen': 18, 'nineteen': 19,
      'twenty': 20, 'thirty': 30, 'forty': 40, 'fifty': 50,
      'sixty': 60, 'seventy': 70, 'eighty': 80, 'ninety': 90
    };

    bool isCorrect = false;

    // --- CHECK 1: Direct Matching ---
    if (cleanSpoken.contains(targetDigit)) {
      isCorrect = true;
    }

    List<String> words = spokenText.toLowerCase().trim().split(RegExp(r'\s+'));

    // --- CHECK 2: Sequence of Spoken Digits ("two nine seven" -> "297") ---
    if (!isCorrect) {
      String digitSequenceStr = "";
      for (var word in words) {
        if (numberWords.containsKey(word)) {
          digitSequenceStr += numberWords[word]!;
        }
      }
      if (digitSequenceStr == targetDigit) {
        isCorrect = true;
      }
    }

    // --- CHECK 3: High-Digit Compound Parser ("seven ninety one" / "two hundred ninety seven") ---
    if (!isCorrect) {
      int totalValue = 0;
      int currentSegmentValue = 0;

      for (var word in words) {
        if (word == 'and') continue;

        if (tensWords.containsKey(word)) {
          // 👇 FIXED: If we already have a single digit (like 'seven') and hit a tens word (like 'ninety'),
          // it means the user said "seven ninety". Shift the single digit to the hundreds place!
          if (currentSegmentValue > 0 && currentSegmentValue < 10) {
            totalValue += currentSegmentValue * 100;
            currentSegmentValue = 0;
          }
          currentSegmentValue += tensWords[word]!;
        } else if (numberWords.containsKey(word)) {
          int val = int.parse(numberWords[word]!);
          // 👇 FIXED: If we hit another single digit back-to-back, push the previous segment value to total
          if (currentSegmentValue > 0 && currentSegmentValue < 10) {
            totalValue += currentSegmentValue * 100;
            currentSegmentValue = 0;
          }
          currentSegmentValue += val;
        } else if (word == 'hundred') {
          currentSegmentValue = (currentSegmentValue == 0 ? 1 : currentSegmentValue) * 100;
        } else if (word == 'thousand') {
          currentSegmentValue = (currentSegmentValue == 0 ? 1 : currentSegmentValue) * 1000;
          totalValue += currentSegmentValue;
          currentSegmentValue = 0;
        } else if (word == 'million') {
          currentSegmentValue = (currentSegmentValue == 0 ? 1 : currentSegmentValue) * 1000000;
          totalValue += currentSegmentValue;
          currentSegmentValue = 0;
        }
      }

      totalValue += currentSegmentValue;

      if (totalValue > 0 && totalValue.toString() == targetDigit) {
        isCorrect = true;
      }
    }

    // --- MATCH EXECUTION BLOCKS ---
    if (isCorrect) {
      debugPrint("🎯 MATCH FOUND! User successfully matched target: $_currentNumber");
      _canAcceptSpeech = false;
      _stopAudioStream();
      _stopListeningAndAdvance(bonus: _timeLeft, feedback: "CORRECT!");
      return;
    }

    if (isFinal) {
      debugPrint("❌ FINAL MISMATCH: Spoken phrase completed incorrectly. Advancing to next question.");
      _canAcceptSpeech = false;
      _stopAudioStream();
      _stopListeningAndAdvance(bonus: 0, feedback: "WRONG!");
    }
  }

  void _stopAudioStream() {
    _audioStreamSubscription?.cancel();
    _audioStreamSubscription = null;
    _audioRecorder.stop();
    _recognizer?.reset();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_isGameActive || _isPaused) {
        timer.cancel();
        return;
      }

      if (_timeLeft > 0) {
        _timeLeft--;
        notifyListeners();
      } else {
        // ⏰ Clock hit 0! This is where the WRONG response safely belongs.
        timer.cancel();
        _canAcceptSpeech = false;
        _stopAudioStream();
        _stopListeningAndAdvance(bonus: 0, feedback: "WRONG!");
      }
    });
  }

  void _handleTimeout() {
    if (!_isGameActive || _isPaused) return;
    _timer?.cancel();
    _timer = null;
    _isListening = false;
    _stopAudioStream();
    _stopListeningAndAdvance(bonus: -20, feedback: "TIMEOUT!");
  }

  void _stopListeningAndAdvance({required int bonus, required String feedback}) async {
    if (!_isGameActive) return;
    _timer?.cancel();
    _timer = null;
    _isListening = false;
    _canAcceptSpeech = false;
    _lastResult = feedback;
    _score += bonus;
    _questionCount++;
    notifyListeners();

    // 👇 FIXED: Clear the speech processor memory completely so old phrases don't overlap
    _recognizer?.reset();

    saveGameStateToFirestore();

    await Future.delayed(const Duration(milliseconds: 1200));

    if (!_isGameActive || _isPaused) return;
    if (_questionCount >= _maxQuestions) {
      _stopGame();
    } else {
      _generateNewNumberOnly();
    }
  }

  Future<void> saveGameStateToFirestore({bool isGameOver = false}) async {
    User? currentUser = _auth.currentUser;
    if (currentUser == null) return;

    try {
      if (isGameOver && _score > 0) {
        await _db.collection('users').doc(currentUser.uid).update({
          'lastUpdate': FieldValue.serverTimestamp(),
          'scoreHistory.$_categoryKey.currentQuestion': _questionCount,
          'scoreHistory.$_categoryKey.totalScore': _score,
          'scoreHistory.$_categoryKey.history': FieldValue.arrayUnion([_score]),
        });
      } else {
        await _db.collection('users').doc(currentUser.uid).set({
          'lastUpdate': FieldValue.serverTimestamp(),
          'scoreHistory': {
            _categoryKey: {
              'currentQuestion': _questionCount,
              'totalScore': _score,
            }
          }
        }, SetOptions(merge: true));
      }
    } catch (e) {
      debugPrint("Failed to sync session: $e");
    }
  }

  void _stopGame() {
    _isGameActive = false;
    _isListening = false;
    _hasStarted = false;
    _isPaused = false;
    _timer?.cancel();
    _timer = null;
    _stopAudioStream();
    saveGameStateToFirestore(isGameOver: true);
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _timer = null;
    _audioStreamSubscription?.cancel();
    _audioRecorder.dispose();
    _recognizer?.dispose();
    super.dispose();
  }
}