import 'package:flutter/material.dart';
import 'package:dash_master_toolkit/constant/app_color.dart';
import 'package:dash_master_toolkit/pages/auth/controller/sign_in_controller.dart';
import 'package:dash_master_toolkit/theme/theme_controller.dart';
import 'package:dash_master_toolkit/widgets/common_button.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';

import '../../../constant/app_images.dart';
import '../../../localization/app_localizations.dart';
import '../../../providers/auth_service.dart';
import '../../../utils/validation.dart';
import '../../../widgets/common_app_widget.dart';
import 'package:go_router/go_router.dart';
import '../../../route/my_route.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  SignInScreenState createState() => SignInScreenState();
}

class SignInScreenState extends State<SignInScreen> {
  final SignInController controller = SignInController();
  final ThemeController themeController = Get.put(ThemeController());

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.sizeOf(context).width;
    final screenHeight = MediaQuery.sizeOf(context).height;
    final lang = AppLocalizations.of(context);
    final desktopView = screenWidth >= 1200;

    // ✅ Remplacement de responsiveValue (responsive_grid) par MediaQuery
    final isMobile = screenWidth < 600;

    return GetBuilder<SignInController>(
      init: controller,
      tag: 'sign_in',
      builder: (controller) {
        return Scaffold(
          backgroundColor: themeController.isDarkMode ? colorDark : colorGrey50,
          body: Padding(
            padding: const EdgeInsets.only(bottom: 20.0),
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
                        end: 20,
                      ),
                      constraints: BoxConstraints(
                        minWidth: desktopView ? (screenWidth * 0.30) : screenWidth,
                      ),
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
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 20,
                                        vertical: isMobile ? 10 : 40,
                                      ),
                                      child: Form(
                                        key: controller.formKey,
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            _buildUserImageView(desktopView),
                                            const SizedBox(height: 10),

                                            Text(
                                              lang.translate("signYourAccount"),
                                              style: theme.textTheme.headlineSmall?.copyWith(
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            const SizedBox(height: 10),

                                            Text(
                                              lang.translate("enterYourDetailToSignIn"),
                                              style: theme.textTheme.bodyMedium?.copyWith(
                                                fontWeight: FontWeight.w400,
                                                color: colorGrey500,
                                              ),
                                              textAlign: TextAlign.center,
                                            ),

                                            // ✅ Bloc Google/Twitter + OR supprimés
                                            const SizedBox(height: 30),

                                            // -------- Username / Email --------
                                            Obx(
                                              () => TextFormField(
                                                style: theme.textTheme.bodyLarge?.copyWith(
                                                  color: themeController.isDarkMode
                                                      ? colorWhite
                                                      : colorGrey900,
                                                ),
                                                textInputAction: TextInputAction.next,
                                                keyboardType: TextInputType.text,
                                                focusNode: controller.f1,
                                                onFieldSubmitted: (v) {
                                                  controller.f1.unfocus();
                                                  FocusScope.of(context).requestFocus(controller.f2);
                                                },
                                                validator: (value) => validateUsernameOrEmail(value),
                                                onChanged: (value) {
                                                  controller.userNameFieldFocused.value = true;
                                                  controller.passwordFieldFocused.value = false;
                                                },
                                                autovalidateMode: controller.userNameFieldFocused.value
                                                    ? AutovalidateMode.onUserInteraction
                                                    : AutovalidateMode.disabled,
                                                controller: controller.userNameController,
                                                decoration: inputDecoration(
                                                  context,
                                                  topContentPadding: isMobile ? 15 : 20,
                                                  bottomContentPadding: isMobile ? 15 : 20,
                                                  hintText: lang.translate("usernameEmail"),
                                                ),
                                              ),
                                            ),

                                            const SizedBox(height: 20),

                                            // -------- Password --------
                                            Obx(
                                              () => TextFormField(
                                                style: theme.textTheme.bodyLarge?.copyWith(
                                                  color: themeController.isDarkMode
                                                      ? colorWhite
                                                      : colorGrey900,
                                                ),
                                                textInputAction: TextInputAction.done,
                                                keyboardType: TextInputType.text,
                                                focusNode: controller.f2,
                                                onFieldSubmitted: (v) {
                                                  controller.f2.unfocus();
                                                },
                                                validator: (value) => validatePassword(value),
                                                onChanged: (value) {
                                                  controller.userNameFieldFocused.value = false;
                                                  controller.passwordFieldFocused.value = true;
                                                },
                                                autovalidateMode: controller.passwordFieldFocused.value
                                                    ? AutovalidateMode.onUserInteraction
                                                    : AutovalidateMode.disabled,
                                                controller: controller.passwordController,
                                                obscureText: controller.isShowPasswordIcon.value,
                                                decoration: inputDecoration(
                                                  context,
                                                  topContentPadding: isMobile ? 15 : 20,
                                                  bottomContentPadding: isMobile ? 15 : 20,
                                                  onSuffixPressed: () {
                                                    controller.isShowPasswordIcon.value =
                                                        !controller.isShowPasswordIcon.value;
                                                  },
                                                  suffixIcon: controller.isShowPasswordIcon.value
                                                      ? eyeOffIcon
                                                      : eyeIcon,
                                                  hintText: lang.translate("password"),
                                                ),
                                              ),
                                            ),

                                            const SizedBox(height: 30),

                                            // -------- Remember + Forgot --------
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Flexible(
                                                  child: Row(
                                                    children: [
                                                      SizedBox(
                                                        width: 20,
                                                        height: 20,
                                                        child: Obx(
                                                          () => Checkbox(
                                                            side: BorderSide(
                                                              color: Get.isDarkMode
                                                                  ? colorGrey700
                                                                  : colorGrey100,
                                                              width: 2,
                                                            ),
                                                            shape: RoundedRectangleBorder(
                                                              borderRadius: BorderRadius.circular(6),
                                                            ),
                                                            activeColor: colorPrimary300,
                                                            value: controller.rememberMe.value,
                                                            onChanged: (value) =>
                                                                controller.rememberMe.value = value!,
                                                          ),
                                                        ),
                                                      ),
                                                      const SizedBox(width: 6),
                                                      Text(
                                                        lang.translate("keepMeLogIn"),
                                                        style: theme.textTheme.bodyMedium?.copyWith(
                                                          fontWeight: FontWeight.w400,
                                                          color: Get.isDarkMode
                                                              ? colorWhite
                                                              : colorGrey900,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                           /*    GestureDetector(
  onTap: () {
    context.go(MyRoute.forgotPasswordScreen);
  },
  child: Text(
    lang.translate("forgotPassword"),
    style: theme.textTheme.bodyMedium?.copyWith(
      decorationColor: colorPrimary300,
      decoration: TextDecoration.underline,
      fontWeight: FontWeight.w500,
      color: colorPrimary300,
    ),
  ),
),*/

                                              ],
                                            ),

                                            const SizedBox(height: 30),

                                            // -------- Button Sign In --------
                                            CommonButton(
                                              height: 55,
                                              bgColor: colorPrimary100,
                                              onPressed: () async {
                                                if (!controller.formKey.currentState!.validate()) return;

                                                try {
                                                  final authService = AuthService();

                                                  final email = controller.userNameController.text
                                                      .trim()
                                                      .toLowerCase();
                                                  final password = controller.passwordController.text;

                                                  await authService.signin(
                                                    email: email,
                                                    password: password,
                                                  );

                                                  if (!mounted) return;

                                                  context.go(MyRoute.dashboardSalesAdmin);
                                                } catch (e) {
                                                  if (!mounted) return;

                                                  final msg = e.toString().replaceFirst('Exception: ', '');
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    SnackBar(content: Text(msg)),
                                                  );
                                                }
                                              },
                                              text: lang.translate("signIn"),
                                            ),

                                            const SizedBox(height: 30),

                                            // -------- Sign Up Link --------
                                            InkWell(
                                              onTap: () {
                                                context.go(MyRoute.signUpScreen);
                                              },
                                              child: Text.rich(
                                                textAlign: TextAlign.center,
                                                TextSpan(
                                                  text: '${lang.translate("donHaveAcc")} ',
                                                  style: theme.textTheme.bodyMedium?.copyWith(
                                                    fontWeight: FontWeight.w400,
                                                    color: colorGrey500,
                                                  ),
                                                  children: [
                                                    TextSpan(
                                                      text: lang.translate("signUp"),
                                                      style: theme.textTheme.bodyMedium?.copyWith(
                                                        fontWeight: FontWeight.w600,
                                                        color: colorPrimary200,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),

                                            const SizedBox(height: 30),
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
