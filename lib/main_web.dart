import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'features/nc_generator/presentation/nc_generator_screen.dart';

/// Standalone browser entry point for the public DXF to NC Generator.
///
/// The production application continues to use `main.dart`, including its
/// Firebase initialization and authenticated routes. GitHub Pages deliberately
/// builds this entry point so the public utility has no authentication or
/// production-management dependencies at runtime.
void main() {
  runApp(const NcGeneratorWebApp());
}

class NcGeneratorWebApp extends StatelessWidget {
  const NcGeneratorWebApp({super.key});

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
