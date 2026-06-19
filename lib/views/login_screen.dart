import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:animate_do/animate_do.dart';
import '../controllers/auth_controller.dart';
import '../constants/app_colors.dart';
import 'signup_screen.dart';

class LoginScreen extends StatelessWidget {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passController = TextEditingController();

  LoginScreen({super.key});

  InputDecoration _midnightInputDecoration(String hintText, IconData icon) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: const TextStyle(color: Colors.white54, fontSize: 16),
      prefixIcon: Icon(icon, color: AppColors.primary),
      filled: true,
      fillColor: AppColors.fieldBg,
      contentPadding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: Colors.white10, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthController>(context);

    return Scaffold(
      backgroundColor: Colors.black,
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
                // physics ensures clean bouncing layout on scroll checks
                physics: const ClampingScrollPhysics(),
                child: ConstrainedBox(
                  // Forces the viewport to take full height when keyboard is closed
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight,
                  ),
                  child: IntrinsicHeight(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 30.0),
                      child: Column(
                        children: [
                          const Spacer(flex: 2),

                          FadeInDown(
                            child: ZoomIn(
                              child: Image.asset(
                                'assets/images/safari_lion_waving.png',
                                height: MediaQuery.of(context).size.height * 0.18,
                              ),
                            ),
                          ),

                          const SizedBox(height: 20),
                          const Text(
                            "SAFARI NIGHTS",
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: 2,
                            ),
                          ),
                          const Text(
                            "Enter your key to start the hunt",
                            style: TextStyle(color: Colors.white60, fontSize: 15),
                          ),

                          const Spacer(flex: 2),

                          TextField(
                            controller: emailController,
                            style: const TextStyle(color: Colors.white),
                            decoration: _midnightInputDecoration("Email Address", Icons.alternate_email),
                          ),
                          const SizedBox(height: 15),
                          TextField(
                            controller: passController,
                            obscureText: true,
                            style: const TextStyle(color: Colors.white),
                            decoration: _midnightInputDecoration("Access Key", Icons.lock_open_rounded),
                          ),

                          const Spacer(flex: 2),

                          authProvider.isLoading
                              ? const CircularProgressIndicator(color: AppColors.primary)
                              : ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              minimumSize: const Size(double.infinity, 60),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                              elevation: 10,
                              shadowColor: AppColors.primary.withOpacity(0.4),
                            ),
                            onPressed: () async {
                              FocusScope.of(context).unfocus();

                              String? error = await authProvider.login(
                                  emailController.text,
                                  passController.text
                              );

                              if (error != null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(error),
                                    backgroundColor: AppColors.error,
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                );
                              } else {
                                debugPrint("Login successful, AuthWrapper will now rebuild.");
                              }
                            },
                            child: const Text("LAUNCH GAME", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, letterSpacing: 1.2)),
                          ),

                          const SizedBox(height: 15),
                          TextButton(
                            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => SignUpScreen())),
                            child: const Text("NEW PLAYER? JOIN HERE", style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                          ),
                          const Spacer(flex: 1),
                        ],
                      ),
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
}