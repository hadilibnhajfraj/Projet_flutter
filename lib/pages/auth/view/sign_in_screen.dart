import 'package:flutter/material.dart';
import 'package:dash_master_toolkit/constant/app_color.dart';
import 'package:dash_master_toolkit/pages/auth/controller/sign_in_controller.dart';
import 'package:dash_master_toolkit/theme/theme_controller.dart';
import 'package:dash_master_toolkit/widgets/common_button.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:responsive_grid/responsive_grid.dart';

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
  SignInController controller = SignInController();
  ThemeController themeController = Get.put(ThemeController());
  // late ThemeData theme;

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.sizeOf(context).width;
    final screenHeight = MediaQuery.sizeOf(context).height;
    final lang = AppLocalizations.of(context);
    final desktopView = screenWidth >= 1200;
    final AuthService authService = AuthService();

    final isMobile = responsiveValue<bool>(
      context,
      xs: true,
      sm: true,
      md: false,
      lg: false,
      xl: false,
    );

    return GetBuilder<SignInController>(
        init: controller,
        tag: 'sign_in',
        // theme: theme,
        builder: (controller) {
          return Scaffold(
            backgroundColor:
                themeController.isDarkMode ? colorDark : colorGrey50,
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
                            color: themeController.isDarkMode
                                ? colorGrey900
                                : Colors.white
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
                                              _buildUserImageView(desktopView),
                                              SizedBox(
                                                height: 10,
                                              ),
                                              Text(
                                                lang.translate(
                                                    "signYourAccount"),
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
                                                    "enterYourDetailToSignIn"),
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
                                              ResponsiveGridRow(
                                                children: [
                                                  ResponsiveGridCol(
                                                    xs: 12,
                                                    // Full width on extra small screens (mobile)
                                                    sm: 6,
                                                    // Half width on small screens (tablets)
                                                    md: 6,
                                                    // Half width on medium screens (desktop)
                                                    child: Padding(
                                                      padding: const EdgeInsets
                                                          .symmetric(
                                                          horizontal: 6.0,
                                                          vertical: 5.0),
                                                      child: _buildSocialButton(
                                                          lang.translate(
                                                              "google"),
                                                          googleIcon,
                                                          theme),
                                                    ),
                                                  ),
                                                  ResponsiveGridCol(
                                                    xs: 12,
                                                    // Full width on mobile
                                                    sm: 6,
                                                    // Half width on small screens (tablets)
                                                    md: 6,
                                                    // Half width on medium screens (desktop)
                                                    child: Padding(
                                                      padding: const EdgeInsets
                                                          .symmetric(
                                                          horizontal: 6.0,
                                                          vertical: 5.0),
                                                      child: _buildSocialButton(
                                                          lang.translate(
                                                              "twitter"),
                                                          themeController
                                                                  .isDarkMode
                                                              ? twitterWhiteIcon
                                                              : twitterIcon,
                                                          theme),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              SizedBox(
                                                height: 30,
                                              ),
                                              Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceAround,
                                                children: [
                                                  Flexible(
                                                    child: Container(
                                                      height: 1,
                                                      color: themeController
                                                              .isDarkMode
                                                          ? colorGrey700
                                                          : colorGrey100,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 10),
                                                  Text(
                                                    lang.translate("or"),
                                                    //'or',
                                                    style: theme
                                                        .textTheme.bodySmall
                                                        ?.copyWith(
                                                      fontWeight:
                                                          FontWeight.w500,
                                                      color: themeController
                                                              .isDarkMode
                                                          ? colorGrey500
                                                          : colorGrey400,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 10),
                                                  Flexible(
                                                    child: Container(
                                                      height: 1,
                                                      color: themeController
                                                              .isDarkMode
                                                          ? colorGrey700
                                                          : colorGrey100,
                                                    ),
                                                  )
                                                ],
                                              ),
                                              SizedBox(
                                                height: 30,
                                              ),
                                              Obx(
                                                () => TextFormField(
                                                  style: theme
                                                      .textTheme.bodyLarge
                                                      ?.copyWith(
                                                    color: themeController
                                                            .isDarkMode
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
                                                      validateUsernameOrEmail(
                                                          value),
                                                  onChanged: (value) {
                                                    controller
                                                        .userNameFieldFocused
                                                        .value = true;
                                                    controller
                                                        .passwordFieldFocused
                                                        .value = false;
                                                  },
                                                  autovalidateMode: controller
                                                          .userNameFieldFocused
                                                          .value
                                                      ? AutovalidateMode
                                                          .onUserInteraction
                                                      : AutovalidateMode
                                                          .disabled,
                                                  controller: controller
                                                      .userNameController,
                                                  decoration: inputDecoration(
                                                      context,
                                                      topContentPadding:
                                                          isMobile ? 15 : 20,
                                                      bottomContentPadding:
                                                          isMobile ? 15 : 20,
                                                      hintText: lang.translate(
                                                          "usernameEmail")),
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
                                                    color: themeController
                                                            .isDarkMode
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
                                                      validatePassword(value),
                                                  onChanged: (value) {
                                                    controller
                                                        .userNameFieldFocused
                                                        .value = false;
                                                    controller
                                                        .passwordFieldFocused
                                                        .value = true;
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
                                                      context,
                                                      onSuffixPressed: () {
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
                                                height: 30,
                                              ),
                                              Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceBetween,
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
                                                                  color: Get
                                                                          .isDarkMode
                                                                      ? colorGrey700
                                                                      : colorGrey100,
                                                                  width: 2),
                                                              shape:
                                                                  RoundedRectangleBorder(
                                                                borderRadius:
                                                                    BorderRadius
                                                                        .circular(
                                                                            6),
                                                              ),
                                                              activeColor:
                                                                  colorPrimary300,
                                                              value: controller
                                                                  .rememberMe
                                                                  .value,
                                                              onChanged: (value) =>
                                                                  controller
                                                                      .rememberMe
                                                                      .value = value!,
                                                            ),
                                                          ),
                                                        ),
                                                        SizedBox(
                                                          width: 6,
                                                        ),
                                                        Text(
                                                          lang.translate(
                                                              "keepMeLogIn"),
                                                          style: theme.textTheme
                                                              .bodyMedium
                                                              ?.copyWith(
                                                            fontWeight:
                                                                FontWeight.w400,
                                                            color: Get
                                                                    .isDarkMode
                                                                ? colorWhite
                                                                : colorGrey900,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  GestureDetector(
                                                    onTap: () {},
                                                    child: Text(
                                                      lang.translate(
                                                          "forgotPassword"),
                                                      style: theme
                                                          .textTheme.bodyMedium
                                                          ?.copyWith(
                                                        decorationColor:
                                                            colorPrimary300,
                                                        decoration:
                                                            TextDecoration
                                                                .underline,
                                                        fontWeight:
                                                            FontWeight.w500,
                                                        color: colorPrimary300,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              SizedBox(
                                                height: 30,
                                              ),
                                              CommonButton(
                                                  height: 55,
                                                  bgColor: colorPrimary100,
                                                  onPressed: () async {
                                                    if (!controller
                                                        .formKey.currentState!
                                                        .validate()) return;

                                                    try {
                                                      final authService =
                                                          AuthService();

                                                      final email = controller
                                                          .userNameController
                                                          .text
                                                          .trim()
                                                          .toLowerCase();
                                                      final password = controller
                                                          .passwordController
                                                          .text;

                                                      await authService.signin(
                                                          email: email,
                                                          password: password);

                                                      if (!mounted) return;

                                                      // ✅ Tous les rôles vont vers la même interface
                                                      context.go(MyRoute
                                                          .dashboardAcademicAdmin);
                                                    } catch (e) {
                                                      if (!mounted) return;

                                                      final msg = e
                                                          .toString()
                                                          .replaceFirst(
                                                              'Exception: ',
                                                              '');
                                                      ScaffoldMessenger.of(
                                                              context)
                                                          .showSnackBar(
                                                        SnackBar(
                                                            content: Text(msg)),
                                                      );
                                                    }
                                                  },
                                                  text:
                                                      lang.translate("signIn")),
                                              SizedBox(
                                                height: 30,
                                              ),
                                              InkWell(
                                                onTap: () {
    context.go(MyRoute.signUpScreen); 
  },
                                                child: Text.rich(
                                                  textAlign: TextAlign.center,
                                                  TextSpan(
                                                    text:
                                                        '${lang.translate("donHaveAcc")} ',
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
                                                            "signUp"),
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

  _buildSocialButton(String label, String asset, ThemeData theme) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: themeController.isDarkMode ? colorGrey700 : colorGrey100,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SvgPicture.asset(
            asset,
            height: 22,
            width: 22,
          ),
          SizedBox(
            width: 10,
          ),
          Text(
            label,
            style: theme.textTheme.bodyLarge
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  _buildUserImageView(bool desktopView) {
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
            border: Border.all(
                color:
                    themeController.isDarkMode ? colorGrey700 : colorGrey100),
            shape: BoxShape.circle),
        child: SvgPicture.asset(
          userIcon,
          colorFilter: ColorFilter.mode(
              themeController.isDarkMode ? Colors.white : colorGrey500,
              BlendMode.srcIn),
        ),
      ),
    );
  }
}
