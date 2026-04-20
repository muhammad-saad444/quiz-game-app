import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/auth_controller.dart';
import '../constants/app_colors.dart';

class VerifyEmailScreen extends StatelessWidget {
  const VerifyEmailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authController = Provider.of<AuthController>(context);

    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.bgTop, AppColors.bgBottom],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(30.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Glowing Email Icon
              FadeInDown(
                child: const Icon(Icons.mark_email_unread_rounded, size: 100, color: AppColors.primary),
              ),
              const SizedBox(height: 30),
              const Text(
                "VERIFY YOUR EMAIL",
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1.5),
              ),
              const SizedBox(height: 16),
              const Text(
                "We've sent a magic link to your inbox. Tap the link in the email to join the safari!",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),
              const SizedBox(height: 40),

              authController.isLoading
                  ? const CircularProgressIndicator(color: AppColors.primary)
                  : Column(
                children: [
                  ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 60),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      ),
                      onPressed: () => authController.checkEmailVerified(),
                      child: const Text("I'VE VERIFIED MY EMAIL", style: TextStyle(fontWeight: FontWeight.bold)),
                    ),

                  const SizedBox(height: 20),
                  TextButton(
                    onPressed: () => authController.logout(),
                    child: const Text("CANCEL / BACK TO LOGIN", style: TextStyle(color: Colors.white54, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}