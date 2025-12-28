import 'package:flutter/material.dart';
import 'package:get/get.dart';

class SignupController extends GetxController {
  TextEditingController fullNameController = TextEditingController();
  TextEditingController emailController = TextEditingController();
  TextEditingController passwordController = TextEditingController();
  RxBool isTermAccepted = false.obs;

  FocusNode f1 = FocusNode();
  FocusNode f2 = FocusNode();
  FocusNode f3 = FocusNode();

  final formKey = GlobalKey<FormState>();
  final fullNameFieldFocused = false.obs;
  final emailFieldFocused = false.obs;
  final passwordFieldFocused = false.obs;

  RxBool isShowPasswordIcon = true.obs;

  @override
  void onInit() {
    super.onInit();
    fullNameController.text = "yourname123";
    emailController.text = "yourname@gmail.com";
    passwordController.text = "Test@123";
  }
}
