import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';
import 'dart:ui';

import '../../../providers/auth_service.dart';
import '../../../route/my_route.dart';
import '../controller/signup_controller.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final SignupController controller = SignupController();

  // 🔥 INPUT MODERNE
  Widget _buildInput({
    required TextEditingController controller,
    required String hint,
    bool isPassword = false,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: isPassword,
      style: const TextStyle(color: Colors.white),

      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white54),

        filled: true,
        fillColor: Colors.white.withOpacity(0.05),

        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 18,
        ),

        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(
            color: Colors.white.withOpacity(0.1),
          ),
        ),

        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(
            color: Colors.white.withOpacity(0.1),
          ),
        ),

        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(
            color: Colors.white.withOpacity(0.4),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final desktopView = screenWidth >= 1200;

    return GetBuilder<SignupController>(
      init: controller,
      builder: (controller) {
        return Scaffold(
          backgroundColor: Colors.transparent,

          body: SizedBox.expand(
            child: Stack(
              children: [
                // 🔥 BACKGROUND
                Positioned.fill(
                  child: Image.asset(
                    "assets/images/login_bg.png",
                    fit: BoxFit.cover,
                  ),
                ),

                // 🔥 OVERLAY
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.black.withOpacity(0.75),
                          Colors.black.withOpacity(0.5),
                          Colors.black.withOpacity(0.3),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                  ),
                ),

                // 🔥 FORMULAIRE
                Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                      child: Container(
                        padding: const EdgeInsets.all(28),
                        margin: const EdgeInsets.symmetric(horizontal: 20),
                        constraints: BoxConstraints(
                          maxWidth: desktopView ? 420 : double.infinity,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.35),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.08),
                          ),
                        ),

                        child: Form(
                          key: controller.formKey,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                "Create account",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),

                              const SizedBox(height: 8),

                              const Text(
                                "Sign up to get started",
                                style: TextStyle(color: Colors.white60),
                              ),

                              const SizedBox(height: 30),

                              _buildInput(
                                controller: controller.fullNameController,
                                hint: "Full Name",
                              ),

                              const SizedBox(height: 18),

                              _buildInput(
                                controller: controller.emailController,
                                hint: "Email",
                              ),

                              const SizedBox(height: 18),

                              _buildInput(
                                controller: controller.passwordController,
                                hint: "Password",
                                isPassword: true,
                              ),

                              const SizedBox(height: 20),

                              Row(
                                children: [
                                  Obx(() => Checkbox(
                                        value: controller.isTermAccepted.value,
                                        onChanged: (v) =>
                                            controller.isTermAccepted.value = v!,
                                        activeColor: Colors.white,
                                        checkColor: Colors.black,
                                      )),
                                  const Expanded(
                                    child: Text(
                                      "I agree to the terms",
                                      style: TextStyle(color: Colors.white60),
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 20),

                              // 🔥 BUTTON
                              SizedBox(
                                width: double.infinity,
                                height: 48,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    foregroundColor: Colors.black,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  onPressed: () async {
                                    final form = controller.formKey.currentState;

                                    if (form == null || !form.validate()) return;

                                    if (!controller.isTermAccepted.value) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                            content: Text(
                                                "Accept terms first")),
                                      );
                                      return;
                                    }

                                    try {
                                      final authService = AuthService();

                                      await authService.signup(
                                        email: controller.emailController.text,
                                        password:
                                            controller.passwordController.text,
                                      );

                                      if (!mounted) return;

                                      context.go(MyRoute.signInScreen);
                                    } catch (e) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                            content: Text(e.toString())),
                                      );
                                    }
                                  },
                                  child: const Text(
                                    "Sign Up",
                                    style: TextStyle(
                                        fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ),

                              const SizedBox(height: 20),

                              TextButton(
                                onPressed: () {
                                  context.go(MyRoute.signInScreen);
                                },
                                child: const Text(
                                  "Already have an account?",
                                  style: TextStyle(color: Colors.white60),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}