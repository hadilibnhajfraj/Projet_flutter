import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import 'package:dash_master_toolkit/theme/theme_controller.dart';
import 'package:dash_master_toolkit/services/notification_api.dart';
import 'package:dash_master_toolkit/app_shell_route/models/notification.dart'; // ✅ le bon

class NotificationController extends GetxController {
  final themeController = Get.find<ThemeController>();
  final box = GetStorage();

  final RxList<NotificationData> listOfNotification = <NotificationData>[].obs;
  final RxInt unreadCount = 0.obs;

  // ✅ token stocké localement
  String get token => (box.read("token") ?? "").toString();

  @override
  void onInit() {
    super.onInit();
    fetchNotifications();
  }

  Future<void> fetchNotifications({bool silent = false}) async {
    if (token.isEmpty) {
      // pas connecté => pas d'appel API
      listOfNotification.clear();
      unreadCount.value = 0;
      return;
    }

    final res = await NotificationApi.instance.getMyNotifications(token);
    listOfNotification.assignAll(res.items);
    unreadCount.value = res.unreadCount;
  }

  Future<void> markAllRead() async {
    if (token.isEmpty) return;
    await NotificationApi.instance.markAllRead(token);
    await fetchNotifications(silent: true);
  }

  Future<void> markOneRead(String id) async {
    if (token.isEmpty) return;
    await NotificationApi.instance.markRead(token, id);
    await fetchNotifications(silent: true);
  }
}
