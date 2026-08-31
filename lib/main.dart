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

class _GeneratorLoginGate extends StatefulWidget {
  const _GeneratorLoginGate();

  @override
  State<_GeneratorLoginGate> createState() => _GeneratorLoginGateState();
}

class _GeneratorLoginGateState extends State<_GeneratorLoginGate> {
  bool _checkingSession = true;
  bool _approved = false;

  @override
  void initState() {
    super.initState();
    unawaited(_restoreSession());
  }

  Future<void> _restoreSession() async {
    final user = await FirebaseAuth.instance.authStateChanges().first;
    final approvedUntil = readGeneratorApprovalExpiry();
    final approved = user != null &&
        approvedUntil != null &&
        approvedUntil.isAfter(DateTime.now());

    if (!approved && user != null) {
      clearGeneratorApproval();
      await FirebaseAuth.instance.signOut();
    }

    if (!mounted) return;
    setState(() {
      _approved = approved;
      _checkingSession = false;
    });
  }

  void _handleApproved() {
    if (!mounted) return;
    setState(() => _approved = true);
  }

  Future<void> _handleSignOut() async {
    clearGeneratorApproval();
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    setState(() => _approved = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_checkingSession) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final user = FirebaseAuth.instance.currentUser;
    if (_approved && user != null) {
      return _GeneratorHome(onSignOut: _handleSignOut);
    }

    return _GeneratorLoginScreen(onApproved: _handleApproved);
  }
}

class _GeneratorLoginScreen extends StatefulWidget {
  const _GeneratorLoginScreen({required this.onApproved});

  final VoidCallback onApproved;

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
  bool _waitingForApproval = false;
  bool _obscurePassword = true;
  bool _cancelPolling = false;
  String? _statusMessage;
  bool _statusIsError = false;

  @override
  void dispose() {
    _cancelPolling = true;
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  int? _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  Future<void> _setFailure(String message) async {
    clearGeneratorApproval();
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _waitingForApproval = false;
      _statusMessage = message;
      _statusIsError = true;
    });
  }

  Future<void> _cancelRequest() async {
    _cancelPolling = true;
    await _setFailure('تم إلغاء طلب الدخول.');
  }

  Future<void> _signIn() async {
    if (_isLoading || _waitingForApproval) return;
    if (!_formKey.currentState!.validate()) return;

    _cancelPolling = false;

    // Browser permission prompts must start from the user's click.
    final notificationPermission = requestGeneratorNotificationPermission();

    setState(() {
      _isLoading = true;
      _statusMessage = 'جارٍ التحقق من بيانات الدخول...';
      _statusIsError = false;
    });

    try {
      final credential =
          await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _accountEmail,
        password: _passwordController.text,
      );
      final idToken = await credential.user?.getIdToken(true);
      if (idToken == null || idToken.isEmpty) {
        await _setFailure('تعذر إنشاء رمز دخول آمن. حاول مرة أخرى.');
        return;
      }

      final request = await createGeneratorAccessRequest(
        requesterName: _allowedUsername,
        idToken: idToken,
        tool: 'المحوّل والمولّد والمحاكي',
      );

      if (request['status'] != 'submitted') {
        await _setFailure(
          request['message']?.toString() ??
              'تعذر إرسال طلب الموافقة إلى البريد.',
        );
        return;
      }

      final requestId = request['requestId']?.toString() ?? '';
      final pollToken = request['pollToken']?.toString() ?? '';
      final expiresAtMillis = _asInt(request['expiresAt']) ??
          DateTime.now()
              .add(const Duration(minutes: 10))
              .millisecondsSinceEpoch;
      final expiresAt =
          DateTime.fromMillisecondsSinceEpoch(expiresAtMillis);
      final requestStartedAt = DateTime.now();

      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _waitingForApproval = true;
        _statusMessage =
            'تم إرسال طلب الموافقة إلى البريد. بانتظار القبول...';
        _statusIsError = false;
      });

      while (mounted &&
          !_cancelPolling &&
          DateTime.now().isBefore(expiresAt)) {
        await Future<void>.delayed(const Duration(seconds: 2));
        if (_cancelPolling || !mounted) return;

        final result = await pollGeneratorAccessRequest(
          requestId: requestId,
          pollToken: pollToken,
        );
        final status = result['status']?.toString() ?? 'error';

        if (status == 'pending') continue;

        // The first poll can arrive before Apps Script finishes writing.
        if (status == 'invalid' &&
            DateTime.now().difference(requestStartedAt) <
                const Duration(seconds: 20)) {
          continue;
        }

        if (status == 'approved') {
          final approvedUntilMillis = _asInt(result['approvedUntil']) ??
              DateTime.now()
                  .add(const Duration(hours: 4))
                  .millisecondsSinceEpoch;
          final approvedUntil =
              DateTime.fromMillisecondsSinceEpoch(approvedUntilMillis);
          saveGeneratorApprovalExpiry(approvedUntil);

          if (await notificationPermission) {
            showGeneratorLoginNotification(
              title: 'تم قبول الدخول',
              body:
                  'تم السماح بالدخول إلى Glass CNC Tools لمدة 4 ساعات.',
            );
          }

          if (!mounted) return;
          widget.onApproved();
          return;
        }

        if (status == 'rejected') {
          await _setFailure('تم رفض طلب الدخول من البريد.');
          return;
        }
        if (status == 'expired') {
          await _setFailure(
            'انتهت مهلة الموافقة. سجّل الدخول وأرسل طلبًا جديدًا.',
          );
          return;
        }
        if (status == 'error') {
          await _setFailure(
            result['message']?.toString() ??
                'تعذر إرسال بريد الموافقة. تحقق من خدمة البريد ثم أعد المحاولة.',
          );
          return;
        }

        await _setFailure(
          'لم تصل حالة موافقة صحيحة. أعد المحاولة بعد التأكد من نشر خدمة الموافقة.',
        );
        return;
      }

      if (!_cancelPolling) {
        await _setFailure(
          'انتهت مهلة طلب الدخول دون موافقة. أرسل طلبًا جديدًا.',
        );
      }
    } on FirebaseAuthException {
      await _setFailure('اسم المستخدم أو كلمة المرور غير صحيحة.');
    } on Object {
      await _setFailure(
        'تعذر إكمال طلب الدخول. تحقق من الاتصال وأعد المحاولة.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final fieldsEnabled = !_isLoading && !_waitingForApproval;

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
                            if (_waitingForApproval)
                              const Padding(
                                padding: EdgeInsets.only(top: 2),
                                child: SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
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
                                  color:
                                      _statusIsError ? Colors.red : null,
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
                            child:
                                CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.login),
                    label: Text(
                      _isLoading
                          ? 'جارٍ تسجيل الدخول...'
                          : _waitingForApproval
                              ? 'بانتظار الموافقة...'
                              : 'تسجيل الدخول',
                    ),
                  ),
                  if (_waitingForApproval) ...[
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _cancelRequest,
                      icon: const Icon(Icons.close),
                      label: const Text('إلغاء الطلب'),
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
