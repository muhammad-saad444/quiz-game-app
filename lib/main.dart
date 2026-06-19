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
import 'services/app_provider.dart';
import 'views/login_screen.dart';
import 'views/dashoard/dashboard.dart';
import 'views/verify_email_address.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await requestPermissions();

  // 1. Robust Firebase Initialization with Error Reporting
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
  var speechStatus = await Permission.speech.status;

  if (!micStatus.isGranted || !speechStatus.isGranted) {
    await [
      Permission.microphone,
      Permission.speech,
    ].request();
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
        home: const AuthWrapper(),
      ),
    );
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
    // Firebase Auth creates the record, but this gate blocks them from moving forward!
    if (!firebaseUser.emailVerified) {
      return const VerifyEmailScreen();
    }

    // GATE 3: Downloader Sync Guard
    if (authController.userModel == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    // SUCCESS: Allowed into the game room
    return const DashboardScreen();
  }
}