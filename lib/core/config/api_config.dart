/// Production-ready API configuration
/// 
/// Centralized API base URLs for all platforms:
/// - Web: http://localhost:4000 ; https://api.crmprobar.com
/// - Mobile (Android): http://localhost:4000 (or 10.0.2.2:4000 for emulator)
/// - Desktop: http://localhost:4000 ; https://api.crmprobar.com
/// - Desktop: http://localhost:4000 ; https://api.crmprobar.com
/// - Desktop: http://localhost:4000 ; https://api.crmprobar.com

class ApiConfig {
  /// API base URL - change to production URL or environment variable as needed
  static const String baseUrl = 'https://api.crmprobar.com';

  /// WebSocket (Socket.IO) : même serveur que l'API — le client passe
  /// automatiquement en ws:// (http) ou wss:// (https).
  static const String wsBaseUrl = baseUrl;

  /// Convenience getters
  static String get apiPath => baseUrl;
  static String get socketPath => wsBaseUrl;

  /// Platform constants (for future use)
  static const String hostLocal = 'localhost';
  static const String hostAndroidEmulator = '10.0.2.2';
  static const int port = 4000;
}
