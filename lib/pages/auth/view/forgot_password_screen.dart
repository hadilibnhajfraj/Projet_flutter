import 'package:flutter/material.dart';
import 'package:dash_master_toolkit/constant/app_color.dart';
import 'package:dash_master_toolkit/pages/auth/controller/forgot_password_controller.dart';
import 'package:dash_master_toolkit/theme/theme_controller.dart';
import 'package:dash_master_toolkit/widgets/common_button.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:responsive_grid/responsive_grid.dart';

import '../../../constant/app_images.dart';
import '../../../localization/app_localizations.dart';
import '../../../utils/validation.dart';
import '../../../widgets/common_app_widget.dart';
import '../../../providers/auth_service.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ForgotPasswordScreenState createState() => ForgotPasswordScreenState();
}

class ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  ForgotPasswordController controller = ForgotPasswordController();
  final AuthService _authService = AuthService();  // Add AuthService
  ThemeController themeController = Get.put(ThemeController());

  Future<void> _forgotPassword() async {
    if (controller.formKey.currentState?.validate() ?? false) {
      try {
        // Call forgotPassword method from AuthService
        await _authService.forgotPassword(email: controller.emailController.text);
        Get.snackbar('Success', 'If the email exists, a reset link has been sent.');
      } catch (e) {
        Get.snackbar('Error', 'Failed to send reset link.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.sizeOf(context).width;
    final screenHeight = MediaQuery.sizeOf(context).height;
    final lang = AppLocalizations.of(context);
    final desktopView = screenWidth >= 1200;

    final isMobile = responsiveValue<bool>(
      context,
      xs: true,
      sm: true,
      md: false,
      lg: false,
      xl: false,
    );

    return GetBuilder<ForgotPasswordController>(
        init: controller,
        tag: 'forgot_password',
        builder: (controller) {
          return Scaffold(
            backgroundColor: themeController.isDarkMode ? colorDark : colorGrey50,
            body: Padding(
              padding: EdgeInsets.only(bottom: 20.0),
              child: Stack(
                children: [
                  Container(
                    color: colorPrimary100,
                    width: screenWidth,
                    height: screenHeight / 2,
                  ),
                  Center(
                    child: IntrinsicHeight(
                      child: Container(
                        margin: EdgeInsetsDirectional.only(
                            top: isMobile ? screenWidth * 0.20 : screenWidth * 0.06,
                            start: 20,
                            end: 20),
                        constraints: BoxConstraints(minWidth: desktopView ? (screenWidth * 0.30) : screenWidth),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(15),
                          color: themeController.isDarkMode ? colorGrey900 : Colors.white,
                        ),
                        child: SafeArea(
                          child: Column(
                            children: [
                              Flexible(
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(maxWidth: 500),
                                  child: Center(
                                    child: ScrollConfiguration(
                                      behavior: ScrollBehavior().copyWith(scrollbars: false),
                                      child: SingleChildScrollView(
                                        padding: EdgeInsets.symmetric(horizontal: 20, vertical: isMobile ? 10 : 40),
                                        child: Form(
                                          key: controller.formKey,
                                          child: Column(
                                            children: [
                                              _buildEmailImageView(desktopView),
                                              SizedBox(height: 10),
                                              Text(
                                                lang.translate("forgotPassword1"),
                                                style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600),
                                              ),
                                              SizedBox(height: 10),
                                              Text(
                                                lang.translate("enterYourEmailToReset"),
                                                style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w400, color: colorGrey500),
                                              ),
                                              SizedBox(height: 30),
                                              Obx(
                                                () => TextFormField(
                                                  style: theme.textTheme.bodyLarge?.copyWith(
                                                    color: themeController.isDarkMode ? colorWhite : colorGrey900,
                                                  ),
                                                  textInputAction: TextInputAction.done,
                                                  keyboardType: TextInputType.emailAddress,
                                                  focusNode: controller.f1,
                                                  onFieldSubmitted: (v) {
                                                    controller.f1.unfocus();
                                                  },
                                                  validator: (value) => validateEmail(value, context),
                                                  onChanged: (value) {
                                                    controller.emailFieldFocused.value = true;
                                                  },
                                                  autovalidateMode: controller.emailFieldFocused.value
                                                      ? AutovalidateMode.onUserInteraction
                                                      : AutovalidateMode.disabled,
                                                  controller: controller.emailController,
                                                  decoration: inputDecoration(
                                                    context,
                                                    topContentPadding: isMobile ? 15 : 20,
                                                    bottomContentPadding: isMobile ? 15 : 20,
                                                    hintText: lang.translate("email"),
                                                  ),
                                                ),
                                              ),
                                              SizedBox(height: 30),
                                              CommonButton(
                                                height: 55,
                                                onPressed: _forgotPassword,  // Call _forgotPassword here
                                                text: lang.translate("resetPassword"),
                                              ),
                                              SizedBox(height: 30),
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
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        });
  }

  _buildEmailImageView(bool desktopView) {
    return Container(
      width: desktopView ? 84 : 64,
      height: desktopView ? 84 : 84,
      padding: EdgeInsets.all(desktopView ? 15 : 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: themeController.isDarkMode
              ? [colorDarkG1.withValues(alpha: 0.100), colorDarkG2, colorDarkG3]
              : [colorG1.withValues(alpha: 0.48), colorG2, colorG3],
          stops: [0, 100, 100],
        ),
        shape: BoxShape.circle,
      ),
      child: Container(
        width: 52,
        height: 52,
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: themeController.isDarkMode ? colorGrey800 : colorWhite,
          boxShadow: [
            BoxShadow(
              color: colorDark.withValues(alpha: 0.04),
              blurRadius: themeController.isDarkMode ? 3.05 : 4,
              offset: Offset(0, themeController.isDarkMode ? 1.52 : 2),
              spreadRadius: 0,
            ),
          ],
          border: Border.all(color: themeController.isDarkMode ? colorGrey700 : colorGrey100),
          shape: BoxShape.circle,
        ),
        child: SvgPicture.asset(
          emailIcon,
          colorFilter: ColorFilter.mode(themeController.isDarkMode ? Colors.white : colorGrey500, BlendMode.srcIn),
        ),
      ),
    );
  }
}

