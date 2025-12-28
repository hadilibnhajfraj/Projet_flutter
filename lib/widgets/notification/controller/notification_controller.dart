import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../../constant/app_images.dart';
import '../../../theme/theme_controller.dart';
import '../model/notification.dart';

class NotificationController extends GetxController {
  ThemeController themeController = Get.put(ThemeController());
  RxList<NotificationData> listOfNotification = <NotificationData>[].obs;

  Future<List<NotificationData>> getNotificationList() async {
    listOfNotification.clear();
    String jsonData =
        await rootBundle.loadString('${dataPath}notification_list.json');
    dynamic data = json.decode(jsonData);
    List<dynamic> jsonArray = data['notification_list'];

    for (int i = 0; i < jsonArray.length; i++) {
      listOfNotification.add(NotificationData.fromJson(jsonArray[i]));
    }
    return listOfNotification;
  }

  @override
  void onInit() {
    getNotificationList();

    super.onInit();
  }


}
