import 'package:flutter/material.dart';
import 'package:dash_master_toolkit/constant/app_color.dart';
import 'package:dash_master_toolkit/pages/auth/controller/sign_in_controller.dart';
import 'package:dash_master_toolkit/theme/theme_controller.dart';
import 'package:dash_master_toolkit/widgets/common_button.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import '../../../widgets/user_name_dialog.dart';
import '../../../constant/app_images.dart';
import '../../../localization/app_localizations.dart';
import '../../../providers/auth_service.dart';
import '../../../utils/validation.dart';
import '../../../widgets/common_app_widget.dart';
import 'package:go_router/go_router.dart';
import '../../../route/my_route.dart';
import 'dart:ui';
import '../../../widgets/user_name_dialog.dart';
class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  SignInScreenState createState() => SignInScreenState();
}

class SignInScreenState extends State<SignInScreen> {
  final SignInController controller = SignInController();
  final ThemeController themeController = Get.put(ThemeController());
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
      hintStyle: const TextStyle(color: Colors.white60),

      filled: true,
      fillColor: Colors.white.withOpacity(0.08),

      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
    ),
  );
}
@override
Widget build(BuildContext context) {
  final theme = Theme.of(context);
  final screenWidth = MediaQuery.sizeOf(context).width;
  final lang = AppLocalizations.of(context);
  final desktopView = screenWidth >= 1200;
  final isMobile = screenWidth < 600;

  return GetBuilder<SignInController>(
    init: controller,
    tag: 'sign_in',
    builder: (controller) {
      return Scaffold(
        backgroundColor: Colors.transparent,

        body: SizedBox.expand(
          child: Stack(
            children: [
              // 🔥 BACKGROUND IMAGE FULL
              Positioned.fill(
                child: Image.asset(
                  "assets/images/login_bg.png",
                  fit: BoxFit.cover,
                ),
              ),

              // 🔥 OVERLAY PRO
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.black.withOpacity(0.7),
                        Colors.black.withOpacity(0.4),
                        Colors.black.withOpacity(0.2),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                ),
              ),

              // 🔥 FORMULAIRE CENTER
              Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                    child: Container(
                      margin: EdgeInsets.symmetric(horizontal: 20),
                      padding: const EdgeInsets.all(25),
                      constraints: BoxConstraints(
                        maxWidth: desktopView ? 450 : double.infinity,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),

                        // 🔥 GLASS EFFECT
                        color: Colors.white.withOpacity(0.10),

                        border: Border.all(
                          color: Colors.white.withOpacity(0.2),
                        ),

                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 25,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),

                      child: SingleChildScrollView(
                        child: Form(
                          key: controller.formKey,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                             
                              const SizedBox(height: 15),

                              Text(
                                "Sign In to your account",
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),

                              const SizedBox(height: 8),

                              Text(
                                "Enter your details to sign in",
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: Colors.white70,
                                ),
                              ),

                              const SizedBox(height: 30),

                              // 🔥 USERNAME
                              _buildInput(
                                controller: controller.userNameController,
                                hint: "Username or Email",
                              ),

                              const SizedBox(height: 20),

                              // 🔥 PASSWORD
                              _buildInput(
                                controller: controller.passwordController,
                                hint: "Password",
                                isPassword: true,
                              ),

                              const SizedBox(height: 20),

                              Row(
                                children: [
                                  Obx(() => Checkbox(
                                        value: controller.rememberMe.value,
                                        onChanged: (v) =>
                                            controller.rememberMe.value = v!,
                                        activeColor: Colors.blueAccent,
                                      )),
                                  const SizedBox(width: 5),
                                  const Text(
                                    "Keep me logged in",
                                    style: TextStyle(color: Colors.white70),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 20),

                              // 🔥 BUTTON
                              SizedBox(
                                width: double.infinity,
                                height: 50,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.black,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  onPressed: () async {
                                    if (!controller.formKey.currentState!
                                        .validate()) return;

                                    try {
                                      final authService = AuthService();

                                      await authService.signin(
                                        email: controller.userNameController.text,
                                        password:
                                            controller.passwordController.text,
                                      );
                                      // 🔥 LOGIN AUTO
await authService.signin(
  email: controller.userNameController.text,
  password: controller.passwordController.text,
);

// 🔥 CHECK ROLE
if (authService.userRole == "commercial") {
  await showUserNameDialog(context);
}
                                      //if (!mounted) return;

                                      context.go(
                                          MyRoute.dashboardSalesAdmin);
                                    } catch (e) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                            content: Text(e.toString())),
                                      );
                                    }
                                  },
                                  child: const Text(
  "Sign In",
  style: TextStyle(color: Colors.white70),
),
                                ),
                              ),

                              const SizedBox(height: 20),

                              TextButton(
                                onPressed: () {
                                  context.go(MyRoute.signUpScreen);
                                },
                                child: const Text(
                                  "Don't have an account? Sign Up",
                                  style: TextStyle(color: Colors.white70),
                                ),
                              ),
                            ],
                          ),
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
  Widget _buildUserImageView(bool desktopView) {
    return Container(
      width: desktopView ? 84 : 64,
      height: desktopView ? 84 : 84,
      padding: EdgeInsets.all(desktopView ? 15 : 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: themeController.isDarkMode
              ? [
                  colorDarkG1.withValues(alpha: 0.100),
                  colorDarkG2,
                  colorDarkG3,
                ]
              : [
                  colorG1.withValues(alpha: 0.48),
                  colorG2,
                  colorG3,
                ],
          stops: const [0, 100, 100],
        ),
        shape: BoxShape.circle,
      ),
      child: Container(
        width: 52,
        height: 52,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: themeController.isDarkMode ? colorGrey800 : colorWhite,
          boxShadow: [
            BoxShadow(
              color: colorDark.withValues(alpha: 0.04),
              blurRadius: themeController.isDarkMode ? 3.05 : 4,
              offset: Offset(0, themeController.isDarkMode ? 1.52 : 2),
              spreadRadius: 0,
            )
          ],
          border: Border.all(
            color: themeController.isDarkMode ? colorGrey700 : colorGrey100,
          ),
          shape: BoxShape.circle,
        ),
        child: SvgPicture.asset(
          userIcon,
          colorFilter: ColorFilter.mode(
            themeController.isDarkMode ? Colors.white : colorGrey500,
            BlendMode.srcIn,
          ),
        ),
      ),
    );
  }
}
