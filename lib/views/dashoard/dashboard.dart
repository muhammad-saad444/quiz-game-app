import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:animate_do/animate_do.dart';
import 'package:realtime_answer_detector/views/game_screen/game_screen.dart';
import '../../constants/app_colors.dart';
import '../../controllers/auth_controller.dart';
import '../game_screen/game_setup_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authController = Provider.of<AuthController>(context);
    final String userEmail = authController.userModel?.email ?? "Explorer";
    final String displayName = userEmail.split('@')[0].toUpperCase();

    return Scaffold(
      backgroundColor: Colors.black,
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
          child: RefreshIndicator(
            onRefresh: () => authController.fetchUserData(authController.userModel!.uid),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 25),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),
                  _buildHeader(displayName, authController),
                  const SizedBox(height: 30),
                  _buildProgressGraph(),
                  const SizedBox(height: 30),
                  _buildStatsGrid(),
                  const SizedBox(height: 30),
                  _buildRecentActivity(),
                  const SizedBox(height: 100), // Space for FAB
                ],
              ),
            ),
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: FadeInUp(
        child: FloatingActionButton.extended(
          backgroundColor: AppColors.primary,
          onPressed: () {
            Navigator.push(context,MaterialPageRoute(builder: (context)=>GameSetupScreen()));
          },
          label: const Text("START HUNT", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 2)),
          icon: const Icon(Icons.play_arrow_rounded),
        ),
      ),
    );
  }

  Widget _buildHeader(String name, AuthController auth) {
    return FadeIn(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // FIX: Wrap the text column in Expanded to prevent right-side overflow
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "DASHBOARD",
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 3,
                    fontSize: 12,
                  ),
                ),
                Text(
                  "HI, $name!",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    overflow: TextOverflow.ellipsis, // Adds '...' if name is too long
                  ),
                  maxLines: 1,
                ),
              ],
            ),
          ),
          const SizedBox(width: 15), // Small gap before the avatar
          CircleAvatar(
            backgroundColor: AppColors.fieldBg,
            radius: 25,
            child: IconButton(
              icon: const Icon(Icons.logout_rounded, color: Colors.white70, size: 20),
              onPressed: () => auth.logout(),
              tooltip: "Logout",
            ),
          )
        ],
      ),
    );
  }

  Widget _buildProgressGraph() {
    return FadeInLeft(
      child: Container(
        height: 220,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(25),
          border: Border.all(color: Colors.white10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("SCORE PROGRESS", style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            Expanded(
              child: LineChart(
                LineChartData(
                  gridData: const FlGridData(show: false),
                  titlesData: const FlTitlesData(show: false),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: [
                        const FlSpot(0, 3),
                        const FlSpot(1, 1),
                        const FlSpot(2, 4),
                        const FlSpot(3, 2),
                        const FlSpot(4, 5),
                      ],
                      isCurved: true,
                      color: AppColors.primary,
                      barWidth: 4,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        color: AppColors.primary.withOpacity(0.1),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsGrid() {
    return Row(
      children: [
        Expanded(child: _statCard("TOTAL STARS", "1,250", Icons.star_rounded, AppColors.accent)),
        const SizedBox(width: 15),
        Expanded(child: _statCard("BEST TIME", "2.5s", Icons.timer_rounded, AppColors.playGreen)),
      ],
    );
  }

  Widget _statCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(height: 10),
          Text(title, style: const TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold)),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }

  Widget _buildRecentActivity() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("RECENT HUNTS", style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
        const SizedBox(height: 15),
        _activityTile("Level 5 Complete", "+20 Stars", "2 mins ago"),
        _activityTile("New Record!", "High Score", "Yesterday"),
      ],
    );
  }

  Widget _activityTile(String title, String subtitle, String time) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded( // Added expanded here as well to protect long activity titles
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                Text(subtitle, style: const TextStyle(color: Colors.white38, fontSize: 12)),
              ],
            ),
          ),
          Text(time, style: const TextStyle(color: Colors.white24, fontSize: 10)),
        ],
      ),
    );
  }
}