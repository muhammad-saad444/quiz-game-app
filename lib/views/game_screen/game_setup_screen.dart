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
    // 📐 Dynamically compute viewport size metrics
    final mediaQuery = MediaQuery.of(context);
    final screenHeight = mediaQuery.size.height;
    final screenWidth = mediaQuery.size.width;

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
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.bottomCenter,
              colors: [AppColors.bgTop, AppColors.bgBottom],
            ),
          ),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.bgTop, AppColors.bgBottom],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                child: ConstrainedBox(
                  // 🦾 Force viewport constraints so it fills the screen cleanly but scrolls if overcrowded
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight,
                  ),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: screenWidth * 0.08, // Dynamic 8% horizontal margins
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        SizedBox(height: screenHeight * 0.03),
                        Text(
                          "GAME SETUP",
                          style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 4,
                            fontSize: screenWidth * 0.045, // Scales typography smoothly
                          ),
                        ),

                        // 📏 Proportional spacing heights instead of hardcoded steps
                        SizedBox(height: screenHeight * 0.05),

                        _sectionTitle("HOW MANY DIGITS?", screenWidth),
                        Wrap(
                          spacing: screenWidth * 0.03,
                          runSpacing: screenWidth * 0.03,
                          alignment: WrapAlignment.center,
                          children: [1, 2, 3, 4, 5, 6].map((d) =>
                              _choiceChip(
                                d.toString(),
                                selectedDigits == d,
                                    () => setState(() => selectedDigits = d),
                                screenWidth,
                              ),
                          ).toList(),
                        ),

                        SizedBox(height: screenHeight * 0.04),

                        _sectionTitle("NUMBER HOPS (MULTIPLES)", screenWidth),
                        Wrap(
                          spacing: screenWidth * 0.025,
                          runSpacing: screenWidth * 0.025,
                          alignment: WrapAlignment.center,
                          children: [1, 2, 5, 10, 50, 100].map((h) =>
                              _choiceChip(
                                "x$h",
                                selectedHop == h,
                                    () => setState(() => selectedHop = h),
                                screenWidth,
                              ),
                          ).toList(),
                        ),

                        SizedBox(height: screenHeight * 0.06),

                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            // Dynamic action block heights scaled proportionally
                            minimumSize: Size(double.infinity, screenHeight * 0.075),
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
                          child: Text(
                            "START SAFARI",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: screenWidth * 0.045,
                              letterSpacing: 2,
                            ),
                          ),
                        ),
                        SizedBox(height: screenHeight * 0.03),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String text, double screenWidth) => Padding(
    padding: const EdgeInsets.only(bottom: 20),
    child: Text(
      text,
      textAlign: TextAlign.center,
      style: TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w900,
        fontSize: screenWidth * 0.035, // Perfectly scaled text sizing
        letterSpacing: 1,
      ),
    ),
  );

  Widget _choiceChip(String label, bool isSelected, VoidCallback onTap, double screenWidth) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        // Proportional padding ensures chips preserve geometry perfectly across device layouts
        padding: EdgeInsets.symmetric(
          horizontal: screenWidth * 0.06,
          vertical: screenWidth * 0.035,
        ),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: isSelected ? Colors.white24 : Colors.white10),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white54,
            fontWeight: FontWeight.bold,
            fontSize: screenWidth * 0.038,
          ),
        ),
      ),
    );
  }
}