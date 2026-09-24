import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

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
    _password.addListener(() => setState(() {}));
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
    FocusScope.of(context).unfocus();
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

  int get _strength {
    final p = _password.text;
    if (p.isEmpty) return 0;
    if (p.length < 8) return 1;
    return RegExp(r'[^a-zA-Z]').hasMatch(p) ? 3 : 2;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Ambient glows (same as the website's auth page)
          const Positioned(top: -140, left: -120, child: _Glow(color: AppColors.primary, size: 360, opacity: 0.35)),
          const Positioned(bottom: -160, right: -140, child: _Glow(color: AppColors.success, size: 340, opacity: 0.18)),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: AutofillGroup(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _hero(),
                        const SizedBox(height: 22),
                        _card(),
                        const SizedBox(height: 14),
                        Center(
                          child: TextButton.icon(
                            onPressed:
                                () => launchUrl(Uri.parse(privacyPolicyUrl), mode: LaunchMode.externalApplication),
                            icon: const Icon(LucideIcons.shieldCheck, size: 14, color: AppColors.textMuted),
                            label: const Text(
                              'Privacy policy',
                              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _hero() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              gradient: AppGradients.primary,
              borderRadius: BorderRadius.circular(11),
              boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.45), blurRadius: 18)],
            ),
            child: const Icon(LucideIcons.target, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 10),
          const Text('Focus System', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        ],
      ),
      const SizedBox(height: 20),
      const Text('Plan today.', style: TextStyle(fontSize: 30, height: 1.1, fontWeight: FontWeight.w900)),
      ShaderMask(
        shaderCallback: (r) => AppGradients.primary.createShader(r),
        child: const Text(
          'Do one thing at a time.',
          style: TextStyle(fontSize: 30, height: 1.15, fontWeight: FontWeight.w900, color: Colors.white),
        ),
      ),
      const SizedBox(height: 10),
      const Text(
        'Tasks, a focus timer with real breaks, reminders and streaks — synced with the website.',
        style: TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.4),
      ),
      const SizedBox(height: 14),
      const Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _FeatureChip(icon: LucideIcons.sun, label: 'Plan'),
          _FeatureChip(icon: LucideIcons.timer, label: 'Focus'),
          _FeatureChip(icon: LucideIcons.coffee, label: 'Breaks'),
          _FeatureChip(icon: LucideIcons.flame, label: 'Streaks'),
        ],
      ),
    ],
  );

  Widget _card() => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: AppColors.surface.withValues(alpha: 0.92),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: AppColors.border),
      boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 40, offset: Offset(0, 20))],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _tabs(),
        const SizedBox(height: 18),
        Text(
          _register ? 'Start focusing today' : 'Welcome back 👋',
          style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        Text(
          _register ? 'Free account · syncs the website and the app.' : 'Sign in to pick up where you left off.',
          style: AppText.muted,
        ),
        const SizedBox(height: 16),
        if (_error != null) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.dangerBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(LucideIcons.circleAlert, size: 16, color: AppColors.danger),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _error!,
                    style: const TextStyle(color: AppColors.danger, fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
        ],
        if (_register) ...[
          _field(
            label: 'Name',
            icon: LucideIcons.user,
            controller: _name,
            hint: 'Your name',
            caps: TextCapitalization.words,
            autofill: const [AutofillHints.name],
          ),
          const SizedBox(height: 12),
        ],
        _field(
          label: 'Email',
          icon: LucideIcons.mail,
          controller: _email,
          hint: 'you@example.com',
          keyboard: TextInputType.emailAddress,
          autofill: const [AutofillHints.email],
        ),
        const SizedBox(height: 12),
        _field(
          label: 'Password',
          icon: LucideIcons.lock,
          controller: _password,
          hint: _register ? 'At least 8 characters' : 'Your password',
          obscure: !_showPassword,
          autofill: [_register ? AutofillHints.newPassword : AutofillHints.password],
          onSubmitted: (_) => _submit(),
          suffix: IconBtn(
            _showPassword ? LucideIcons.eyeOff : LucideIcons.eye,
            size: 16,
            onPressed: () => setState(() => _showPassword = !_showPassword),
          ),
        ),
        if (_register) ...[const SizedBox(height: 8), _strengthBar()],
        const SizedBox(height: 18),
        Btn(
          label: _register ? 'Create account' : 'Sign in',
          icon: _busy ? null : LucideIcons.arrowRight,
          expand: true,
          busy: _busy,
          large: true,
          onPressed: _submit,
        ),
        const SizedBox(height: 14),
        _serverSection(),
      ],
    ),
  );

  Widget _tabs() => Container(
    padding: const EdgeInsets.all(4),
    decoration: BoxDecoration(
      color: AppColors.surface2,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.border),
    ),
    child: Row(
      children: [
        for (final (register, label) in const [(false, 'Sign in'), (true, 'Create account')])
          Expanded(
            child: Semantics(
              container: true,
              button: true,
              selected: _register == register,
              label: label,
              excludeSemantics: true,
              child: GestureDetector(
                onTap:
                    () => setState(() {
                      _register = register;
                      _error = null;
                    }),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _register == register ? AppColors.surface3 : Colors.transparent,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _register == register ? AppColors.text : AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );

  Widget _field({
    required String label,
    required IconData icon,
    required TextEditingController controller,
    String? hint,
    bool obscure = false,
    TextInputType? keyboard,
    TextCapitalization caps = TextCapitalization.none,
    Iterable<String>? autofill,
    ValueChanged<String>? onSubmitted,
    Widget? suffix,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      FieldLabel(label),
      TextField(
        controller: controller,
        obscureText: obscure,
        keyboardType: keyboard,
        textCapitalization: caps,
        autocorrect: false,
        autofillHints: autofill,
        onSubmitted: onSubmitted,
        style: const TextStyle(fontSize: 14),
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: Icon(icon, size: 17, color: AppColors.textMuted),
          suffixIcon: suffix,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
          border: _inputBorder(AppColors.border),
          enabledBorder: _inputBorder(AppColors.border),
          focusedBorder: _inputBorder(AppColors.primary),
        ),
      ),
    ],
  );

  static OutlineInputBorder _inputBorder(Color c) =>
      OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: c));

  Widget _strengthBar() {
    final colors = [AppColors.surface3, AppColors.danger, AppColors.warning, AppColors.success];
    final label = ['', 'Too short', 'Good', 'Strong'][_strength];
    return Row(
      children: [
        for (var i = 1; i <= 3; i++) ...[
          Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 3,
              decoration: BoxDecoration(
                color: _strength >= i ? colors[_strength] : AppColors.surface3,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          if (i < 3) const SizedBox(width: 4),
        ],
        SizedBox(
          width: 64,
          child: Text(
            label,
            textAlign: TextAlign.right,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textMuted),
          ),
        ),
      ],
    );
  }

  Widget _serverSection() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => setState(() => _showServer = !_showServer),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              const Icon(LucideIcons.server, size: 13, color: AppColors.textMuted),
              const SizedBox(width: 6),
              const Expanded(child: Kicker('Server')),
              Icon(
                _showServer ? LucideIcons.chevronDown : LucideIcons.chevronRight,
                size: 15,
                color: AppColors.textMuted,
              ),
            ],
          ),
        ),
      ),
      if (_showServer) ...[
        const SizedBox(height: 8),
        TextField(
          controller: _server,
          keyboardType: TextInputType.url,
          autocorrect: false,
          style: const TextStyle(fontSize: 13),
          decoration: const InputDecoration(hintText: defaultApiUrl),
        ),
        const SizedBox(height: 6),
        const Text(
          'Leave the default to use the Focus System cloud. For a self-hosted backend enter its address.',
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
  );
}

class _Glow extends StatelessWidget {
  const _Glow({required this.color, required this.size, required this.opacity});
  final Color color;
  final double size;
  final double opacity;
  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [color.withValues(alpha: opacity), color.withValues(alpha: 0)]),
      ),
    ),
  );
}

class _FeatureChip extends StatelessWidget {
  const _FeatureChip({required this.icon, required this.label});
  final IconData icon;
  final String label;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: AppColors.primaryBg,
      borderRadius: BorderRadius.circular(99),
      border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: AppColors.primaryHover),
        const SizedBox(width: 5),
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primaryHover)),
      ],
    ),
  );
}
