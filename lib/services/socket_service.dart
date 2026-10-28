// lib/services/socket_service.dart
//
// Connexion Socket.IO unique et partagée (notifications, RH, archivage,
// maintenance). Le backend authentifie chaque connexion avec le jeton
// d'accès (même JWT que l'API) et place l'utilisateur dans sa propre salle :
// chaque client ne reçoit que ses propres événements.
//
//  - Les écouteurs sont mémorisés : enregistrés avant la connexion ou
//    rattachés après une reconnexion, ils ne sont jamais perdus.
//  - Reconnexion automatique illimitée après une coupure réseau.
//  - Jeton expiré ou changement d'utilisateur : `connect` avec le nouveau
//    jeton recrée la connexion (l'ancienne est fermée).
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

class SocketService {
  static final SocketService instance = SocketService._();
  SocketService._();

  io.Socket? _socket;
  String? _token;
  bool _intentionalDisconnect = false;
  final Map<String, List<void Function(dynamic)>> _handlers = {};

  bool get isConnected => _socket?.connected ?? false;

  /// Jeton utilisé par la connexion en cours (null : aucune connexion).
  String? get currentToken => _token;

  void connect(String baseUrl, String token) {
    // Même jeton : connexion existante (établie ou en cours) réutilisée.
    if (_socket != null && token == _token) return;
    if (_socket != null) _close(); // nouveau jeton (expiré / autre utilisateur)
    _intentionalDisconnect = false;
    _token = token;

    try {
      final socket = io.io(
        baseUrl,
        io.OptionBuilder()
            .setTransports(['websocket', 'polling'])
            .setAuth({'token': token})
            .enableAutoConnect()
            .enableReconnection()
            .setReconnectionAttempts(double.infinity)
            .setReconnectionDelay(2000)
            .setReconnectionDelayMax(30000)
            .enableForceNew()
            .build(),
      );
      _socket = socket;

      socket.onConnect((_) => debugPrint('[Socket] ✅ connected'));
      socket.onDisconnect((_) {
        if (!_intentionalDisconnect) debugPrint('[Socket] ⚠️ disconnected — will reconnect');
      });
      socket.onConnectError((e) => debugPrint('[Socket] connect error: $e'));

      for (final entry in _handlers.entries) {
        for (final h in entry.value) {
          socket.on(entry.key, h);
        }
      }
      socket.connect();
    } catch (e) {
      debugPrint('[Socket] init error: $e');
    }
  }

  void _close() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _token = null;
  }

  void disconnect() {
    _intentionalDisconnect = true;
    _close();
  }

  void on(String event, void Function(dynamic) handler) {
    _handlers.putIfAbsent(event, () => []).add(handler);
    _socket?.on(event, handler);
  }

  /// Retire [handler] seul (les autres écouteurs de l'événement restent) ;
  /// sans [handler], tous les écouteurs de l'événement.
  void off(String event, [void Function(dynamic)? handler]) {
    if (handler == null) {
      _handlers.remove(event);
      _socket?.off(event);
      return;
    }
    _handlers[event]?.remove(handler);
    _socket?.off(event, handler);
  }

  void emit(String event, [dynamic data]) {
    if (isConnected) {
      _socket?.emit(event, data);
    }
  }

  void joinRoom(String room) => emit('join', room);
  void leaveRoom(String room) => emit('leave', room);
}

// ── Polling fallback for real-time updates ─────────────────────────────────────
// Used when Socket.IO is not available on the backend.
class PollingService {
  Timer? _timer;

  void start({
    required Duration interval,
    required Future<void> Function() onTick,
  }) {
    _timer?.cancel();
    _timer = Timer.periodic(interval, (_) async {
      try { await onTick(); } catch (_) {}
    });
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }
}
