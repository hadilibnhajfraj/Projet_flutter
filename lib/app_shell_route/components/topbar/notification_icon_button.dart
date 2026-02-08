import '../common_imports.dart' hide NotificationController, NotificationData;
import 'package:get/get.dart';

import 'package:dash_master_toolkit/app_shell_route/components/topbar/NotificationController.dart';
import 'package:dash_master_toolkit/app_shell_route/models/notification.dart';

class NotificationIconButton extends StatelessWidget {
  const NotificationIconButton({
    super.key,
    this.notificationCount = 0,
  });

  final int notificationCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // ✅ IMPORTANT : ne pas Get.put() ici
    final NotificationController controller =
    Get.isRegistered<NotificationController>()
        ? Get.find<NotificationController>()
        : Get.put(NotificationController(), permanent: true);


    return Obx(() {
      final int count = controller.unreadCount.value;

      return PopupMenuButton<int>(
        offset: const Offset(0, 25),
        padding: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),

        // ✅ refresh quand on ouvre
        onOpened: () => controller.fetchNotifications(silent: true),

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
                        AppLocalizations.of(context).translate("notifications"),
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: controller.themeController.isDarkMode
                              ? colorWhite
                              : colorGrey900,
                        ),
                      ),
                      const SizedBox(width: 3),
                      Expanded(
                        child: InkWell(
                          onTap: () => controller.markAllRead(),
                          child: Text(
                            AppLocalizations.of(context).translate("markAllRead"),
                            maxLines: 2,
                            textAlign: TextAlign.end,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: colorPrimary100,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const DashedDivider(),
                ],
              ),
            ),

            // ✅ notifications list
            ...controller.listOfNotification.asMap().entries.map((entry) {
              final index = entry.key;
              final NotificationData notification = entry.value;

              return PopupMenuItem<int>(
                value: index,
                child: InkWell(
                  onTap: () => controller.markOneRead(notification.id),
                  child: NotificationListWidget(notification: notification),
                ),
              );
            }),

            PopupMenuItem<int>(
              enabled: false,
              child: Text(
                AppLocalizations.of(context).translate("viewAllNotifications"),
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colorPrimary100,
                ),
              ),
            ),
          ];
        },

        child: Stack(
          children: [
            SvgPicture.asset(
              bellIcon,
              width: 22,
              height: 22,
              colorFilter: ColorFilter.mode(
                controller.themeController.isDarkMode ? colorWhite : colorGrey900,
                BlendMode.srcIn,
              ),
            ),

            if (count > 0)
              Positioned(
                right: 0,
                top: 0,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
  shape: BoxShape.circle,
  color: colorError100,
),

                  constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
                  child: Center(
                    child: Text(
                      count > 99 ? "99+" : "$count",
                      style: const TextStyle(fontSize: 9, color: Colors.white),
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
    });
  }
}
