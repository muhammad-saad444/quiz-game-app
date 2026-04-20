import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';

class GameController extends ChangeNotifier {
  int _currentNumber = 0;
  int _score = 0;
  int _timeLeft = 20;
  int _questionCount = 0;
  Timer? _timer;
  bool _isGameActive = false;
  bool _isListening = false; // Controls the "Start" state

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
      onStatus: (status) => debugPrint('Speech status: $status'),
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
    _isListening = false; // Wait for user to press Mic
    _generateNewNumberOnly();
  }

  // Generate number but DON'T start timer yet
  void _generateNewNumberOnly() {
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
    _isListening = false;
    notifyListeners();
  }

  // Triggered when Mic button is pressed
  void startListening() async {
    if (!_isGameActive || _isListening) return;

    bool available = await _speech.initialize(
      onStatus: (status) {
        debugPrint('Speech status: $status');
        // If it stops unexpectedly, reset our UI state
        if (status == 'done' || status == 'notListening') {
          _isListening = false;
          notifyListeners();
        }
      },
      onError: (error) => debugPrint('Speech error: $error'),
    );

    if (available) {
      _isListening = true;
      _startTimer();
      notifyListeners();

      await _speech.listen(
        onResult: (result) {
          // Use result.recognizedWords which updates as you talk
          debugPrint("Recognized: ${result.recognizedWords}");
          onSpeechResult(result.recognizedWords, result.finalResult);
        },
        listenFor: const Duration(seconds: 20),
        pauseFor: const Duration(seconds: 5), // Wait 5s of silence before stopping
        localeId: "en_US",
        cancelOnError: false, // Don't stop the game on a single mic error
        listenMode: ListenMode.dictation, // Use dictation for continuous stream
      );
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
    _score -= 20; // Deduct 20 points
    _questionCount++;
    _generateNewNumberOnly();
  }
  void _stopListeningAndAdvance({required int bonus}) {
    _timer?.cancel();
    _isListening = false;

    _score += bonus; // This will subtract if bonus is negative
    _questionCount++;

    debugPrint("Bonus Applied: $bonus | New Score: $_score");

    if (_questionCount >= 30) {
      _isGameActive = false;
    } else {
      _generateNewNumberOnly();
    }
    notifyListeners();
  }

  // Update the parameter to include the 'isFinal' flag
  void onSpeechResult(String spokenText, bool isFinal) {
    if (!_isGameActive || !_isListening) return;

    debugPrint("Transcription: $spokenText (Final: $isFinal)");

    String targetDigit = _currentNumber.toString();
    String cleanSpoken = spokenText.toLowerCase().trim();

    final numberWords = {
      'one': '1', 'two': '2', 'three': '3', 'four': '4', 'five': '5',
      'six': '6', 'seven': '7', 'eight': '8', 'nine': '9', 'zero': '0',
    };

    bool isCorrect = false;

    // --- 1. ALWAYS check for Correct Answer (Instant Win) ---
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
      _speech.stop();
      _stopListeningAndAdvance(bonus: _timeLeft);
      return;
    }

    // --- 2. Check for Wrong Answer ONLY when user stops speaking (isFinal) ---
    if (isFinal) {
      final hasAnyNumber = RegExp(r'\d+').hasMatch(cleanSpoken);
      bool hasAnyNumberWord = numberWords.keys.any((word) => cleanSpoken.contains(word));

      if (hasAnyNumber || hasAnyNumberWord) {
        debugPrint("❌ Final Wrong Number Detected: $spokenText");
        _speech.stop();
        _stopListeningAndAdvance(bonus: -_timeLeft);
      }
    }
  }

  void _stopGame() {
    _isGameActive = false;
    _isListening = false;
    _timer?.cancel();
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}