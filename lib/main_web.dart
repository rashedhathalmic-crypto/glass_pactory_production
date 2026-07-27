import 'main.dart' as application;

export 'main.dart' show NcGeneratorApp;

/// Backwards-compatible entry point for existing web build commands.
///
/// New builds use `main.dart` directly, so both entry points now have exactly
/// the same NC Generator startup behavior.
void main() => application.main();

typedef NcGeneratorWebApp = application.NcGeneratorApp;
