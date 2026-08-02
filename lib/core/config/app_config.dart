class AppConfig {
  static const apiBaseUrl = String.fromEnvironment(
    'BATMIN_API_URL',
    defaultValue: 'https://batminplatform.pro/api/v1',
  );
}
