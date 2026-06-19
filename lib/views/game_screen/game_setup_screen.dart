import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import 'game_screen.dart';

class GameSetupScreen extends StatefulWidget {
  const GameSetupScreen({super.key});

  @override
  State<GameSetupScreen> createState() => _GameSetupScreenState();
}

class _GameSetupScreenState extends State<GameSetupScreen> {
  int selectedDigits = 1;
  int selectedHop = 1;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "GAME SETUP",
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        // This is where the magic happens
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.bottomCenter,
              colors: [AppColors.bgTop, AppColors.bgBottom],
            ),
          ),
        ),
        elevation: 0, // Removes the shadow for a flat, seamless transition
        backgroundColor: Colors.transparent, // Ensures the container shows through
      ),
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.bgTop, AppColors.bgBottom],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 30),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text("GAME SETUP", style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, letterSpacing: 4)),
                const SizedBox(height: 50),

                _sectionTitle("HOW MANY DIGITS?"),
                Wrap(
                  spacing: 12,      // Horizontal space between chips
                  runSpacing: 12,   // Vertical space if they wrap to a second line
                  alignment: WrapAlignment.center,
                  children: [1, 2, 3, 4, 5, 6].map((d) =>
                      _choiceChip(
                        d.toString(),
                        selectedDigits == d,
                            () => setState(() => selectedDigits = d),
                      ),
                  ).toList(),
                ),

                const SizedBox(height: 40),

                _sectionTitle("NUMBER HOPS (MULTIPLES)"),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  alignment: WrapAlignment.center,
                  children: [1, 2, 5, 10 ,50 ,100].map((h) => _choiceChip("x$h", selectedHop == h, () => setState(() => selectedHop = h))).toList(),
                ),

                const SizedBox(height: 60),

                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    minimumSize: const Size(double.infinity, 65),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => SafariGameScreen(digits: selectedDigits, hop: selectedHop),
                      ),
                    );
                  },
                  child: const Text("START SAFARI", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18, letterSpacing: 2)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 20),
    child: Text(text, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 1)),
  );

  Widget _choiceChip(String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 15),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: isSelected ? Colors.white24 : Colors.white10),
        ),
        child: Text(label, style: TextStyle(color: isSelected ? Colors.white : Colors.white54, fontWeight: FontWeight.bold)),
      ),
    );
  }
}