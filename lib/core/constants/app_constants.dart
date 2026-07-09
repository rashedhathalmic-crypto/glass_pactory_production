abstract final class AppConstants {
  static const String appName = 'Glass Factory Production';
  static const String appVersion = '1.0.0';

  static const int desktopBreakpoint = 1200;
  static const int tabletBreakpoint = 768;

  static const int defaultPageSize = 25;
  static const int maxUploadSizeMb = 10;

  static const Duration sessionTimeout = Duration(hours: 8);
  static const Duration debounceDelay = Duration(milliseconds: 300);
}
