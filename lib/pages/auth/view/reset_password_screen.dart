import 'package:flutter/material.dart';
import 'package:dash_master_toolkit/constant/app_color.dart';
import 'package:dash_master_toolkit/pages/auth/controller/reset_password_controller.dart';
import 'package:dash_master_toolkit/theme/theme_controller.dart';
import 'package:dash_master_toolkit/widgets/common_button.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:responsive_grid/responsive_grid.dart';

import '../../../constant/app_images.dart';
import '../../../localization/app_localizations.dart';
import '../../../utils/validation.dart';
import '../../../widgets/common_app_widget.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  ResetPasswordScreenState createState() => ResetPasswordScreenState();
}

class ResetPasswordScreenState extends State<ResetPasswordScreen> {
  ResetPasswordController controller = ResetPasswordController();
  ThemeController themeController = Get.put(ThemeController());


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

    return GetBuilder<ResetPasswordController>(
        init: controller,
        tag: 'reset_password',
        // theme: theme,
        builder: (controller) {
          return Scaffold(
            backgroundColor: themeController.isDarkMode ? colorDark : colorGrey50,
            body: Padding(
              padding: EdgeInsets.only(
                bottom: 20.0,
              ),
              child: Stack(
                // alignment: Alignment.center,
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
                            top: isMobile
                                ? screenWidth * 0.20
                                : screenWidth * 0.06,
                            start: 20,
                            end: 20),
                        constraints: BoxConstraints(
                          minWidth:
                              desktopView ? (screenWidth * 0.30) : screenWidth,
                        ),
                        decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(15),
                            color: themeController.isDarkMode ? colorGrey900 : Colors.white
                            // color: theme.colorScheme.primaryContainer,
                            ),
                        child: SafeArea(
                          child: Column(
                            children: [
                              // Sign in form
                              Flexible(
                                child: ConstrainedBox(
                                  constraints:
                                      const BoxConstraints(maxWidth: 500),
                                  child: Center(
                                    child: ScrollConfiguration(
                                      behavior: ScrollBehavior()
                                          .copyWith(scrollbars: false),
                                      child: SingleChildScrollView(
                                        padding: EdgeInsets.symmetric(
                                            horizontal: 20,
                                            vertical: isMobile ? 10 : 40),
                                        child: Form(
                                          key: controller.formKey,
                                          child: Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              _buildLockImageView(desktopView),
                                              SizedBox(
                                                height: 10,
                                              ),
                                              Text(
                                                lang.translate(
                                                    "pleaseChoosePassword"),
                                                textAlign: TextAlign.center,
                                                //'Sign in',
                                                style: theme
                                                    .textTheme.headlineSmall
                                                    ?.copyWith(
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                              SizedBox(
                                                height: 10,
                                              ),
                                              Text(
                                                lang.translate(
                                                    "enterYourResetPassword"),
                                                textAlign: TextAlign.center,
                                                //'Sign in',
                                                style: theme
                                                    .textTheme.bodyMedium
                                                    ?.copyWith(
                                                        fontWeight:
                                                            FontWeight.w400,
                                                        color: colorGrey500),
                                              ),
                                              SizedBox(
                                                height: 30,
                                              ),
                                              Obx(
                                                () => TextFormField(
                                                  style: theme
                                                      .textTheme.bodyLarge
                                                      ?.copyWith(
                                                    color: themeController.isDarkMode
                                                        ? colorWhite
                                                        : colorGrey900, // Set your desired text color
                                                  ),
                                                  textInputAction:
                                                      TextInputAction.next,
                                                  keyboardType:
                                                      TextInputType.text,
                                                  focusNode: controller.f1,
                                                  onFieldSubmitted: (v) {
                                                    controller.f1.unfocus();
                                                    FocusScope.of(context)
                                                        .requestFocus(
                                                            controller.f2);
                                                  },
                                                  validator: (value) =>
                                                      validatePassword(value),
                                                  onChanged: (value) {
                                                    controller
                                                        .passwordFieldFocused
                                                        .value = true;
                                                    controller
                                                        .confirmPasswordFieldFocused
                                                        .value = false;
                                                  },
                                                  autovalidateMode: controller
                                                          .passwordFieldFocused
                                                          .value
                                                      ? AutovalidateMode
                                                          .onUserInteraction
                                                      : AutovalidateMode
                                                          .disabled,
                                                  controller: controller
                                                      .passwordController,
                                                  obscureText: controller
                                                      .isShowPasswordIcon.value,
                                                  decoration: inputDecoration(
                                                      topContentPadding:
                                                      isMobile ? 15 : 20,
                                                      bottomContentPadding:
                                                      isMobile ? 15 : 20,
                                                      context, onSuffixPressed: () {
                                                    controller
                                                            .isShowPasswordIcon
                                                            .value =
                                                        !controller
                                                            .isShowPasswordIcon
                                                            .value;
                                                  },
                                                      suffixIcon: (controller
                                                              .isShowPasswordIcon
                                                              .value)
                                                          ? eyeOffIcon
                                                          : eyeIcon,
                                                      hintText: lang.translate(
                                                          "password")),
                                                ),
                                              ),
                                              SizedBox(
                                                height: 20,
                                              ),
                                              Obx(
                                                () => TextFormField(
                                                  style: theme
                                                      .textTheme.bodyLarge
                                                      ?.copyWith(
                                                    color: themeController.isDarkMode
                                                        ? colorWhite
                                                        : colorGrey900, // Set your desired text color
                                                  ),
                                                  textInputAction:
                                                      TextInputAction.done,
                                                  keyboardType:
                                                      TextInputType.text,
                                                  focusNode: controller.f2,
                                                  onFieldSubmitted: (v) {
                                                    controller.f2.unfocus();
                                                  },
                                                  validator: (value) =>
                                                      validateConfirmPassword(
                                                          controller
                                                              .passwordController
                                                              .text,
                                                          value),
                                                  onChanged: (value) {
                                                    controller
                                                        .passwordFieldFocused
                                                        .value = false;
                                                    controller
                                                        .confirmPasswordFieldFocused
                                                        .value = true;
                                                  },
                                                  autovalidateMode: controller
                                                          .confirmPasswordFieldFocused
                                                          .value
                                                      ? AutovalidateMode
                                                          .onUserInteraction
                                                      : AutovalidateMode
                                                          .disabled,
                                                  controller: controller
                                                      .confirmPasswordController,
                                                  obscureText: controller
                                                      .isShowConfirmPasswordIcon
                                                      .value,
                                                  decoration: inputDecoration(
                                                      topContentPadding:
                                                      isMobile ? 15 : 20,
                                                      bottomContentPadding:
                                                      isMobile ? 15 : 20,
                                                      context, onSuffixPressed: () {
                                                    controller
                                                            .isShowConfirmPasswordIcon
                                                            .value =
                                                        !controller
                                                            .isShowConfirmPasswordIcon
                                                            .value;
                                                  },
                                                      suffixIcon: (controller
                                                              .isShowConfirmPasswordIcon
                                                              .value)
                                                          ? eyeOffIcon
                                                          : eyeIcon,
                                                      hintText: lang.translate(
                                                          "confirmPassword")),
                                                ),
                                              ),
                                              SizedBox(
                                                height: 30,
                                              ),
                                              CommonButton(
                                                  height: 55,
                                                  onPressed: () {
                                                    if (controller
                                                        .formKey.currentState!
                                                        .validate()) {}
                                                  },
                                                  text: lang.translate(
                                                      "changePassword")),
                                              SizedBox(
                                                height: 30,
                                              ),
                                              InkWell(
                                                onTap: () {},
                                                child: Text.rich(
                                                  textAlign: TextAlign.center,
                                                  TextSpan(
                                                    text: '${lang.translate("needHelp")} ',
                                                    style: theme
                                                        .textTheme.bodyMedium
                                                        ?.copyWith(
                                                            fontWeight:
                                                                FontWeight.w400,
                                                            color:
                                                                colorGrey500),
                                                    children: [
                                                      TextSpan(
                                                        text: lang.translate(
                                                            "contactUs"),
                                                        style: theme.textTheme
                                                            .bodyMedium
                                                            ?.copyWith(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w600,
                                                                color:
                                                                    colorPrimary200),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                              SizedBox(
                                                height: 30,
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
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        });
  }

  _buildLockImageView(bool desktopView) {
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
                      colorDarkG3
                    ]
                  : [colorG1.withValues(alpha: 0.48), colorG2, colorG3],
              stops: [0, 100, 100]),
          shape: BoxShape.circle),
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
                  spreadRadius: 0)
            ],
            border:
                Border.all(color: themeController.isDarkMode ? colorGrey700 : colorGrey100),
            shape: BoxShape.circle),
        child: SvgPicture.asset(
          lockIcon,colorFilter: ColorFilter.mode(themeController.isDarkMode ? Colors.white : colorGrey500, BlendMode.srcIn),
        ),
      ),
    );
  }
}
