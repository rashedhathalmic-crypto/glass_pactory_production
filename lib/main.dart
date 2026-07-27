import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'features/nc_generator/presentation/nc_generator_screen.dart';

/// Application entry point.
///
/// The public web application starts directly in the NC Generator. Keeping the
/// startup page here (rather than in a separate build target) also makes the
/// default `flutter build web` entry point safe for GitHub Pages.
void main() {
  runApp(const NcGeneratorApp());
}

class NcGeneratorApp extends StatelessWidget {
  const NcGeneratorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DXF to NC Generator',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const Scaffold(body: NcGeneratorScreen()),
    );
  }
}
