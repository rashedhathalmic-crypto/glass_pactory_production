import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'core/helpers/generator_login_alert.dart';
import 'core/theme/app_theme.dart';
import 'features/nc_generator/presentation/image_to_dxf_screen.dart';
import 'features/nc_generator/presentation/nc_generator_screen.dart';
import 'features/nc_generator/presentation/nc_simulator_screen.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const NcGeneratorApp());
}

class NcGeneratorApp extends StatelessWidget {
  const NcGeneratorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Glass CNC Tools',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const _GeneratorLoginGate(),
    );
  }
}

class _GeneratorLoginGate extends StatelessWidget {
  const _GeneratorLoginGate();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return snapshot.data == null
            ? const _GeneratorLoginScreen()
            : const _GeneratorHome();
      },
    );
  }
}

class _GeneratorLoginScreen extends StatefulWidget {
  const _GeneratorLoginScreen();

  @override
  State<_GeneratorLoginScreen> createState() =>
      _GeneratorLoginScreenState();
}

class _GeneratorLoginScreenState extends State<_GeneratorLoginScreen> {
  static const _allowedUsername = 'MTVF-AGF';
  static const _accountEmail = 'rashedhathalmic@gmail.com';

  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;

    // Start the browser permission request directly from the sign-in click.
    // Browsers may reject notification prompts that are not user initiated.
    final notificationPermission = requestGeneratorNotificationPermission();

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _accountEmail,
        password: _passwordController.text,
      );

      if (await notificationPermission) {
        showGeneratorLoginNotification();
      }
      unawaited(
        sendGeneratorLoginEmail(
          username: _allowedUsername,
          accountEmail: _accountEmail,
        ),
      );
    } on FirebaseAuthException {
      if (mounted) {
        setState(() => _errorMessage = 'Invalid username or password');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Glass CNC Tools',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'NC generator, drawing converter and toolpath simulator',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 32),
                  TextFormField(
                    controller: _usernameController,
                    textCapitalization: TextCapitalization.characters,
                    autocorrect: false,
                    enableSuggestions: false,
                    decoration: const InputDecoration(
                      labelText: 'Username',
                      hintText: _allowedUsername,
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Username is required';
                      }
                      if (value.trim().toUpperCase() != _allowedUsername) {
                        return 'Invalid username';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _signIn(),
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        onPressed: () => setState(
                          () => _obscurePassword = !_obscurePassword,
                        ),
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                      ),
                    ),
                    validator: (value) => value == null || value.isEmpty
                        ? 'Password is required'
                        : null,
                  ),
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      _errorMessage!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ],
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: _isLoading ? null : _signIn,
                    icon: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.login),
                    label: Text(_isLoading ? 'Signing in...' : 'Sign In'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GeneratorHome extends StatefulWidget {
  const _GeneratorHome();

  @override
  State<_GeneratorHome> createState() => _GeneratorHomeState();
}

class _GeneratorHomeState extends State<_GeneratorHome> {
  final ValueNotifier<String> _generatedProgram = ValueNotifier('');

  @override
  void dispose() {
    _generatedProgram.dispose();
    super.dispose();
  }

  Future<void> _enableNotifications() async {
    final granted = await requestGeneratorNotificationPermission();
    if (granted) showGeneratorLoginNotification();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          granted
              ? 'Browser notifications are enabled.'
              : 'Notification permission was not granted by the browser.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Glass CNC Tools'),
          actions: [
            IconButton(
              onPressed: _enableNotifications,
              tooltip: 'Enable notifications',
              icon: const Icon(Icons.notifications_active_outlined),
            ),
            IconButton(
              onPressed: FirebaseAuth.instance.signOut,
              tooltip: 'Sign out',
              icon: const Icon(Icons.logout),
            ),
          ],
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(
                icon: Icon(Icons.precision_manufacturing),
                text: 'DXF → NC Grinding',
              ),
              Tab(
                icon: Icon(Icons.description_outlined),
                text: 'PDF / Image → Editable DXF',
              ),
              Tab(
                icon: Icon(Icons.animation),
                text: 'NC Simulator',
              ),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            NcGeneratorScreen(
              onProgramGenerated: (program) {
                _generatedProgram.value = program;
              },
            ),
            const ImageToDxfScreen(),
            NcSimulatorScreen(generatedProgram: _generatedProgram),
          ],
        ),
      ),
    );
  }
}
