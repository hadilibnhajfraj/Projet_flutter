
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../constant/app_color.dart';
import '../../theme/theme_controller.dart';
import '../common_app_widget.dart';
import '../dotted_line.dart';
import 'model/notification.dart';

class NotificationListWidget extends StatelessWidget {
  final NotificationData notification;

  const NotificationListWidget({super.key, required this.notification});

  @override
  Widget build(BuildContext context) {
    ThemeData theme = Theme.of(context);
    ThemeController themeController = Get.put(ThemeController());
    // final screenWidth = MediaQuery.sizeOf(context).width;

    return Padding(
      padding: const EdgeInsets.only(top: 15.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              commonCacheImageWidget(notification.icon, 36,
                  width: 36, fit: BoxFit.contain),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      notification.title,
                      style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: themeController.isDarkMode
                              ? colorWhite
                              : colorGrey900),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      notification.message,
                      maxLines: 3,
                      style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w400,
                          color: notification.isUnread
                              ? themeController.isDarkMode
                                  ? colorWhite
                                  : colorGrey900
                              : colorGrey500),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      notification.timeAgo,
                      style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w400,
                          color: themeController.isDarkMode
                              ? colorGrey500
                              : colorGrey400),
                    )
                  ],
                ),
              ),
              const SizedBox(width: 10),
              if (notification.isUnread)
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                      shape: BoxShape.circle, color: colorError100),
                )
            ],
          ),
          const SizedBox(height: 16),
          DashedDivider()
        ],
      ),
    );
  }
}
