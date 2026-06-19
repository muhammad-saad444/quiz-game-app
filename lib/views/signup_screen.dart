import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:animate_do/animate_do.dart';
import '../controllers/auth_controller.dart';
import '../constants/app_colors.dart';

class SignUpScreen extends StatelessWidget {
  final TextEditingController nameController = TextEditingController(); // 👈 Added Controller
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passController = TextEditingController();
  final TextEditingController confirmPassController = TextEditingController();

  SignUpScreen({super.key});

  InputDecoration _midnightInputDecoration(String hintText, IconData icon) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: const TextStyle(color: Colors.white38, fontSize: 16),
      prefixIcon: Icon(icon, color: AppColors.primary, size: 24),
      filled: true,
      fillColor: AppColors.fieldBg,
      contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 24),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: Colors.white12, width: 1),
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
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
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
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight,
                  ),
                  child: IntrinsicHeight(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 30.0),
                      child: Column(
                        children: [
                          const Spacer(flex: 1),

                          FadeInDown(
                            child: ZoomIn(
                              child: Image.asset(
                                'assets/images/safari_lion_waving.png',
                                height: MediaQuery.of(context).size.height * 0.15,
                              ),
                            ),
                          ),

                          const Text(
                            "NEW PLAYER",
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: 2,
                            ),
                          ),
                          const Text("Join the midnight safari hunt", style: TextStyle(color: Colors.white54)),

                          const Spacer(flex: 1),

                          // 👈 PLAYER NAME INPUT FIELD
                          TextField(
                            controller: nameController,
                            style: const TextStyle(color: Colors.white),
                            textCapitalization: TextCapitalization.words,
                            decoration: _midnightInputDecoration("Player Name", Icons.person_outline_rounded),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: emailController,
                            style: const TextStyle(color: Colors.white),
                            keyboardType: TextInputType.emailAddress,
                            decoration: _midnightInputDecoration("Email Address", Icons.alternate_email),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: passController,
                            obscureText: true,
                            style: const TextStyle(color: Colors.white),
                            decoration: _midnightInputDecoration("Create Access Key", Icons.lock_outline),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: confirmPassController,
                            obscureText: true,
                            style: const TextStyle(color: Colors.white),
                            decoration: _midnightInputDecoration("Confirm Access Key", Icons.lock_reset_rounded),
                          ),

                          const Spacer(flex: 2),

                          authProvider.isLoading
                              ? const CircularProgressIndicator(color: AppColors.primary)
                              : ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              minimumSize: const Size(double.infinity, 60),
                              elevation: 10,
                              shadowColor: AppColors.primary.withOpacity(0.5),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                            ),
                            onPressed: () async {
                              // 1. Basic Validation Validation
                              if (nameController.text.trim().isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text("Please enter a player name!"), backgroundColor: AppColors.error)
                                );
                                return;
                              }
                              if (passController.text != confirmPassController.text) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text("The keys don't match!"), backgroundColor: AppColors.error)
                                );
                                return;
                              }

                              // 2. Call the Sign Up function passing the custom name value
                              String? error = await authProvider.signUp(
                                  emailController.text.trim(),
                                  passController.text.trim(),
                                  nameController.text.trim() // 👈 Passed parameter name field
                              );

                              if (error != null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(error), backgroundColor: AppColors.error)
                                );
                              } else {
                                if (context.mounted) {
                                  Navigator.pop(context);
                                }
                              }
                            },
                            child: const Text("CREATE ACCOUNT", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, letterSpacing: 1.2)),
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