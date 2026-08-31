import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
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

  // Never restore an old browser login into the protected generator. Every
  // reload/new browser session must pass password + fresh owner OTP again.
  if (kIsWeb) {
    await FirebaseAuth.instance.setPersistence(Persistence.NONE);
    await FirebaseAuth.instance.signOut();
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
  bool _approved = false;

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
    if (_approved && FirebaseAuth.instance.currentUser != null) {
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
  final _otpController = TextEditingController();

  bool _isLoading = false;
  bool _otpStep = false;
  bool _obscurePassword = true;
  String? _requestId;
  String? _pollToken;
  DateTime? _otpExpiresAt;
  String? _statusMessage;
  bool _statusIsError = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  int? _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  Future<void> _resetLogin({String? error}) async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _otpStep = false;
      _requestId = null;
      _pollToken = null;
      _otpExpiresAt = null;
      _otpController.clear();
      _statusMessage = error;
      _statusIsError = error != null;
    });
  }

  String _friendlyAuthError(FirebaseAuthException error) {
    switch (error.code) {
      case 'wrong-password':
      case 'invalid-credential':
      case 'user-not-found':
        return 'اسم المستخدم أو كلمة المرور غير صحيحة.';
      case 'too-many-requests':
        return 'محاولات كثيرة خلال وقت قصير. انتظر قليلًا ثم أعد المحاولة.';
      case 'network-request-failed':
        return 'تعذر الاتصال بخدمة تسجيل الدخول.';
      default:
        return 'تعذر التحقق من كلمة المرور.';
    }
  }

  Future<void> _signInAndSendOtp() async {
    if (_isLoading || _otpStep) return;
    if (!_formKey.currentState!.validate()) return;

    final notificationPermission = requestGeneratorNotificationPermission();

    setState(() {
      _isLoading = true;
      _statusMessage = 'جارٍ التحقق من كلمة المرور...';
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
        await _resetLogin(error: 'تعذر إنشاء جلسة تحقق آمنة.');
        return;
      }

      final request = await createGeneratorAccessRequest(
        requesterName: _allowedUsername,
        idToken: idToken,
        tool: 'المحوّل والمولّد والمحاكي',
      );

      if (request['status'] != 'submitted') {
        await _resetLogin(
          error: request['message']?.toString() ??
              'تعذر إرسال كود التحقق إلى البريد.',
        );
        return;
      }

      final requestId = request['requestId']?.toString() ?? '';
      final pollToken = request['pollToken']?.toString() ?? '';
      if (requestId.isEmpty || pollToken.isEmpty) {
        await _resetLogin(error: 'تعذر إنشاء طلب OTP آمن.');
        return;
      }

      final expiresAtMillis = _asInt(request['expiresAt']) ??
          DateTime.now()
              .add(const Duration(minutes: 10))
              .millisecondsSinceEpoch;

      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _otpStep = true;
        _requestId = requestId;
        _pollToken = pollToken;
        _otpExpiresAt =
            DateTime.fromMillisecondsSinceEpoch(expiresAtMillis);
        _statusMessage =
            'تم إرسال كود من 6 أرقام إلى rashedhathalmic@gmail.com.';
        _statusIsError = false;
      });

      if (await notificationPermission) {
        showGeneratorLoginNotification(
          title: 'تم إرسال كود الدخول',
          body: 'راجع بريد المالك لإكمال الدخول إلى Glass CNC Tools.',
        );
      }
    } on FirebaseAuthException catch (error) {
      await _resetLogin(error: _friendlyAuthError(error));
    } on Object {
      await _resetLogin(
        error: 'تعذر إكمال طلب الدخول. تحقق من الاتصال وأعد المحاولة.',
      );
    }
  }

  Future<void> _verifyOtp() async {
    if (_isLoading || !_otpStep) return;

    final otp = _otpController.text.trim();
    if (!RegExp(r'^\d{6}$').hasMatch(otp)) {
      setState(() {
        _statusMessage = 'أدخل الكود المكون من 6 أرقام.';
        _statusIsError = true;
      });
      return;
    }

    if (_otpExpiresAt != null &&
        !DateTime.now().isBefore(_otpExpiresAt!)) {
      await _resetLogin(error: 'انتهت صلاحية الكود. أرسل كودًا جديدًا.');
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    final requestId = _requestId;
    final pollToken = _pollToken;
    if (user == null || requestId == null || pollToken == null) {
      await _resetLogin(error: 'انتهت جلسة كلمة المرور. سجّل الدخول من جديد.');
      return;
    }

    setState(() {
      _isLoading = true;
      _statusMessage = 'جارٍ التحقق من الكود...';
      _statusIsError = false;
    });

    try {
      final idToken = await user.getIdToken(true);
      if (idToken == null || idToken.isEmpty) {
        await _resetLogin(error: 'تعذر تحديث جلسة التحقق.');
        return;
      }

      final result = await verifyGeneratorAccessOtp(
        requestId: requestId,
        pollToken: pollToken,
        otp: otp,
        idToken: idToken,
      );
      final status = result['status']?.toString() ?? 'error';

      if (status == 'approved') {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _statusMessage = 'تم التحقق. جارٍ فتح المولد...';
          _statusIsError = false;
        });
        showGeneratorLoginNotification(
          title: 'تم قبول الدخول',
          body: 'تم التحقق من كلمة المرور وكود البريد بنجاح.',
        );
        widget.onApproved();
        return;
      }

      if (status == 'invalid_otp') {
        final remaining = result['attemptsRemaining'];
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _otpController.clear();
          _statusMessage = remaining == null
              ? 'الكود غير صحيح.'
              : 'الكود غير صحيح. المحاولات المتبقية: $remaining';
          _statusIsError = true;
        });
        return;
      }

      if (status == 'expired') {
        await _resetLogin(error: 'انتهت صلاحية الكود. أرسل كودًا جديدًا.');
        return;
      }
      if (status == 'locked') {
        await _resetLogin(
          error: 'تم إيقاف الطلب بسبب كثرة محاولات الكود الخاطئة.',
        );
        return;
      }
      if (status == 'unauthorized') {
        await _resetLogin(error: 'تم رفض جلسة الدخول من الخادم.');
        return;
      }

      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _statusMessage = result['message']?.toString() ??
            'تعذر التحقق من الكود. حاول مرة أخرى.';
        _statusIsError = true;
      });
    } on Object {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _statusMessage = 'تعذر الاتصال بخدمة OTP.';
        _statusIsError = true;
      });
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
                  if (!_otpStep) ...[
                    TextFormField(
                      controller: _usernameController,
                      enabled: !_isLoading,
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
                      enabled: !_isLoading,
                      obscureText: _obscurePassword,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _signInAndSendOtp(),
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          onPressed: _isLoading
                              ? null
                              : () => setState(
                                    () => _obscurePassword =
                                        !_obscurePassword,
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
                  ] else ...[
                    Text(
                      'أدخل كود التحقق المرسل إلى بريد المالك',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _otpController,
                      enabled: !_isLoading,
                      autofocus: true,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _verifyOtp(),
                      maxLength: 6,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 8,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'OTP',
                        hintText: '000000',
                        prefixIcon: Icon(Icons.mark_email_read_outlined),
                        counterText: '',
                      ),
                    ),
                  ],
                  if (_statusMessage != null) ...[
                    const SizedBox(height: 18),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (_isLoading)
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
                  if (!_otpStep)
                    FilledButton.icon(
                      onPressed: _isLoading ? null : _signInAndSendOtp,
                      icon: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.login),
                      label: Text(
                        _isLoading ? 'جارٍ التحقق...' : 'تسجيل الدخول وإرسال الكود',
                      ),
                    )
                  else ...[
                    FilledButton.icon(
                      onPressed: _isLoading ? null : _verifyOtp,
                      icon: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.verified_user_outlined),
                      label: Text(_isLoading ? 'جارٍ التحقق...' : 'تحقق وافتح المولد'),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: _isLoading ? null : () => _resetLogin(),
                      icon: const Icon(Icons.refresh),
                      label: const Text('إرسال كود جديد'),
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
