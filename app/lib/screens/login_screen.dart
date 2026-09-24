import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../api.dart';
import '../app_state.dart';
import '../theme.dart';
import '../widgets/ui.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _register = false;
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _server = TextEditingController();
  bool _showPassword = false;
  bool _showServer = false;
  bool _busy = false;
  String? _error;
  String? _serverStatus;

  @override
  void initState() {
    super.initState();
    Session.baseUrl().then((u) {
      if (mounted) _server.text = u;
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _server.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final s = context.read<AppState>();
    setState(() {
      _busy = true;
      _error = null;
    });
    final err = await s.authenticate(
      serverUrl: _server.text,
      email: _email.text.trim(),
      password: _password.text,
      name: _register ? _name.text.trim() : null,
    );
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = err;
      if (err != null && err.contains('reach the server')) _showServer = true;
    });
  }

  Future<void> _testServer() async {
    setState(() => _serverStatus = 'Checking…');
    try {
      final res = await Api(baseUrl: Session.normalizeUrl(_server.text)).get('/api/health');
      setState(() => _serverStatus = res['app'] == 'focus-system' ? '✓ Connected' : 'Not a Focus System server');
    } on ApiException catch (e) {
      setState(() => _serverStatus = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Panel(
                padding: const EdgeInsets.all(24),
                child: AutofillGroup(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Row(
                        children: [
                          Icon(LucideIcons.target, color: AppColors.primary, size: 24),
                          SizedBox(width: 10),
                          Text('Focus System', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Text(
                        _register ? 'Create your account' : 'Welcome back',
                        style: AppText.h1.copyWith(fontSize: 22),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _register
                            ? 'One account for the website and the mobile app.'
                            : 'Sign in to plan today and do one thing at a time.',
                        style: AppText.muted,
                      ),
                      const SizedBox(height: 18),
                      if (_error != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.dangerBg,
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                          ),
                          child: Row(
                            children: [
                              const Icon(LucideIcons.circleAlert, size: 16, color: AppColors.danger),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _error!,
                                  style: const TextStyle(
                                    color: AppColors.danger,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],
                      if (_register) ...[
                        const FieldLabel('Name'),
                        TextField(
                          controller: _name,
                          textCapitalization: TextCapitalization.words,
                          autofillHints: const [AutofillHints.name],
                        ),
                        const SizedBox(height: 14),
                      ],
                      const FieldLabel('Email'),
                      TextField(
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        autocorrect: false,
                        autofillHints: const [AutofillHints.email],
                      ),
                      const SizedBox(height: 14),
                      const FieldLabel('Password'),
                      TextField(
                        controller: _password,
                        obscureText: !_showPassword,
                        autofillHints: [_register ? AutofillHints.newPassword : AutofillHints.password],
                        onSubmitted: (_) => _submit(),
                        decoration: InputDecoration(
                          suffixIcon: IconBtn(
                            _showPassword ? LucideIcons.eyeOff : LucideIcons.eye,
                            onPressed: () => setState(() => _showPassword = !_showPassword),
                          ),
                        ),
                      ),
                      if (_register)
                        const Padding(
                          padding: EdgeInsets.only(top: 5),
                          child: Text(
                            'At least 8 characters.',
                            style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                          ),
                        ),
                      const SizedBox(height: 18),
                      Btn(
                        label: _register ? 'Create account' : 'Sign in',
                        expand: true,
                        busy: _busy,
                        onPressed: _submit,
                      ),
                      const SizedBox(height: 14),
                      Center(
                        child: TextButton(
                          onPressed:
                              () => setState(() {
                                _register = !_register;
                                _error = null;
                              }),
                          child: Text.rich(
                            TextSpan(
                              text: _register ? 'Already have an account? ' : 'New here? ',
                              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                              children: [
                                TextSpan(
                                  text: _register ? 'Sign in' : 'Create an account',
                                  style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const Divider(height: 24),
                      InkWell(
                        onTap: () => setState(() => _showServer = !_showServer),
                        child: Row(
                          children: [
                            const Icon(LucideIcons.server, size: 14, color: AppColors.textMuted),
                            const SizedBox(width: 6),
                            const Expanded(child: Kicker('Server')),
                            Icon(
                              _showServer ? LucideIcons.chevronDown : LucideIcons.chevronRight,
                              size: 16,
                              color: AppColors.textMuted,
                            ),
                          ],
                        ),
                      ),
                      if (_showServer) ...[
                        const SizedBox(height: 10),
                        TextField(
                          controller: _server,
                          keyboardType: TextInputType.url,
                          autocorrect: false,
                          style: const TextStyle(fontSize: 13),
                          decoration: const InputDecoration(hintText: 'http://192.168.1.20:4000'),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'The address of the Focus System backend (port 4000). Emulator: http://10.0.2.2:4000 · '
                          "Phone: your computer's network IP.",
                          style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Btn(label: 'Test connection', kind: BtnKind.secondary, small: true, onPressed: _testServer),
                            const SizedBox(width: 10),
                            if (_serverStatus != null)
                              Expanded(
                                child: Text(
                                  _serverStatus!,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: _serverStatus!.startsWith('✓') ? AppColors.success : AppColors.textSecondary,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
