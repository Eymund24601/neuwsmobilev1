import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../app/app_routes.dart';
import '../services/supabase/supabase_bootstrap.dart';
import '../theme/app_theme.dart';

class SignInPage extends StatefulWidget {
  const SignInPage({super.key});

  @override
  State<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isSignUpMode = false;
  bool _submitting = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (email.isEmpty || password.isEmpty) {
      _showMessage('Email and password are required.');
      return;
    }

    setState(() => _submitting = true);
    try {
      if (_isSignUpMode) {
        final response = await Supabase.instance.client.auth.signUp(
          email: email,
          password: password,
        );
        if (!mounted) {
          return;
        }
        final hasSession = response.session != null;
        _showMessage(
          hasSession
              ? 'Account created and signed in.'
              : 'Account created. Check your email to confirm sign in.',
        );
        if (hasSession) {
          await _ensureProfileRow();
          _goAfterAuth();
        }
      } else {
        await Supabase.instance.client.auth.signInWithPassword(
          email: email,
          password: password,
        );
        await _ensureProfileRow();
        if (!mounted) {
          return;
        }
        _showMessage('Signed in successfully.');
        _goAfterAuth();
      }
    } on AuthException catch (error) {
      _showMessage(error.message);
    } catch (error) {
      _showMessage('Authentication failed: $error');
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  void _showMessage(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _ensureProfileRow() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      return;
    }

    final email = user.email?.trim() ?? '';
    final existing = await Supabase.instance.client
        .from('profiles')
        .select('id,email')
        .eq('id', user.id)
        .maybeSingle();
    if (existing is Map<String, dynamic>) {
      // Profile already exists: do not overwrite user-edited username/display_name.
      final existingEmailRaw = existing['email'];
      final existingEmail = existingEmailRaw is String
          ? existingEmailRaw.trim()
          : '';
      if (existingEmail.isEmpty && email.isNotEmpty) {
        try {
          await Supabase.instance.client
              .from('profiles')
              .update({'email': email}).eq('id', user.id);
        } catch (_) {
          // Keep sign-in resilient even when profile schema differs.
        }
      }
      return;
    }

    final base = email.contains('@')
        ? email.split('@').first
        : 'user${user.id.substring(0, 6)}';
    final safeBase = base.toLowerCase().replaceAll(RegExp(r'[^a-z0-9_]'), '');
    final username =
        '${safeBase.isEmpty ? 'user' : safeBase}_${user.id.substring(0, 6)}';
    final nowIso = DateTime.now().toIso8601String();

    final attempts = <Map<String, dynamic>>[
      {
        'id': user.id,
        'email': email,
        'username': username,
        'display_name': safeBase.isEmpty ? 'nEUws User' : safeBase,
        'created_at': nowIso,
      },
      {
        'id': user.id,
        'username': username,
        'display_name': safeBase.isEmpty ? 'nEUws User' : safeBase,
        'created_at': nowIso,
      },
      {'id': user.id},
    ];

    for (final payload in attempts) {
      try {
        await Supabase.instance.client.from('profiles').insert(payload);
        return;
      } catch (_) {
        // Try the next payload shape for schema-compat across environments.
      }
    }
    if (!mounted) {
      return;
    }
    _showMessage(
      'Signed in, but profile setup is incomplete. Some user actions may fail until profile row exists.',
    );
  }

  void _goAfterAuth() {
    if (!mounted) {
      return;
    }
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.goNamed(AppRouteName.home);
  }

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<NeuwsPalette>()!;
    final isConfigured = SupabaseBootstrap.isConfigured;

    return Scaffold(
      appBar: AppBar(title: const Text('Sign In')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        children: [
          Text(
            'nEUws account',
            style: Theme.of(
              context,
            ).textTheme.displaySmall?.copyWith(fontSize: 36),
          ),
          const SizedBox(height: 8),
          Text(
            'Sign in to test messages, saved stories, perks, profile, and creator tools.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: palette.muted),
          ),
          const SizedBox(height: 20),
          if (!isConfigured)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: palette.surfaceCard,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: palette.border),
              ),
              child: Text(
                'Supabase is not configured for this build. Run with --dart-define-from-file=.env/supabase.local.json',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: palette.muted),
              ),
            ),
          const SizedBox(height: 14),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment<bool>(value: false, label: Text('Sign In')),
              ButtonSegment<bool>(value: true, label: Text('Create Account')),
            ],
            selected: {_isSignUpMode},
            onSelectionChanged: (selection) {
              setState(() => _isSignUpMode = selection.first);
            },
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Email',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _passwordController,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Password',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: (!isConfigured || _submitting) ? null : _submit,
            child: Text(
              _submitting
                  ? 'Please wait...'
                  : (_isSignUpMode ? 'Create Account' : 'Sign In'),
            ),
          ),
        ],
      ),
    );
  }
}
