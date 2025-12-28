import 'package:flutter/material.dart';
import 'package:get/get.dart';

class ResetPasswordController extends GetxController {
  TextEditingController passwordController = TextEditingController();
  TextEditingController confirmPasswordController = TextEditingController();

  FocusNode f1 = FocusNode();
  FocusNode f2 = FocusNode();

  final formKey = GlobalKey<FormState>();
  final passwordFieldFocused = false.obs;
  final confirmPasswordFieldFocused = false.obs;

  RxBool isShowPasswordIcon = true.obs;
  RxBool isShowConfirmPasswordIcon = true.obs;

  @override
  void onInit() {
    super.onInit();
    passwordController.text = "Test@123";
    confirmPasswordController.text = "Test@123";
  }
}
