


import '../common_imports.dart';

class NotificationIconButton extends StatefulWidget {
  const NotificationIconButton({
    super.key,
    this.notificationCount = 0,
  });

  final int notificationCount;

  @override
  State<NotificationIconButton> createState() => _NotificationIconButtonState();
}

class _NotificationIconButtonState extends State<NotificationIconButton> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    NotificationController controller = Get.put(NotificationController());

    return PopupMenuButton<int>(
      offset: Offset(0, 25),
      padding: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      itemBuilder: (BuildContext context) {
        return [
          PopupMenuItem<int>(
            enabled: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      AppLocalizations.of(context)
                          .translate("notifications"),
                      style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: controller.themeController.isDarkMode
                              ? colorWhite
                              : colorGrey900),
                    ),
                    const SizedBox(width: 3),
                    Expanded(
                      child: Text(
                        AppLocalizations.of(context)
                            .translate("markAllRead"),
                        maxLines: 3,
                        textAlign: TextAlign.end,
                        style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600, color: colorPrimary100),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                DashedDivider()
              ],
            ),
          ),
          ...controller.listOfNotification.asMap().entries.map((entry) {
            int index = entry.key;
            NotificationData notification = entry.value;
            return PopupMenuItem<int>(
                value: index,
                child: NotificationListWidget(notification: notification));
          }),
          PopupMenuItem<int>(
              enabled: false,
              child: Text(
                AppLocalizations.of(context)
                    .translate("viewAllNotifications"),
                style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600, color: colorPrimary100),
              )),
        ];
      },
      child: Stack(
        children: [
          SvgPicture.asset(
            bellIcon,
            width: 22,
            height: 22,
            colorFilter: ColorFilter.mode(
                controller.themeController.isDarkMode
                    ? colorWhite
                    : colorGrey900,
                BlendMode.srcIn),
          ),
          Positioned(
            right: 0,
            top: 0,
            child: Container(
              width: 10,
              height: 10,
              decoration:
              BoxDecoration(shape: BoxShape.circle, color: colorError100),
            ),
          )
        ],
      ),
    );
  }
}
