import 'dart:async';

import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import 'package:dash_master_toolkit/core/config/api_config.dart';
import 'package:dash_master_toolkit/services/socket_service.dart';

import 'package:dash_master_toolkit/theme/theme_controller.dart';
import 'package:dash_master_toolkit/services/notification_api.dart';
import 'package:dash_master_toolkit/app_shell_route/models/notification.dart';
import 'package:dash_master_toolkit/providers/auth_service.dart';
class NotificationController extends GetxController {
  final themeController = Get.find<ThemeController>();
  final box = GetStorage();
  final RxInt page = 1.obs;
final RxBool hasMore = true.obs;
  final RxList<NotificationData> listOfNotification = <NotificationData>[].obs;
  final RxInt unreadCount = 0.obs;

  final RxBool isLoading = false.obs;

  String get token => AuthService().accessToken ?? "";

  // ── Temps réel ─────────────────────────────────────────────────────────
  // Événement « notification:new » (Socket.IO, salle de l'utilisateur
  // connecté uniquement) → badge incrémenté immédiatement puis liste relue
  // depuis l'API (seule source affichée : l'historique durable en base).
  // Après chaque (re)connexion, la liste est relue : aucun événement manqué
  // pendant une coupure n'est perdu. Filet de sécurité : relecture toutes les
  // 60 s si le temps réel est indisponible, et reconnexion avec le jeton
  // courant (jeton renouvelé ou autre utilisateur connecté).
  final SocketService _socket = SocketService.instance;
  Timer? _fallback;
  static const fallbackInterval = Duration(seconds: 60);

 @override
void onInit() {
  super.onInit();
  print("🔥 NotificationController INIT");
  fetchNotifications();
  _startRealtime();
  _lastToken = token;
  AuthService().addListener(_onAuthChanged);
}

  @override
  void onClose() {
    AuthService().removeListener(_onAuthChanged);
    _fallback?.cancel();
    _socket.off('notification:new');
    super.onClose();
  }

  // Connexion / déconnexion / changement de compte : la cloche (créée avant
  // la connexion) se met à jour immédiatement — notifications du compte
  // connecté et temps réel, sans attendre le prochain cycle de 60 s ; à la
  // déconnexion, plus aucune notification du compte précédent affichée.
  String _lastToken = '';
  void _onAuthChanged() {
    final t = token;
    if (t == _lastToken) return;
    _lastToken = t;
    _syncSocket();
    if (t.isEmpty) {
      listOfNotification.clear();
      unreadCount.value = 0;
      return;
    }
    fetchNotifications(silent: true);
  }

  void _startRealtime() {
    _socket.on('notification:new', (_) {
      unreadCount.value++;
      fetchNotifications(silent: true);
    });
    _socket.on('connect', (_) => fetchNotifications(silent: true));
    _syncSocket();
    _fallback = Timer.periodic(fallbackInterval, (_) {
      _syncSocket();
      if (!_socket.isConnected) fetchNotifications(silent: true);
    });
  }

  /// Connexion temps réel avec le jeton courant (aucune si déconnecté).
  void _syncSocket() {
    final t = token;
    if (t.isEmpty) {
      if (_socket.currentToken != null) _socket.disconnect();
      return;
    }
    _socket.connect(ApiConfig.wsBaseUrl, t);
  }

  // =========================
  // 📥 FETCH
  // =========================
Future<void> fetchNotifications({bool silent = false}) async {
  if (token.isEmpty) {
    print("⚠️ NOTIF: token vide → fetch annulé");
    return;
  }

  try {
    print("IS LOADING = ${isLoading.value} (avant fetch)");
    if (!silent) isLoading.value = true;

    page.value = 1;

    final res = await NotificationApi.instance.getMyNotifications(
      token,
      page: page.value,
    );

    listOfNotification.assignAll(res.items);
    unreadCount.value = res.unreadCount;
    hasMore.value = res.items.length >= 10;

    print("NOTIFICATION COUNT STATE = ${listOfNotification.length}");
    print("IS LOADING = ${isLoading.value} (après assignAll, avant finally)");

  } catch (e, s) {
    print("NOTIFICATION ERROR = $e");
    print(s);
  } finally {
    isLoading.value = false;
    print("IS LOADING = ${isLoading.value}");
  }
}

  // =========================
  // 🔵 MARK ALL READ (OPTIMISÉ)
  // =========================
  Future<void> markAllRead() async {
    if (token.isEmpty) return;

    try {
      await NotificationApi.instance.markAllRead(token);

      // 🔥 update local (sans refetch)
      for (var n in listOfNotification) {
        n.isRead = true; // ⚠️ nécessite modèle modifiable
      }

      unreadCount.value = 0;

      listOfNotification.refresh();

    } catch (e) {
      print("❌ MARK ALL ERROR: $e");
    }
  }

  // =========================
  // 🔵 MARK ONE READ (OPTIMISÉ)
  // =========================
  Future<void> markOneRead(String id) async {
    if (token.isEmpty) return;

    try {
      await NotificationApi.instance.markRead(token, id);

      // 🔥 update local
      final index =
          listOfNotification.indexWhere((n) => n.id == id);

      if (index != -1 && !listOfNotification[index].isRead) {
        listOfNotification[index].isRead = true;

        unreadCount.value =
            (unreadCount.value > 0) ? unreadCount.value - 1 : 0;

        listOfNotification.refresh();
      }

    } catch (e) {
      print("❌ MARK ONE ERROR: $e");
    }
  }

  // =========================
  // 🗑 DELETE
  // =========================
  Future<void> deleteNotification(String id) async {
    if (token.isEmpty) return;

    try {
      await NotificationApi.instance.deleteNotification(token, id);

      listOfNotification.removeWhere((n) => n.id == id);

      // recalcul unread
      unreadCount.value =
          listOfNotification.where((n) => !n.isRead).length;

    } catch (e) {
      print("❌ DELETE ERROR: $e");
    }
  }
  Future<void> loadMore() async {
  if (!hasMore.value || isLoading.value) return;

  try {
    isLoading.value = true;
    page.value++;

    final res = await NotificationApi.instance.getMyNotifications(
      token,
      page: page.value,
    );

    if (res.items.isEmpty) {
      hasMore.value = false;
    } else {
      listOfNotification.addAll(res.items);
    }

  } catch (e) {
    print("❌ LOAD MORE ERROR: $e");
  } finally {
    isLoading.value = false;
  }
}
}