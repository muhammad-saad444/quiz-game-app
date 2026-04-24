import 'dart:async';
import 'dart:math';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';

class GameController extends ChangeNotifier {
  int _currentNumber = 0;
  int _score = 0;
  int _timeLeft = 20;
  int _questionCount = 0;
  Timer? _timer;
  bool _isGameActive = false;
  bool _isListening = false;
  bool _hasStarted = false; // Prevents listening before the first play button tap

  // Game Settings
  int _digits = 1;
  int _hopValue = 1;
  final int _maxQuestions = 30;
  final SpeechToText _speech = SpeechToText();

  int get currentNumber => _currentNumber;
  int get score => _score;
  int get timeLeft => _timeLeft;
  int get questionCount => _questionCount;
  bool get isGameActive => _isGameActive;
  bool get isListening => _isListening;

  Future<bool> initializeSpeech() async {
    bool available = await _speech.initialize(
      onStatus: (status) {
        debugPrint('Speech status: $status');
        if (status == 'done' || status == 'notListening') {
          _isListening = false;
          notifyListeners();
        }
      },
      onError: (errorNotification) => debugPrint('Speech error: $errorNotification'),
    );
    return available;
  }

  void startNewGame(int digits, int hopValue) {
    _digits = digits;
    _hopValue = hopValue;
    _score = 0;
    _questionCount = 0;
    _isGameActive = true;
    _isListening = false;
    _hasStarted = false; // Standby mode until Play is pressed
    _generateNewNumberOnly();
  }

  /// Triggered ONLY by the UI Play Button
  void pressPlayButton() {
    if (!_isGameActive) return;
    _hasStarted = true;
    startListening();
  }

  void _generateNewNumberOnly() async {
    if (_questionCount >= _maxQuestions) {
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
    notifyListeners();

    // Auto-Restart mic if the game is already in progress
    if (_isGameActive && _hasStarted) {
      // CRITICAL: Delay prevents iOS EXC_BAD_ACCESS by giving the
      // Audio Engine time to cycle off/on.
      await Future.delayed(const Duration(milliseconds: 600));
      startListening();
    }
  }

  void startListening() async {
    if (!_isGameActive || _isListening) return;

    // Ensure engine is ready
    bool available = await _speech.initialize();

    if (available) {
      _isListening = true;
      _startTimer();
      notifyListeners();

      await _speech.listen(
        onResult: (result) => onSpeechResult(result.recognizedWords, result.finalResult),
        listenFor: const Duration(seconds: 20),
        pauseFor: const Duration(seconds: 3),
        localeId: "en_US",
        // Use true for real iPhone, false for Simulator
        onDevice: Platform.isIOS && !Platform.environment.containsKey('SIMULATOR_HOST_NAME'),
        cancelOnError: false,
        listenMode: ListenMode.dictation,
      );
    }
  }

  void onSpeechResult(String spokenText, bool isFinal) {
    if (!_isGameActive || !_isListening) return;

    debugPrint("Transcription: $spokenText (Final: $isFinal)");

    // Clean formatting for matching
    String cleanSpoken = spokenText.toLowerCase().replaceAll(',', '').replaceAll(' ', '').trim();
    String targetDigit = _currentNumber.toString();

    final numberWords = {
      'one': '1', 'two': '2', 'three': '3', 'four': '4', 'five': '5',
      'six': '6', 'seven': '7', 'eight': '8', 'nine': '9', 'zero': '0',
    };

    bool isCorrect = false;

    // 1. Check for Correct Answer (Instant)
    if (cleanSpoken.contains(targetDigit)) {
      isCorrect = true;
    } else {
      numberWords.forEach((word, digit) {
        if (digit == targetDigit && cleanSpoken.contains(word)) {
          isCorrect = true;
        }
      });
    }

    if (isCorrect) {
      debugPrint("🎯 Match Found: $targetDigit");
      _speech.stop(); // Stop engine to clear buffer
      _stopListeningAndAdvance(bonus: _timeLeft);
      return;
    }

    // 2. Check for Wrong Answer (Only when user stops talking)
    if (isFinal) {
      final hasAnyNumber = RegExp(r'\d+').hasMatch(cleanSpoken);
      bool hasAnyNumberWord = numberWords.keys.any((word) => cleanSpoken.contains(word));

      if (hasAnyNumber || hasAnyNumberWord) {
        debugPrint("❌ Wrong Answer: $spokenText");
        _speech.stop();
        _stopListeningAndAdvance(bonus: -_timeLeft);
      }
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_timeLeft > 0) {
        _timeLeft--;
        notifyListeners();
      } else {
        _handleTimeout();
      }
    });
  }

  void _handleTimeout() {
    _timer?.cancel();
    _score -= 20;
    _questionCount++;
    _generateNewNumberOnly();
  }

  void _stopListeningAndAdvance({required int bonus}) {
    _timer?.cancel();
    _isListening = false;

    _score += bonus;
    _questionCount++;

    debugPrint("Bonus: $bonus | Total: $_score");

    if (_questionCount >= _maxQuestions) {
      _stopGame();
    } else {
      _generateNewNumberOnly();
    }
    notifyListeners();
  }

  void _stopGame() {
    _isGameActive = false;
    _isListening = false;
    _hasStarted = false;
    _timer?.cancel();
    _speech.stop();
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _speech.stop();
    super.dispose();
  }
}