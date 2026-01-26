import 'package:flutter/material.dart';
import 'package:get/get.dart';

class ResetPasswordController extends GetxController {
  // Text controllers for password and confirm password fields
  TextEditingController passwordController = TextEditingController();
  TextEditingController confirmPasswordController = TextEditingController();

  // Focus nodes for password fields
  FocusNode f1 = FocusNode();
  FocusNode f2 = FocusNode();

  // Form key for validation
  final formKey = GlobalKey<FormState>();

  // Observables to track focus states
  final passwordFieldFocused = false.obs;
  final confirmPasswordFieldFocused = false.obs;

  // Show password toggle logic
  RxBool isShowPasswordIcon = true.obs;
  RxBool isShowConfirmPasswordIcon = true.obs;

  @override
  void onInit() {
    super.onInit();
    // Optionally, you can fetch the password reset token and email if required
    // Example:
    // final arguments = Get.arguments;
    // passwordController.text = arguments['password'] ?? 'defaultPassword';
    // confirmPasswordController.text = arguments['password'] ?? 'defaultPassword';
  }

  // Function to toggle password visibility
  void togglePasswordVisibility() {
    isShowPasswordIcon.value = !isShowPasswordIcon.value;
  }

  // Function to toggle confirm password visibility
  void toggleConfirmPasswordVisibility() {
    isShowConfirmPasswordIcon.value = !isShowConfirmPasswordIcon.value;
  }
}
