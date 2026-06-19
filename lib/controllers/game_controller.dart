import 'dart:async';
import 'dart:math';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';
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
  int _countdownValue = 0;
  String _lastResult = "";

  int _digits = 1;
  int _hopValue = 1;
  final int _maxQuestions = 30;
  final SpeechToText _speech = SpeechToText();

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

  // Helper string key to uniquely segment scores by game rules category
  String get _categoryKey => "digits_${_digits}_hop_${_hopValue}";

  void togglePause() {
    if (!_isGameActive || _isCountingDown) return;
    _isPaused = !_isPaused;
    if (_isPaused) {
      _timer?.cancel();
      _timer = null; // Ensure pointer instance is entirely cleared
      _speech.stop();
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
    _speech.stop();
    _isListening = false;
    _hasStarted = false;
    _timeLeft = 20;
    _score = 0;
    _questionCount = 0;
    _lastResult = "";
    if (shouldNotify) notifyListeners();
  }

  Future<bool> initializeSpeech() async {
    bool available = await _speech.initialize(
      onStatus: (status) {
        if (status == 'done' || status == 'notListening') {
          _isListening = false;
          if (_isGameActive && !_isPaused) notifyListeners();
        }
      },
      onError: (errorNotification) => debugPrint('Speech error: $errorNotification'),
    );
    return available;
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
              debugPrint("Resuming saved profile game: $_categoryKey at Q: $_questionCount");
            }
          }
        }
      } catch (e) {
        debugPrint("Error looking up session restoration data: $e");
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
      await Future.delayed(const Duration(milliseconds: 600));
      if (_isGameActive && !_isPaused) startListening();
    }
  }

  void startListening() async {
    if (!_isGameActive || _isListening || _isPaused || _isCountingDown) return;

    // Explicitly re-verify availability
    bool available = await _speech.initialize(
      onStatus: (status) => debugPrint('Speech status loop: $status'),
      onError: (err) => debugPrint('Speech explicit error: $err'),
    );

    if (available && _isGameActive && !_isPaused) {
      _isListening = true;
      _startTimer();
      notifyListeners();

      try {
        await _speech.listen(
          onResult: (result) => onSpeechResult(result.recognizedWords, result.finalResult),
          listenFor: const Duration(seconds: 20),
          localeId: "en_US",
          // Force false on Android to prevent local plugin crashes
          onDevice: Platform.isIOS ? !Platform.environment.containsKey('SIMULATOR_HOST_NAME') : false,
          cancelOnError: false,
        );
      } catch (e) {
        debugPrint("Speech execution fallback triggered: $e");
        _isListening = false;
        notifyListeners();
      }
    }
  }

  void onSpeechResult(String spokenText, bool isFinal) {
    if (!_isGameActive || !_isListening || _isPaused) return;

    String cleanSpoken = spokenText.toLowerCase().replaceAll(',', '').replaceAll(' ', '').trim();
    String targetDigit = _currentNumber.toString();

    final numberWords = {
      'one': '1', 'two': '2', 'three': '3', 'four': '4', 'five': '5',
      'six': '6', 'seven': '7', 'eight': '8', 'nine': '9', 'zero': '0'
    };

    bool isCorrect = false;
    if (cleanSpoken.contains(targetDigit)) {
      isCorrect = true;
    } else {
      numberWords.forEach((word, digit) {
        if (digit == targetDigit && cleanSpoken.contains(word)) isCorrect = true;
      });
    }

    if (isCorrect) {
      _speech.stop();
      _stopListeningAndAdvance(bonus: _timeLeft, feedback: "CORRECT!");
      return;
    }

    final hasAnyNumber = RegExp(r'\d+').hasMatch(cleanSpoken);
    bool hasAnyNumberWord = numberWords.keys.any((word) => cleanSpoken.contains(word));

    if (hasAnyNumber || hasAnyNumberWord) {
      _speech.stop();
      _stopListeningAndAdvance(bonus: -_timeLeft, feedback: "WRONG!");
    }
  }

  void _startTimer() {
    _timer?.cancel();
    // 👈 FIXED: Instantly exit and block loop creations if a race condition paused the game state
    if (!_isGameActive || _isPaused) return;

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_isGameActive || _isPaused) {
        timer.cancel();
        _timer = null;
        return;
      }
      if (_timeLeft > 0) {
        _timeLeft--;
        notifyListeners();
      } else {
        _handleTimeout();
      }
    });
  }

  void _handleTimeout() {
    if (!_isGameActive || _isPaused) return;
    _timer?.cancel();
    _timer = null;
    _isListening = false;
    _speech.stop();
    _stopListeningAndAdvance(bonus: -20, feedback: "TIMEOUT!");
  }

  void _stopListeningAndAdvance({required int bonus, required String feedback}) async {
    if (!_isGameActive) return;
    _timer?.cancel();
    _timer = null;
    _isListening = false;
    _lastResult = feedback;
    _score += bonus;
    _questionCount++;
    notifyListeners();

    await saveGameStateToFirestore();

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
      debugPrint("Game session successfully updated in cloud.");
    } catch (e) {
      debugPrint("Failed to sync game session data to cloud: $e");
    }
  }

  void _stopGame() {
    _isGameActive = false;
    _isListening = false;
    _hasStarted = false;
    _isPaused = false;
    _timer?.cancel();
    _timer = null;
    _speech.stop();
    saveGameStateToFirestore(isGameOver: true);
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _timer = null;
    super.dispose();
  }
}