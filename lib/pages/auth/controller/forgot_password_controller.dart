import 'package:flutter/material.dart';
import 'package:get/get.dart';

class ForgotPasswordController extends GetxController {
  TextEditingController emailController = TextEditingController();

  FocusNode f1 = FocusNode();

  final formKey = GlobalKey<FormState>();
  final emailFieldFocused = false.obs;

  @override
  void onInit() {
    super.onInit();
    emailController.text = "yourname@gmail.com";
  }
}
