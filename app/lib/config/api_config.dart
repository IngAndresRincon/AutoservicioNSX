// Únicas fuentes de las api keys. Se pueden sobreescribir en build con
// --dart-define=API_KEY=... / --dart-define=SOCKET_API_KEY=... sin tocar código.
class ApiConfig {
  static const String apiKey = String.fromEnvironment('API_KEY', defaultValue: '');

  static const String socketApiKey = String.fromEnvironment(
    'SOCKET_API_KEY',
    defaultValue: '',
  );
}
