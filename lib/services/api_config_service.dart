
enum AppEnv { dev, production }

class ApiConfig {
  static const AppEnv _env = AppEnv.production;
  // static const AppEnv _env = AppEnv.dev;
  //
  // ── Environment base URLs ─────────────────────────────────────────────────
  static const String _productionBase = 'https://dbmarts.com/DBM/';
  static const String _devBase        = 'http://192.168.1.28:8001';

  // ── Active base URL (normalized — always ends with /) ─────────────────────
  static String get baseUrl {
    final raw = _env == AppEnv.production ? _productionBase : _devBase;
    return raw.endsWith('/') ? raw : '$raw/';
  }

  // ── Derived URLs ───────────────────────────────────────────────────────────
  static String get indexPhp  => '${baseUrl}index.php';
  static String get imageBase => '${baseUrl}image/';

  // ── Whether we are in dev mode ─────────────────────────────────────────────
  static bool get isDev => _env == AppEnv.dev;

  // ── API route builder ──────────────────────────────────────────────────────
  static String route(String routeName, {String? token}) {
    final base = '$indexPhp?route=$routeName';
    if (token != null && token.isNotEmpty) {
      return '$base&token=$token&api_token=$token';
    }
    return base;
  }
}