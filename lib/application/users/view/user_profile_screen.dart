import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:responsive_framework/responsive_framework.dart' as rf;

import 'package:dash_master_toolkit/application/users/users_imports.dart';

class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({super.key});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  final UserProfileController controller = Get.put(UserProfileController());
  final ThemeController themeController = Get.put(ThemeController());

  @override
  Widget build(BuildContext context) {
    final AppLocalizations lang = AppLocalizations.of(context);
    final ThemeData theme = Theme.of(context);
    final double screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: themeController.isDarkMode ? colorGrey900 : colorWhite,
      body: SingleChildScrollView(
        padding: EdgeInsets.all(
          rf.ResponsiveValue<double>(
            context,
            conditionalValues: const [
              rf.Condition.between(start: 0, end: 340, value: 10),
              rf.Condition.between(start: 341, end: 992, value: 16),
            ],
            defaultValue: 24,
          ).value,
        ),
        child: Obx(() {
          final p = controller.profile.value;

          // ✅ éviter crash avant load
          if (p == null) {
            return const Center(child: CircularProgressIndicator());
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ---------------- HEADER ----------------
              _commonBackgroundWidget(
                screenWidth: screenWidth,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Image.asset(profileIcon, width: 60, height: 60),
                    const SizedBox(width: 10),

                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Obx(() {
                            final editing = controller.isEditing.value;
                            return editing
                                ? TextFormField(
                                    controller: controller.nameCtrl,
                                    decoration: inputDecoration(context, hintText: "Name"),
                                  )
                                : Text(
                                    p.name,
                                    style: theme.textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  );
                          }),
                          const SizedBox(height: 6),
                          Obx(() {
                            final editing = controller.isEditing.value;
                            return editing
                                ? TextFormField(
                                    controller: controller.designationCtrl,
                                    decoration: inputDecoration(context, hintText: "Designation"),
                                  )
                                : Text(
                                    p.designation,
                                    style: theme.textTheme.bodyLarge?.copyWith(
                                      fontWeight: FontWeight.w400,
                                    ),
                                  );
                          }),
                        ],
                      ),
                    ),

                    // ✅ actions edit/save/cancel
                    Obx(() {
                      final editing = controller.isEditing.value;

                      if (!editing) {
                        return CommonButton(
                          onPressed: controller.startEdit,
                          text: "Edit",
                          width: 90,
                          height: 38,
                          borderRadius: 8,
                          fontSize: 14,
                        );
                      }

                      return Row(
                        children: [
                          CommonButton(
                            onPressed: () async {
                              await controller.saveEdit();
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text("Profil mis à jour ✅")),
                              );
                            },
                            text: "Save",
                            width: 90,
                            height: 38,
                            borderRadius: 8,
                            fontSize: 14,
                          ),
                          const SizedBox(width: 10),
                          CommonButton(
                            onPressed: controller.cancelEdit,
                            text: "Cancel",
                            width: 90,
                            height: 38,
                            borderRadius: 8,
                            fontSize: 14,
                          ),
                        ],
                      );
                    }),
                  ],
                ),
              ),

              const SizedBox(height: 15),

              // ---------------- GRID ----------------
              ResponsiveGridRow(
                children: [
                  ResponsiveGridCol(
                    xs: 12,
                    sm: 12,
                    md: 12,
                    lg: 5,
                    xl: 5,
                    child: Padding(
                      padding: EdgeInsetsDirectional.only(
                        end: screenWidth > 768 ? 10 : 0,
                      ),
                      child: Column(
                        children: [
                          _buildPersonalInfoWidget(theme, lang, screenWidth),
                          const SizedBox(height: 15),
                          _buildOccupationInfoWidget(theme, lang, screenWidth),
                          const SizedBox(height: 15),
                          _buildAboutMeWidget(theme, lang, screenWidth),
                        ],
                      ),
                    ),
                  ),
                  ResponsiveGridCol(
                    xs: 12,
                    md: 12,
                    sm: 12,
                    lg: 7,
                    xl: 7,
                    child: Padding(
                      padding: EdgeInsetsDirectional.only(
                        start: screenWidth > 768 ? 10 : 0,
                      ),
                      child: Column(
                        children: [
                          _buildActivityWidget(theme, lang, screenWidth),
                          const SizedBox(height: 15),
                          _buildAllExperienceWidget(theme, lang, screenWidth),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          );
        }),
      ),
    );
  }

  // =====================================================
  // UI HELPERS
  // =====================================================

  Widget _commonBackgroundWidget({required Widget child, required double? screenWidth}) {
    return Container(
      width: screenWidth,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: themeController.isDarkMode ? colorDark : colorWhite,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [BoxShadow(blurRadius: 6, color: Colors.black12)],
      ),
      child: child,
    );
  }

  // ✅ row texte / input selon isEditing
  Widget _editableRow({
    required ThemeData theme,
    required String iconAsset,
    required String label,
    required TextEditingController ctrl,
    TextInputType? keyboardType,
  }) {
    return Obx(() {
      final editing = controller.isEditing.value;

      return Padding(
        padding: const EdgeInsets.only(top: 10.0),
        child: Row(
          children: [
            SvgPicture.asset(
              iconAsset,
              width: 18,
              height: 18,
              colorFilter: ColorFilter.mode(
                themeController.isDarkMode ? colorGrey500 : colorGrey700,
                BlendMode.srcIn,
              ),
            ),
            const SizedBox(width: 5),
            SizedBox(
              width: 110,
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w400,
                  color: themeController.isDarkMode ? colorGrey500 : colorGrey700,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              ":",
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w400,
                color: themeController.isDarkMode ? colorGrey500 : colorGrey400,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: editing
                  ? TextFormField(
                      controller: ctrl,
                      keyboardType: keyboardType,
                      decoration: inputDecoration(context, hintText: label),
                    )
                  : Text(
                      ctrl.text,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
            ),
          ],
        ),
      );
    });
  }

  // =====================================================
  // SECTIONS
  // =====================================================

  Widget _buildPersonalInfoWidget(ThemeData theme, AppLocalizations lang, double? screenWidth) {
    return _commonBackgroundWidget(
      screenWidth: screenWidth,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            lang.translate("personalInformation"),
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 5),

          _editableRow(theme: theme, iconAsset: userIcon, label: lang.translate("fullName"), ctrl: controller.nameCtrl),
          _editableRow(theme: theme, iconAsset: emailIcon, label: lang.translate("email"), ctrl: controller.emailCtrl, keyboardType: TextInputType.emailAddress),
          _editableRow(theme: theme, iconAsset: birthdayIcon, label: lang.translate("birthDay"), ctrl: controller.birthdayCtrl),
          _editableRow(theme: theme, iconAsset: phoneIcon, label: lang.translate("phone"), ctrl: controller.phoneCtrl, keyboardType: TextInputType.phone),
          _editableRow(theme: theme, iconAsset: countryIcon, label: lang.translate("country"), ctrl: controller.countryCtrl),
          _editableRow(theme: theme, iconAsset: regionIcon, label: lang.translate("stateRegion"), ctrl: controller.stateCtrl),
          _editableRow(theme: theme, iconAsset: addressIcon, label: lang.translate("address"), ctrl: controller.addressCtrl),
        ],
      ),
    );
  }

  Widget _buildOccupationInfoWidget(ThemeData theme, AppLocalizations lang, double? screenWidth) {
    final p = controller.profile.value!;
    return _commonBackgroundWidget(
      screenWidth: screenWidth,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            lang.translate("occupationInfo"),
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          ResponsiveGridRow(
            children: List.generate(
              p.occupationType.length,
              (index) {
                final occupationType = p.occupationType[index];
                return ResponsiveGridCol(
                  lg: 6,
                  xl: 6,
                  md: 6,
                  xs: 6,
                  child: Padding(
                    padding: const EdgeInsetsDirectional.only(top: 10.0, bottom: 10.0),
                    child: Row(
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(4),
                            color: themeController.isDarkMode ? colorGrey700 : colorGrey100,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(5.0),
                            child: commonCacheImageWidget(
                              occupationType.icon,
                              24,
                              width: 24,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            occupationType.type,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAboutMeWidget(ThemeData theme, AppLocalizations lang, double? screenWidth) {
    final p = controller.profile.value!;
    return _commonBackgroundWidget(
      screenWidth: screenWidth,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            lang.translate("aboutMe"),
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 5),
          Text(
            p.about,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
              color: colorGrey500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityWidget(ThemeData theme, AppLocalizations lang, double? screenWidth) {
    final p = controller.profile.value!;
    return _commonBackgroundWidget(
      screenWidth: screenWidth,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            lang.translate("activity"),
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 5),
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.35,
            child: ListView.builder(
              itemCount: p.activities.length,
              itemBuilder: (context, index) {
                final activity = p.activities[index];
                return Padding(
                  padding: const EdgeInsets.only(top: 10.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      ClipOval(
                        child: commonCacheImageWidget(activity.icon, 48, width: 48, fit: BoxFit.contain),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              activity.deviceName,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${lang.translate("lastSeen")} : ${activity.status}',
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.w400,
                                color: themeController.isDarkMode ? colorGrey500 : colorGrey400,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'IME : ${activity.imei}',
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w400,
                          color: themeController.isDarkMode ? colorGrey500 : colorGrey400,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Obx(() => Transform.scale(
                            scale: 0.9,
                            child: CupertinoSwitch(
                              activeTrackColor: colorPrimary100,
                              value: activity.isActive.value,
                              onChanged: (value) => activity.isActive.value = value,
                            ),
                          )),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: CommonButton(
              onPressed: () {},
              text: lang.translate("save"),
              width: 90,
              height: 38,
              borderRadius: 8,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAllExperienceWidget(ThemeData theme, AppLocalizations lang, double? screenWidth) {
    final p = controller.profile.value!;
    return _commonBackgroundWidget(
      screenWidth: screenWidth,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            lang.translate("allExperience"),
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 5),
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.2,
            child: ListView.builder(
              itemCount: p.experiences.length,
              itemBuilder: (context, index) {
                final experience = p.experiences[index];
                return Padding(
                  padding: const EdgeInsets.only(top: 10.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: themeController.isDarkMode ? colorGrey700 : colorGrey100,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(10.0),
                          child: commonCacheImageWidget(experience.icon, 48, width: 48, fit: BoxFit.contain),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              experience.company,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              experience.position,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.w400,
                                color: themeController.isDarkMode ? colorGrey500 : colorGrey400,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        decoration: BoxDecoration(
                          color: colorPrimary100.withValues(alpha: 0.20),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        child: Text(
                          experience.type,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w400,
                            color: colorPrimary100,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
