import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:animate_do/animate_do.dart';
import '../../constants/app_colors.dart';
import '../../controllers/auth_controller.dart';
import '../game_screen/game_setup_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  // Local states to handle dropdown filters
  int selectedDigits = 1;
  int selectedHop = 1;

  // Available options matching your setup configuration rules
  final List<int> digitOptions = [1, 2, 3, 4, 5, 6];
  final List<int> hopOptions = [1, 2, 5, 10, 50, 100];

  @override
  Widget build(BuildContext context) {
    final authController = Provider.of<AuthController>(context);
    final userModel = authController.userModel;

    // 🌟 FIXED: Display the user's name directly from the model, fallback to Explorer
    final String displayName = (userModel?.name ?? "Explorer").toUpperCase();

    // 1. Target the dynamic map key matching current selection
    String categoryKey = "digits_${selectedDigits}_hop_${selectedHop}";

    // 2. Extract the targeted stats map for this specific category option
    Map<String, dynamic>? categoryData;
    if (userModel?.scoreHistory != null && userModel!.scoreHistory.containsKey(categoryKey)) {
      categoryData = Map<String, dynamic>.from(userModel.scoreHistory[categoryKey]);
    }

    // 3. Dynamic score and question values extracted directly from current state profile
    int totalScore = (categoryData?['totalScore'] ?? 0).toInt();
    int currentQuestion = (categoryData?['currentQuestion'] ?? 1).toInt();

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
                  const SizedBox(height: 25),

                  // DROPDOWN FILTER BAR
                  _buildFilterSelectors(),
                  const SizedBox(height: 20),

                  // Passing reactive calculations to build visual graphs
                  _buildProgressGraph(categoryData),
                  const SizedBox(height: 30),

                  _buildStatsGrid(totalScore, currentQuestion),
                  const SizedBox(height: 30),

                  _buildRecentActivity(currentQuestion),
                  const SizedBox(height: 100),
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
            Navigator.push(context, MaterialPageRoute(builder: (context) => const GameSetupScreen()));
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
                    overflow: TextOverflow.ellipsis,
                  ),
                  maxLines: 1,
                ),
              ],
            ),
          ),
          const SizedBox(width: 15),
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

  /// Builds the side-by-side drop down choice pickers
  Widget _buildFilterSelectors() {
    return Row(
      children: [
        // Digits Selector
        Expanded(
          child: _dropdownCard(
            label: "DIGITS",
            value: selectedDigits,
            items: digitOptions,
            onChanged: (val) {
              if (val != null) setState(() => selectedDigits = val);
            },
          ),
        ),
        const SizedBox(width: 15),
        // Hops Selector
        Expanded(
          child: _dropdownCard(
            label: "HOPS",
            value: selectedHop,
            items: hopOptions,
            prefix: "x",
            onChanged: (val) {
              if (val != null) setState(() => selectedHop = val);
            },
          ),
        ),
      ],
    );
  }

  Widget _dropdownCard({
    required String label,
    required int value,
    required List<int> items,
    required ValueChanged<int?> onChanged,
    String prefix = "",
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: AppColors.primary, fontSize: 9, fontWeight: FontWeight.bold)),
          DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: value,
              dropdownColor: Colors.grey[900],
              isExpanded: true,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
              icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white54),
              onChanged: onChanged,
              items: items.map((int val) {
                return DropdownMenuItem<int>(
                  value: val,
                  child: Text("$prefix$val"),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressGraph(Map<String, dynamic>? categoryData) {
    List<dynamic> rawHistory = categoryData?['history'] ?? [];
    int totalScore = (categoryData?['totalScore'] ?? 0).toInt();

    List<FlSpot> spots = [];

    // Build out data spots chronologically
    if (rawHistory.isEmpty) {
      spots = [
        const FlSpot(0, 0), // Base starting point
        FlSpot(1, totalScore.toDouble()), // Active progress score
      ];
    } else {
      for (int i = 0; i < rawHistory.length; i++) {
        spots.add(FlSpot(i.toDouble(), (rawHistory[i] as num).toDouble()));
      }
      if (totalScore > 0 && totalScore != rawHistory.last) {
        spots.add(FlSpot(rawHistory.length.toDouble(), totalScore.toDouble()));
      }
    }

    double highestScore = 50;
    for (var spot in spots) {
      if (spot.y > highestScore) highestScore = spot.y;
    }

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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("SCORE PROGRESS", style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
                Text(
                  "Current: $totalScore pts",
                  style: const TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.bold),
                )
              ],
            ),
            const SizedBox(height: 20),
            Expanded(
              child: LineChart(
                LineChartData(
                  // TOUCH INTERACTION & POPUP TOOLTIPS
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipColor: (touchedSpot) => Colors.grey[900]!,
                      getTooltipItems: (List<LineBarSpot> touchedSpots) {
                        return touchedSpots.map((barSpot) {
                          return LineTooltipItem(
                            "${barSpot.y.toInt()} Pts",
                            const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                          );
                        }).toList();
                      },
                    ),
                    handleBuiltInTouches: true,
                  ),
                  gridData: const FlGridData(show: false),
                  titlesData: FlTitlesData(
                    show: true,
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 22,
                        interval: 1,
                        getTitlesWidget: (value, meta) {
                          int index = value.toInt();
                          if (index < 0 || index >= spots.length) return const SizedBox.shrink();
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              index == 0 && rawHistory.isEmpty ? "START" : "H$index",
                              style: const TextStyle(color: Colors.white30, fontSize: 9, fontWeight: FontWeight.bold),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  minX: 0,
                  maxX: spots.length.toDouble() - 1 < 3 ? 3 : spots.length.toDouble() - 1,
                  minY: 0,
                  maxY: highestScore * 1.35, // Extra top padding so points aren't cut off
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: spots.length > 2, // Smooth layout wave if enough historic milestones exist
                      curveSmoothness: 0.35,
                      color: AppColors.primary,
                      barWidth: 4,
                      // VISIBLE VALUE LABELS DIRECTLY ABOVE DOTS
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, percent, barData, index) {
                          return FlDotCirclePainter(
                            radius: 5,
                            color: AppColors.primary,
                            strokeWidth: 2,
                            strokeColor: Colors.white,
                          );
                        },
                      ),
                      showingIndicators: List.generate(spots.length, (index) => index),
                      belowBarData: BarAreaData(
                        show: true,
                        color: AppColors.primary.withOpacity(0.08),
                      ),
                    ),
                  ],
                  showingTooltipIndicators: List.generate(spots.length, (index) {
                    return ShowingTooltipIndicators([
                      LineBarSpot(
                        LineChartBarData(spots: spots),
                        0,
                        spots[index],
                      ),
                    ]);
                  }),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsGrid(int totalScore, int currentQuestion) {
    String dynamicStars = totalScore.toString();
    String dynamicQuest = "$currentQuestion/30";

    return Row(
      children: [
        Expanded(child: _statCard("TOTAL STARS", dynamicStars, Icons.star_rounded, AppColors.accent)),
        const SizedBox(width: 15),
        Expanded(child: _statCard("QUEST PROGRESS", dynamicQuest, Icons.flag_rounded, AppColors.playGreen)),
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

  Widget _buildRecentActivity(int currentQuestion) {
    String labelText = currentQuestion > 1
        ? "Hunting in progress"
        : "No attempts yet";

    String subText = currentQuestion >= 30
        ? "All 30 Hunts Completed!"
        : "Saved at Question #$currentQuestion";

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("CATEGORY ACTIVITY", style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
        const SizedBox(height: 15),
        _activityTile(labelText, subText, "Active Configuration"),
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
          Expanded(
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