import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:animate_do/animate_do.dart';
import '../../constants/app_colors.dart';
import '../../controllers/game_controller.dart';

class SafariGameScreen extends StatefulWidget {
  final int digits;
  final int hop;
  const SafariGameScreen({super.key, required this.digits, required this.hop});

  @override
  State<SafariGameScreen> createState() => _SafariGameScreenState();
}

class _SafariGameScreenState extends State<SafariGameScreen> with WidgetsBindingObserver {
  late GameController _gameController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _gameController = Provider.of<GameController>(context, listen: false);
    _initGameLogic();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _gameController.resetAndStop(shouldNotify: false);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      if (_gameController.isGameActive && !_gameController.isPaused) {
        _gameController.togglePause();
      }
    }
  }

  Future<void> _initGameLogic() async {
    await Permission.microphone.request();
    await Permission.speech.request();
    await _gameController.initializeSpeech();
    _gameController.startNewGame(widget.digits, widget.hop);
  }

  @override
  Widget build(BuildContext context) {
    final gameProvider = Provider.of<GameController>(context);

    return PopScope(
      // Block back button unless game is over or paused
      canPop: !gameProvider.isGameActive || gameProvider.isPaused,
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("PAUSE the game to go back!", textAlign: TextAlign.center),
              backgroundColor: AppColors.error,
              duration: Duration(seconds: 1),
            ),
          );
        } else {
          // 1. Explicitly invoke save state logic upon navigating back
          await _gameController.saveGameStateToFirestore();
          // 2. Clear out parameters cleanly without triggering global state leaks
          _gameController.resetAndStop(shouldNotify: false);
        }
      },
      child: Scaffold(
        body: Stack(
          children: [
            Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter, end: Alignment.bottomCenter,
                  colors: [AppColors.bgTop, AppColors.bgBottom],
                ),
              ),
              child: SafeArea(
                child: Column(
                  children: [
                    // Header Badges
                    Padding(
                      padding: const EdgeInsets.all(25.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _infoBadge("STARS", "${gameProvider.score}", AppColors.accent),
                          _tickingClock(gameProvider.timeLeft, gameProvider.timeLeft <= 5 ? AppColors.error : AppColors.primary),
                          _infoBadge("QUEST", "${gameProvider.questionCount}/30", Colors.white70),
                        ],
                      ),
                    ),
                    const Spacer(),

                    // Center Game Content
                    _buildGameCore(gameProvider),

                    const Spacer(),

                    // Action Buttons
                    _buildActionButtons(gameProvider),

                    const Spacer(),
                  ],
                ),
              ),
            ),

            // COUNTDOWN OVERLAY
            if (gameProvider.isCountingDown)
              Container(
                color: Colors.black87,
                width: double.infinity,
                height: double.infinity,
                child: Center(
                  child: ZoomIn(
                    key: ValueKey(gameProvider.countdownValue),
                    child: Text(
                      gameProvider.countdownValue == 0 ? "GO!" : "${gameProvider.countdownValue}",
                      style: TextStyle(
                          fontSize: 180,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          shadows: const [Shadow(color: AppColors.primary, blurRadius: 40)]
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildGameCore(GameController gameProvider) {
    return Column(
      children: [
        SizedBox(
          height: 50,
          child: gameProvider.lastResult.isNotEmpty
              ? ElasticIn(
            key: ValueKey(gameProvider.lastResult),
            child: Text(gameProvider.lastResult, style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: gameProvider.lastResult == "CORRECT!" ? Colors.greenAccent : AppColors.error)),
          )
              : const SizedBox.shrink(),
        ),
        FadeInDown(
          key: ValueKey(gameProvider.currentNumber),
          child: Column(
            children: [
              Text(gameProvider.isListening ? "SPEAK NOW!" : (gameProvider.isPaused ? "READY?" : "WATCHING..."), style: const TextStyle(color: Colors.white54, letterSpacing: 4, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Text(
                "${gameProvider.currentNumber}",
                style: TextStyle(
                    fontSize: 100,
                    fontWeight: FontWeight.w900,
                    color: gameProvider.isPaused ? Colors.white24 : Colors.white,
                    shadows: gameProvider.isPaused ? [] : [const Shadow(color: AppColors.primary, blurRadius: 40)]
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons(GameController gameProvider) {
    if (!gameProvider.isGameActive) return _buildGameOverUI(context, gameProvider);

    return Column(
      children: [
        if (gameProvider.isPaused)
          FadeIn(child: const Text("GAME PAUSED", style: TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold, letterSpacing: 2))),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Pause/Resume Button
            _actionBtn(
                onTap: () => gameProvider.togglePause(),
                icon: gameProvider.isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                color: Colors.orangeAccent,
                label: gameProvider.isPaused ? "RESUME" : "PAUSE"
            ),
            const SizedBox(width: 40),
            // Play/Mic Button
            _actionBtn(
                onTap: gameProvider.isPaused || gameProvider.isCountingDown ? null : () => gameProvider.pressPlayButton(),
                icon: gameProvider.isListening ? Icons.mic_rounded : Icons.mic_none_rounded,
                color: gameProvider.isListening ? AppColors.primary : Colors.white24,
                label: gameProvider.isListening ? "LISTENING" : "START MIC",
                isPulse: gameProvider.isListening,
                isDisabled: gameProvider.isPaused || gameProvider.isCountingDown
            ),
          ],
        ),
      ],
    );
  }

  Widget _actionBtn({required VoidCallback? onTap, required IconData icon, required Color color, required String label, bool isPulse = false, bool isDisabled = false}) {
    return Opacity(
      opacity: isDisabled ? 0.3 : 1.0,
      child: Column(
        children: [
          GestureDetector(
              onTap: onTap,
              child: Pulse(
                  infinite: isPulse,
                  animate: isPulse,
                  child: Container(
                      padding: const EdgeInsets.all(25),
                      decoration: BoxDecoration(shape: BoxShape.circle, color: color.withOpacity(0.1), border: Border.all(color: color, width: 2)),
                      child: Icon(icon, color: Colors.white, size: 40)
                  )
              )
          ),
          const SizedBox(height: 10),
          Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 10)),
        ],
      ),
    );
  }

  Widget _tickingClock(int timeLeft, Color color) {
    double progress = timeLeft / 20;
    return Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(width: 55, height: 55, child: CircularProgressIndicator(value: progress, strokeWidth: 6, backgroundColor: Colors.white10, valueColor: AlwaysStoppedAnimation<Color>(color))),
          Column(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.access_time_filled, size: 14, color: color.withOpacity(0.8)), Text("${timeLeft}s", style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold))])
        ]
    );
  }

  Widget _buildGameOverUI(BuildContext context, GameController controller) {
    return FadeInUp(child: Column(children: [const Text("HUNT COMPLETE!", style: TextStyle(color: AppColors.accent, fontSize: 32, fontWeight: FontWeight.bold)), const SizedBox(height: 10), Text("FINAL SCORE: ${controller.score}", style: const TextStyle(color: Colors.white, fontSize: 20)), const SizedBox(height: 30), ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, minimumSize: const Size(200, 60), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))), onPressed: () => Navigator.pop(context), child: const Text("BACK TO DASHBOARD", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)))]));
  }

  Widget _infoBadge(String label, String value, Color color) {
    return Container(padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(15), border: Border.all(color: color.withOpacity(0.5), width: 1.5)), child: Column(children: [Text(label, style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.bold)), Text(value, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900))]));
  }
}