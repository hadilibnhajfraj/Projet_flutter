import 'package:flutter/cupertino.dart';
import 'package:dash_master_toolkit/application/users/users_imports.dart';
import 'package:responsive_framework/responsive_framework.dart' as rf;

class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({super.key});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  final UserProfileController controller = Get.put(UserProfileController());
  ThemeController themeController = Get.put(ThemeController());

  @override
  Widget build(BuildContext context) {
    AppLocalizations lang = AppLocalizations.of(context);
    ThemeData theme = Theme.of(context);
    double screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: themeController.isDarkMode ? colorGrey900 : colorWhite,
      body: SingleChildScrollView(
        padding: EdgeInsets.all(
          rf.ResponsiveValue<double>(
            context,
            conditionalValues: [
              const rf.Condition.between(start: 0, end: 340, value: 10),
              const rf.Condition.between(start: 341, end: 992, value: 16),
            ],
            defaultValue: 24,
          ).value,
        ),
        child: Obx(
          () => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // user name and designation widget
              _commonBackgroundWidget(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Image.asset(
                        profileIcon,
                        width: 60,
                        height: 60,
                      ),
                      SizedBox(
                        width: 10,
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              controller.profile.value!.name,
                              style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  overflow: TextOverflow.ellipsis),
                            ),
                            Text(
                              controller.profile.value!.designation,
                              style: theme.textTheme.bodyLarge?.copyWith(
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SvgPicture.asset(
                        verticalDotIcon,
                        width: 24,
                        height: 24,
                        colorFilter: ColorFilter.mode(
                            themeController.isDarkMode
                                ? colorGrey500
                                : colorGrey400,
                            BlendMode.srcIn),
                      ),
                    ],
                  ),
                  screenWidth: screenWidth),

              SizedBox(
                height: 15,
              ),

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
                          end: screenWidth > 768 ? 10 : 0),
                      child: Column(
                        children: [
                          _buildPersonalInfoWidget(theme, lang, screenWidth),
                          SizedBox(
                            height: 15,
                          ),
                          _buildOccupationInfoWidget(theme, lang, screenWidth),
                          SizedBox(
                            height: 15,
                          ),
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
                          start: screenWidth > 768 ? 10 : 0),
                      child: Column(
                        children: [
                          _buildActivityWidget(theme, lang, screenWidth),
                          SizedBox(
                            height: 15,
                          ),
                          _buildAllExperienceWidget(theme, lang, screenWidth),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  _commonBackgroundWidget(
      {required Widget child, required double? screenWidth}) {
    return Container(
      width: screenWidth,
      padding: EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: themeController.isDarkMode ? colorDark : colorWhite,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(blurRadius: 6, color: Colors.black12)],
      ),
      child: child,
    );
  }

  _buildPersonalInfoWidget(
      ThemeData theme, AppLocalizations lang, double? screenWidth) {
    return _commonBackgroundWidget(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              lang.translate("personalInformation"),
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            SizedBox(
              height: 5,
            ),
            _buildCommonInfoWidget(theme, userIcon, lang.translate("fullName"),
                controller.profile.value!.name),
            _buildCommonInfoWidget(theme, emailIcon, lang.translate("email"),
                controller.profile.value!.email),
            _buildCommonInfoWidget(theme, birthdayIcon, lang.translate("birthDay"),
                controller.profile.value!.birthday),
            _buildCommonInfoWidget(theme, phoneIcon, lang.translate("phone"),
                controller.profile.value!.phone),
            _buildCommonInfoWidget(theme, countryIcon, lang.translate("country"),
                controller.profile.value!.country),
            _buildCommonInfoWidget(theme, regionIcon,
                lang.translate("stateRegion"), controller.profile.value!.state),
            _buildCommonInfoWidget(theme, addressIcon, lang.translate("address"),
                controller.profile.value!.address),
          ],
        ),
        screenWidth: screenWidth);
  }

  _buildOccupationInfoWidget(
      ThemeData theme, AppLocalizations lang, double? screenWidth) {
    return _commonBackgroundWidget(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              lang.translate("occupationInfo"),
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            ResponsiveGridRow(
              // crossAxisAlignment: CrossAxisAlignment.center,
              children: List.generate(
                controller.profile.value!.occupationType.length,
                (index) {
                  OccupationModel occupationType =
                      controller.profile.value!.occupationType[index];
                  return ResponsiveGridCol(
                    lg: 6,
                    xl: 6,
                    md: 6,
                    xs: 6,
                    child: Padding(
                      padding:
                          EdgeInsetsDirectional.only(top: 10.0, bottom: 10.0),
                      child: Row(
                        children: [
                          Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(4),
                                  color: themeController.isDarkMode
                                      ? colorGrey700
                                      : colorGrey100),
                              child: Padding(
                                padding: const EdgeInsets.all(5.0),
                                child: commonCacheImageWidget(
                                  occupationType.icon,
                                  24,
                                  width: 24,
                                  fit: BoxFit.contain,
                                ),
                              ),),
                          SizedBox(
                            width: 5,
                          ),
                          Text(
                            occupationType.type,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w500,
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
        screenWidth: screenWidth);
  }

  _buildAboutMeWidget(
      ThemeData theme, AppLocalizations lang, double? screenWidth) {
    return _commonBackgroundWidget(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              lang.translate("aboutMe"),
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            SizedBox(
              height: 5,
            ),
            Text(
              controller.profile.value!.about,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w500, color: colorGrey500),
            ),
          ],
        ),
        screenWidth: screenWidth);
  }

  _buildActivityWidget(
      ThemeData theme, AppLocalizations lang, double? screenWidth) {
    return _commonBackgroundWidget(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              lang.translate("activity"),
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            SizedBox(
              height: 5,
            ),
            SizedBox(
                height: MediaQuery.of(context).size.height * 0.35,
                child: ListView.builder(
                  itemBuilder: (context, index) {
                    ActivityModel activity =
                        controller.profile.value!.activities[index];
                    return Padding(
                      padding: const EdgeInsets.only(top: 10.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          ClipOval(
                            child: commonCacheImageWidget(activity.icon, 48,
                                width: 48, fit: BoxFit.contain),
                          ),
                          SizedBox(
                            width: 10,
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  activity.deviceName,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                SizedBox(
                                  height: 2,
                                ),
                                Text(
                                  '${lang.translate("lastSeen")} : ${activity.status}',
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                      fontWeight: FontWeight.w400,
                                      color: themeController.isDarkMode
                                          ? colorGrey500
                                          : colorGrey400),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(
                            width: 10,
                          ),
                          Text(
                            'IME : ${activity.imei}',
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.w400,
                                color: themeController.isDarkMode
                                    ? colorGrey500
                                    : colorGrey400),
                          ),
                          SizedBox(
                            width: 10,
                          ),
                          Obx(
                            () => Transform.scale(
                                scale: 0.9,
                                // Adjust the scale factor to change the size
                                child: CupertinoSwitch(
                                  activeTrackColor: colorPrimary100,
                                  value: activity.isActive.value,
                                  onChanged: (value) {
                                    activity.isActive.value = value;
                                  },
                                )),
                          ),
                        ],
                      ),
                    );
                  },
                  shrinkWrap: true,
                  itemCount: controller.profile.value!.activities.length,
                )),
            SizedBox(
              height: 10,
            ),
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
            )
          ],
        ),
        screenWidth: screenWidth);
  }

  _buildAllExperienceWidget(
      ThemeData theme, AppLocalizations lang, double? screenWidth) {
    return _commonBackgroundWidget(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              lang.translate("allExperience"),
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            SizedBox(
              height: 5,
            ),
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.2,
              child: ListView.builder(
                itemBuilder: (context, index) {
                  ExperienceModel experience =
                      controller.profile.value!.experiences[index];
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
                              color: themeController.isDarkMode
                                  ? colorGrey700
                                  : colorGrey100),
                          child: Padding(
                            padding: const EdgeInsets.all(10.0),
                            child: commonCacheImageWidget(experience.icon, 48,
                                width: 48, fit: BoxFit.contain),
                          ),
                        ),
                        SizedBox(
                          width: 10,
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                experience.company,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              SizedBox(
                                height: 2,
                              ),
                              Text(
                                experience.position,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall?.copyWith(
                                    fontWeight: FontWeight.w400,
                                    color: themeController.isDarkMode
                                        ? colorGrey500
                                        : colorGrey400),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(
                          width: 10,
                        ),
                        Container(
                          decoration: BoxDecoration(
                            color: colorPrimary100.withValues(alpha: 0.20),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding:
                              EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          child: Text(
                            experience.type,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.w400,
                                color: colorPrimary100),
                          ),
                        ),
                      ],
                    ),
                  );
                },
                shrinkWrap: true,
                itemCount: controller.profile.value!.experiences.length,
              ),
            ),
          ],
        ),
        screenWidth: screenWidth);
  }

  _buildCommonInfoWidget(
      ThemeData theme, String assetName, String data, String answer) {
    return Padding(
      padding: const EdgeInsets.only(top: 10.0),
      child: Row(
        // mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          SvgPicture.asset(
            assetName,
            width: 18,
            height: 18,
            colorFilter: ColorFilter.mode(
                themeController.isDarkMode ? colorGrey500 : colorGrey700,
                BlendMode.srcIn),
          ),
          SizedBox(
            width: 5,
          ),
          SizedBox(
            width: 100,
            child: Text(
              data,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w400,
                  color:
                      themeController.isDarkMode ? colorGrey500 : colorGrey700),
            ),
          ),
          SizedBox(
            width: 10,
          ),
          Text(
            ":",
            style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w400,
                color:
                    themeController.isDarkMode ? colorGrey500 : colorGrey400),
          ),
          SizedBox(
            width: 10,
          ),
          Flexible(
            child: Text(
              answer,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}
