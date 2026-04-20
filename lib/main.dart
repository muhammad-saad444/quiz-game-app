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
    // You can handle critical initialization failure here if needed
  }

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));

  runApp(const MyApp());
}

Future<void> requestPermissions() async {
  // Check current status first
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
    final User? firebaseUser = FirebaseAuth.instance.currentUser;

    // 1. If no user is logged in, show Login Screen
    if (firebaseUser == null) {
      return LoginScreen();
    }

    // 2. If logged in but data isn't loaded, show loader
    // NOTE: If this spins forever, Firestore is either empty or unreachable.
    if (authController.userModel == null) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(color: AppColors.primary),
              const SizedBox(height: 20),
              Text(
                "Syncing Safari Data...",
                style: TextStyle(color: Colors.white.withOpacity(0.7)),
              ),
            ],
          ),
        ),
      );
    }

    // 3. Check Session Expiry (24-hour logic)
    final lastLogin = authController.userModel!.lastLogin;
    if (lastLogin != null) {
      final hoursPassed = DateTime.now().difference(lastLogin).inHours;
      if (hoursPassed >= 24) {
        // Log out on next frame to avoid build-phase navigation errors
        Future.microtask(() => authController.logout());
        return LoginScreen();
      }
    }

    // 4. Verification Gate
    if (firebaseUser.emailVerified) {
      return const DashboardScreen();
    } else {
      return const VerifyEmailScreen();
    }
  }
}