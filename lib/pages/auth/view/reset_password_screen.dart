import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../providers/auth_service.dart';
import '../../../localization/app_localizations.dart';
import '../../../theme/theme_controller.dart';
import '../../../widgets/common_button.dart';
import '../../../widgets/common_app_widget.dart';

import 'package:dash_master_toolkit/pages/auth/controller/reset_password_controller.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  ResetPasswordScreenState createState() => ResetPasswordScreenState();
}

class ResetPasswordScreenState extends State<ResetPasswordScreen> {
  // Initialisation correcte du contrôleur
  ResetPasswordController controller = Get.put(ResetPasswordController()); 
  final AuthService _authService = AuthService();
  ThemeController themeController = Get.put(ThemeController());

  // Fonction pour traiter la réinitialisation du mot de passe
  Future<void> _resetPassword() async {
    if (controller.formKey.currentState?.validate() ?? false) {
      try {
        // Vous devez passer l'email et le token réel ici
        await _authService.resetPassword(
          email: "user@example.com",  // Remplacez par l'email réel
          token: "token_from_url",    // Remplacez par le token réel
          newPassword: controller.passwordController.text,
        );
        Get.snackbar('Success', 'Password reset successful. Please log in again.');
      } catch (e) {
        Get.snackbar('Error', 'Failed to reset password.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.sizeOf(context).width;
    final screenHeight = MediaQuery.sizeOf(context).height;

    return GetBuilder<ResetPasswordController>(
        init: controller,  // Utilisation correcte de GetBuilder
        builder: (controller) {
          return Scaffold(
            backgroundColor: themeController.isDarkMode ? Colors.black : Colors.white,
            body: Padding(
              padding: EdgeInsets.all(20.0),
              child: Column(
                children: [
                  TextFormField(
                    controller: controller.passwordController,
                    obscureText: controller.isShowPasswordIcon.value,
                    decoration: InputDecoration(
                      labelText: 'New Password',
                      hintText: 'Enter your new password',
                      suffixIcon: IconButton(
                        icon: Icon(
                          controller.isShowPasswordIcon.value
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                        onPressed: controller.togglePasswordVisibility,
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Password is required';
                      }
                      if (value.length < 8) {
                        return 'Password must be at least 8 characters';
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: 20),
                  TextFormField(
                    controller: controller.confirmPasswordController,
                    obscureText: controller.isShowConfirmPasswordIcon.value,
                    decoration: InputDecoration(
                      labelText: 'Confirm Password',
                      hintText: 'Confirm your new password',
                      suffixIcon: IconButton(
                        icon: Icon(
                          controller.isShowConfirmPasswordIcon.value
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                        onPressed: controller.toggleConfirmPasswordVisibility,
                      ),
                    ),
                    validator: (value) {
                      if (value != controller.passwordController.text) {
                        return 'Passwords do not match';
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: 20),
                  CommonButton(
                    height: 55,
                    onPressed: _resetPassword,  // Appel de la fonction _resetPassword
                    text: 'Change Password',
                  ),
                ],
              ),
            ),
          );
        });
  }
}
