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

class _SafariGameScreenState extends State<SafariGameScreen> {
  @override
  void initState() {
    super.initState();
    _initGameLogic();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<GameController>(context, listen: false).startNewGame(widget.digits, widget.hop);
    });
  }
  Future<void> _initGameLogic() async {
    // 1. Request raw permissions
    await Permission.microphone.request();
    await Permission.speech.request();

    // 2. Initialize the speech engine hardware
    final controller = Provider.of<GameController>(context, listen: false);
    await controller.initializeSpeech();

    // 3. Start the game question
    controller.startNewGame(widget.digits, widget.hop);
  }

  @override
  Widget build(BuildContext context) {
    final gameProvider = Provider.of<GameController>(context);

    return Scaffold(
      body: Container(
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
              // Score & Timer & Progress
              Padding(
                padding: const EdgeInsets.all(25.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _infoBadge("STARS", "${gameProvider.score}", AppColors.accent),
                    _infoBadge("QUEST", "${gameProvider.questionCount}/30", Colors.white70),
                    _infoBadge("TIME", "${gameProvider.timeLeft}s",
                        gameProvider.timeLeft <= 5 ? AppColors.error : AppColors.primary),
                  ],
                ),
              ),

              const Spacer(),

              FadeInDown(
                key: ValueKey(gameProvider.currentNumber),
                child: Column(
                  children: [
                    Text(gameProvider.isListening ? "SPEAK NOW!" : "READY?",
                        style: const TextStyle(color: Colors.white54, letterSpacing: 4, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    Text(
                      "${gameProvider.currentNumber}",
                      style: TextStyle(
                        // Dynamic font size for large numbers
                        fontSize: widget.digits > 4 ? 70 : 100,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        shadows: const [Shadow(color: AppColors.primary, blurRadius: 40)],
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(),

              if (gameProvider.isGameActive)
                Column(
                  children: [
                    GestureDetector(
                      onTap: () => gameProvider.startListening(),
                      child: Pulse(
                        infinite: gameProvider.isListening,
                        animate: gameProvider.isListening,
                        child: Container(
                          padding: const EdgeInsets.all(30),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: gameProvider.isListening
                                ? AppColors.primary.withOpacity(0.2)
                                : Colors.white.withOpacity(0.05),
                            border: Border.all(
                                color: gameProvider.isListening ? AppColors.primary : Colors.white24,
                                width: 3),
                          ),
                          child: Icon(
                              gameProvider.isListening ? Icons.mic_rounded : Icons.play_arrow_rounded,
                              color: Colors.white, size: 50),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                        gameProvider.isListening ? "LISTENING..." : "TAP TO START TIMER",
                        style: TextStyle(
                            color: gameProvider.isListening ? AppColors.primary : Colors.white54,
                            fontWeight: FontWeight.bold)
                    ),
                  ],
                )
              else
                _buildGameOverUI(context, gameProvider),

              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGameOverUI(BuildContext context, GameController controller) {
    return FadeInUp(
      child: Column(
        children: [
          const Text("HUNT COMPLETE!", style: TextStyle(color: AppColors.accent, fontSize: 32, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Text("FINAL SCORE: ${controller.score}", style: const TextStyle(color: Colors.white, fontSize: 20)),
          const SizedBox(height: 30),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                minimumSize: const Size(200, 60),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))
            ),
            onPressed: () => Navigator.pop(context),
            child: const Text("BACK TO DASHBOARD", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }

  Widget _infoBadge(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: color.withOpacity(0.5), width: 1.5),
      ),
      child: Column(
        children: [
          Text(label, style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.bold)),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}