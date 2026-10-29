import 'package:flutter/material.dart';
import 'features/nc_generator/presentation/glass_cutting_screen.dart';

/// Windows offline development entrypoint.
/// Run: flutter run -d windows -t lib/main_cutting_offline.dart
/// No Firebase initialization, login or network access is required by this entrypoint.
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const CuttingOfflineApp());
}

class CuttingOfflineApp extends StatelessWidget {
  const CuttingOfflineApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Glass Cutting V2 - Offline',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(useMaterial3: true),
    home: const Scaffold(
      appBar: _CuttingOfflineBar(),
      body: GlassCuttingScreen(),
    ),
  );
}

class _CuttingOfflineBar extends StatelessWidget
    implements PreferredSizeWidget {
  const _CuttingOfflineBar();
  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
  @override
  Widget build(BuildContext context) => AppBar(
    title: const Text('Glass Cutting V2 - Offline Preview'),
  );
}
