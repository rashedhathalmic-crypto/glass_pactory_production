import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'core/helpers/browser_history.dart';
import 'core/helpers/generator_login_alert.dart';
import 'core/theme/app_theme.dart';
import 'features/nc_generator/presentation/image_to_dxf_screen.dart';
import 'features/nc_generator/presentation/nc_generator_screen.dart';
import 'features/nc_generator/presentation/nc_simulator_screen.dart';
import 'firebase_options.dart';

const _allowedUsername = 'MTVF-AGF';
const _ownerEmail = 'rashedhathalmic@gmail.com';
const _publishedWebUrl =
    'https://rashedhathalmic-crypto.github.io/glass_pactory_production/';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // A verified session survives page reloads, but closing the browser/tab
  // requires a fresh owner-email verification on the next login.
  if (kIsWeb) {
    await FirebaseAuth.instance.setPersistence(Persistence.SESSION);
  }

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

class _GeneratorLoginGate extends StatefulWidget {
  const _GeneratorLoginGate();

  @override
  State<_GeneratorLoginGate> createState() => _GeneratorLoginGateState();
}

class _GeneratorLoginGateState extends State<_GeneratorLoginGate> {
  bool _checkingSession = true;
  bool _approved = false;
  String? _startupError;

  @override
  void initState() {
    super.initState();
    unawaited(_restoreSession());
  }

  String _friendlyAuthError(FirebaseAuthException error) {
    switch (error.code) {
      case 'invalid-action-code':
      case 'expired-action-code':
        return 'انتهت صلاحية رابط التحقق أو تم استخدامه مسبقًا. سجّل الدخول وأرسل رابطًا جديدًا.';
      case 'operation-not-allowed':
        return 'تسجيل الدخول عبر رابط البريد غير مفعّل في Firebase Authentication.';
      case 'unauthorized-domain':
        return 'نطاق GitHub Pages غير مضاف إلى Authorized domains في Firebase Authentication.';
      case 'too-many-requests':
        return 'تم إرسال محاولات كثيرة خلال وقت قصير. انتظر قليلًا ثم أعد المحاولة.';
      default:
        return 'تعذر إكمال التحقق عبر البريد. أرسل رابط تحقق جديدًا.';
    }
  }

  Future<void> _restoreSession() async {
    final auth = FirebaseAuth.instance;

    try {
      if (kIsWeb) {
        final incomingLink = Uri.base.toString();
        if (auth.isSignInWithEmailLink(incomingLink)) {
          final credential = await auth.signInWithEmailLink(
            email: _ownerEmail,
            emailLink: incomingLink,
          );
          final email = credential.user?.email?.toLowerCase();
          if (email != _ownerEmail.toLowerCase()) {
            await auth.signOut();
            throw StateError('Unexpected verified email');
          }
          clearGeneratorEmailLinkFromAddressBar();
        }
      }

      final user = auth.currentUser ?? await auth.authStateChanges().first;
      final approved = user != null &&
          user.email?.toLowerCase() == _ownerEmail.toLowerCase();

      if (!approved && user != null) {
        await auth.signOut();
      }

      if (!mounted) return;
      setState(() {
        _approved = approved;
        _checkingSession = false;
      });
    } on FirebaseAuthException catch (error) {
      await auth.signOut();
      if (!mounted) return;
      setState(() {
        _approved = false;
        _checkingSession = false;
        _startupError = _friendlyAuthError(error);
      });
    } on Object {
      await auth.signOut();
      if (!mounted) return;
      setState(() {
        _approved = false;
        _checkingSession = false;
        _startupError = 'تعذر التحقق من جلسة الدخول. أعد المحاولة.';
      });
    }
  }

  Future<void> _handleSignOut() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    setState(() {
      _approved = false;
      _startupError = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_checkingSession) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final user = FirebaseAuth.instance.currentUser;
    if (_approved &&
        user != null &&
        user.email?.toLowerCase() == _ownerEmail.toLowerCase()) {
      return _GeneratorHome(onSignOut: _handleSignOut);
    }

    return _GeneratorLoginScreen(initialError: _startupError);
  }
}

class _GeneratorLoginScreen extends StatefulWidget {
  const _GeneratorLoginScreen({this.initialError});

  final String? initialError;

  @override
  State<_GeneratorLoginScreen> createState() =>
      _GeneratorLoginScreenState();
}

class _GeneratorLoginScreenState extends State<_GeneratorLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _waitingForEmailLink = false;
  bool _obscurePassword = true;
  String? _statusMessage;
  bool _statusIsError = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialError != null) {
      _statusMessage = widget.initialError;
      _statusIsError = true;
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _setFailure(String message) async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _waitingForEmailLink = false;
      _statusMessage = message;
      _statusIsError = true;
    });
  }

  String _friendlySignInError(FirebaseAuthException error) {
    switch (error.code) {
      case 'wrong-password':
      case 'invalid-credential':
      case 'user-not-found':
        return 'اسم المستخدم أو كلمة المرور غير صحيحة.';
      case 'operation-not-allowed':
        return 'يلزم تفعيل Email link في Firebase Authentication مرة واحدة.';
      case 'unauthorized-domain':
        return 'يلزم إضافة rashedhathalmic-crypto.github.io إلى Authorized domains في Firebase Authentication.';
      case 'too-many-requests':
        return 'تمت محاولات دخول كثيرة. انتظر قليلًا ثم أعد المحاولة.';
      case 'network-request-failed':
        return 'تعذر الاتصال بخدمة تسجيل الدخول. تحقق من الإنترنت.';
      default:
        return 'تعذر إكمال تسجيل الدخول. أعد المحاولة.';
    }
  }

  Future<void> _signIn() async {
    if (_isLoading || _waitingForEmailLink) return;
    if (!_formKey.currentState!.validate()) return;

    if (!kIsWeb) {
      await _setFailure(
        'التحقق الآمن عبر بريد المالك متاح من النسخة المنشورة على الويب فقط.',
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _statusMessage = 'جارٍ التحقق من اسم المستخدم وكلمة المرور...';
      _statusIsError = false;
    });

    try {
      final auth = FirebaseAuth.instance;
      final credential = await auth.signInWithEmailAndPassword(
        email: _ownerEmail,
        password: _passwordController.text,
      );

      if (credential.user?.email?.toLowerCase() != _ownerEmail.toLowerCase()) {
        await _setFailure('هذا الحساب غير مصرح له باستخدام المولد.');
        return;
      }

      final settings = ActionCodeSettings(
        url: _publishedWebUrl,
        handleCodeInApp: true,
      );

      await auth.sendSignInLinkToEmail(
        email: _ownerEmail,
        actionCodeSettings: settings,
      );

      // The password is only the first factor. Sign out immediately so nobody
      // can enter until the owner clicks the fresh email verification link.
      await auth.signOut();
      _passwordController.clear();

      final notificationPermission = requestGeneratorNotificationPermission();
      if (await notificationPermission) {
        showGeneratorLoginNotification(
          title: 'تم إرسال تحقق الدخول',
          body: 'افتح رابط التحقق المرسل إلى بريد المالك لإكمال الدخول.',
        );
      }

      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _waitingForEmailLink = true;
        _statusMessage =
            'تم قبول كلمة المرور. أُرسل الآن رابط تحقق آمن إلى بريد المالك. افتح الرابط من البريد لإكمال الدخول.';
        _statusIsError = false;
      });
    } on FirebaseAuthException catch (error) {
      await _setFailure(_friendlySignInError(error));
    } on Object {
      await _setFailure(
        'تعذر إرسال رابط التحقق إلى بريد المالك. أعد المحاولة.',
      );
    }
  }

  Future<void> _resetEmailLinkRequest() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    setState(() {
      _waitingForEmailLink = false;
      _statusMessage = null;
      _statusIsError = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final fieldsEnabled = !_isLoading && !_waitingForEmailLink;

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
                    style:
                        Theme.of(context).textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'NC generator, drawing converter and toolpath simulator',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'الدخول محمي بكلمة المرور ثم تحقق إلزامي من بريد المالك.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  TextFormField(
                    controller: _usernameController,
                    enabled: fieldsEnabled,
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
                    enabled: fieldsEnabled,
                    obscureText: _obscurePassword,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _signIn(),
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        onPressed: fieldsEnabled
                            ? () => setState(
                                  () => _obscurePassword =
                                      !_obscurePassword,
                                )
                            : null,
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
                  if (_statusMessage != null) ...[
                    const SizedBox(height: 18),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (_waitingForEmailLink)
                              const Padding(
                                padding: EdgeInsets.only(top: 2),
                                child: Icon(Icons.mark_email_read_outlined),
                              )
                            else
                              Icon(
                                _statusIsError
                                    ? Icons.error_outline
                                    : Icons.info_outline,
                                color: _statusIsError ? Colors.red : null,
                              ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _statusMessage!,
                                style: TextStyle(
                                  color: _statusIsError ? Colors.red : null,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: fieldsEnabled ? _signIn : null,
                    icon: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.login),
                    label: Text(
                      _isLoading
                          ? 'جارٍ التحقق...'
                          : _waitingForEmailLink
                              ? 'تحقق من بريد المالك'
                              : 'تسجيل الدخول وإرسال التحقق',
                    ),
                  ),
                  if (_waitingForEmailLink) ...[
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _resetEmailLinkRequest,
                      icon: const Icon(Icons.refresh),
                      label: const Text('إرسال طلب جديد'),
                    ),
                  ],
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
  const _GeneratorHome({required this.onSignOut});

  final Future<void> Function() onSignOut;

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
    if (granted) {
      showGeneratorLoginNotification(
        title: 'تم تفعيل الإشعارات',
        body: 'ستظهر إشعارات Glass CNC Tools في هذا المتصفح.',
      );
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          granted
              ? 'تم تفعيل إشعارات المتصفح.'
              : 'لم يمنح المتصفح إذن الإشعارات.',
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
              tooltip: 'تفعيل الإشعارات',
              icon: const Icon(Icons.notifications_active_outlined),
            ),
            IconButton(
              onPressed: widget.onSignOut,
              tooltip: 'تسجيل الخروج',
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
