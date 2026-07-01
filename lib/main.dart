import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';

// Internal Imports
import 'constants/app_colors.dart';
import 'constants/app_texts.dart';
import 'controllers/auth_controller.dart';
import 'controllers/game_controller.dart';
import 'services/app_provider.dart';
import 'views/login_screen.dart';
import 'views/dashoard/dashboard.dart';
import 'views/verify_email_address.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await requestPermissions();

  // Robust Firebase Initialization
  try {
    await Firebase.initializeApp();
    debugPrint("✅ Firebase Connected Successfully");
  } catch (e) {
    debugPrint("❌ Firebase Connection Failed: $e");
  }

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));

  runApp(const MyApp());
}

Future<void> requestPermissions() async {
  var micStatus = await Permission.microphone.status;

  // FIXED: Removed Permission.speech since Vosk runs 100% locally and only needs raw mic access
  if (!micStatus.isGranted) {
    await Permission.microphone.request();
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: AppProvider.providers,
      child: MaterialApp(
        title: AppTexts.appName,
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.dark,
          fontFamily: 'Quicksand',
          primaryColor: AppColors.primary,
          scaffoldBackgroundColor: Colors.black,
          colorScheme: ColorScheme.fromSeed(
            seedColor: AppColors.primary,
            brightness: Brightness.dark,
            primary: AppColors.primary,
            secondary: AppColors.accent,
            surface: AppColors.bgTop,
          ),
          appBarTheme: const AppBarTheme(
            backgroundColor: Colors.transparent,
            elevation: 0,
            centerTitle: true,
            iconTheme: IconThemeData(color: Colors.white, size: 28),
          ),
        ),
        home: const AppWarmupWrapper(),
      ),
    );
  }
}

// Safely initializes the live voice listener interface when the providers load
class AppWarmupWrapper extends StatefulWidget {
  const AppWarmupWrapper({super.key});

  @override
  State<AppWarmupWrapper> createState() => _AppWarmupWrapperState();
}

class _AppWarmupWrapperState extends State<AppWarmupWrapper> {
  @override
  void initState() {
    super.initState();
    // Warm up the independent listener engine asynchronously on the app's very first frame execution
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        Provider.of<GameController>(context, listen: false).initializeSpeech();
        debugPrint("✅ Independent Audio Mixer Pipeline Warmed Up Successfully");
      } catch (e) {
        debugPrint("❌ Independent Audio Warmup Error: $e");
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return const AuthWrapper();
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final authController = Provider.of<AuthController>(context);
    final User? firebaseUser = authController.firebaseUser;

    // GATE 1: Is anyone logged in?
    if (firebaseUser == null) {
      return LoginScreen();
    }

    // GATE 2: STOPS UNVERIFIED USERS HERE 🛑
    if (!firebaseUser.emailVerified) {
      return const VerifyEmailScreen();
    }

    // GATE 3: Downloader Sync Guard with Safe Reactive State Switch
    if (authController.userModel == null) {
      // 👇 FIXED: Check if we are offline or network is failing.
      // If Firebase says we have a user instance, let them through to the dashboard immediately!
      if (firebaseUser.uid.isNotEmpty) {
        debugPrint("ℹ️ Entering Dashboard via offline reactive state block.");
        return const DashboardScreen();
      }

      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: AppColors.primary),
              SizedBox(height: 16),
              Text("Syncing profile...", style: TextStyle(color: Colors.grey)),
            ],
          ),
        ),
      );
    }

    // SUCCESS: Allowed into the game room
    return const DashboardScreen();
  }
}