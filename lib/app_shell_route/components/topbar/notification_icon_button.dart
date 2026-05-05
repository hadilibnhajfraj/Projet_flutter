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

    final NotificationController controller =
        Get.isRegistered<NotificationController>()
            ? Get.find<NotificationController>()
            : Get.put(NotificationController(), permanent: true);

    return Obx(() {
      final int count = controller.unreadCount.value;

      return GestureDetector(
        onTap: () {
          showDialog(
            context: context,
            builder: (_) => Dialog(
              child: SizedBox(
                height: 450,
                width: 400,
                child: Column(
                  children: [
                    _buildHeader(context, controller, theme),
                    const Divider(height: 1),
                    Expanded(child: _buildList(controller, context)),
                  ],
                ),
              ),
            ),
          );
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
                  constraints:
                      const BoxConstraints(minWidth: 14, minHeight: 14),
                  child: Center(
                    child: Text(
                      count > 99 ? "99+" : "$count",
                      style: const TextStyle(
                        fontSize: 9,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
    });
  }

  // ================= HEADER =================
  Widget _buildHeader(
    BuildContext context,
    NotificationController controller,
    ThemeData theme,
  ) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            AppLocalizations.of(context).translate("notifications"),
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          TextButton(
            onPressed: () => controller.markAllRead(),
            child: Text(
              AppLocalizations.of(context).translate("markAllRead"),
            ),
          ),
        ],
      ),
    );
  }

  // ================= LIST + PAGINATION =================
  Widget _buildList(
    NotificationController controller,
    BuildContext context,
  ) {
    return NotificationListener<ScrollNotification>(
      onNotification: (scrollInfo) {
        if (scrollInfo.metrics.pixels ==
            scrollInfo.metrics.maxScrollExtent) {
          controller.loadMore();
        }
        return false;
      },
      child: Obx(() {
        return ListView.builder(
          itemCount: controller.listOfNotification.length,
          itemBuilder: (context, index) {
            final notification = controller.listOfNotification[index];

            return InkWell(
              onTap: () {
                controller.markOneRead(notification.id);
                _showNotificationDetails(context, notification);
              },
              child: NotificationListWidget(
                notification: notification,
              ),
            );
          },
        );
      }),
    );
  }

  // ================= POPUP DETAIL =================
  void _showNotificationDetails(
    BuildContext context,
    NotificationData notification,
  ) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(notification.title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Type: ${notification.type}"),
            const SizedBox(height: 10),
            Text(notification.message),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Fermer"),
          ),
        ],
      ),
    );
  }
}