import 'package:flutter/material.dart';

import '../services/backend.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Create an account (keeps the current guest data) or log in to an existing one.
class LoginScreen extends StatefulWidget {
  final String? reason;
  const LoginScreen({super.key, this.reason});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _create = true;
  bool _busy = false;
  bool _showPassword = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      final email = _email.text.trim();
      if (_create) {
        final done = await app.createAccount(email, _password.text);
        if (!done) {
          if (!mounted) return;
          await showDialog<void>(
            context: context,
            builder: (_) => AlertDialog(
              title: const Text('Confirm your email'),
              content: Text('We sent a confirmation link to $email. Open it, then come back and log in.'),
              actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
            ),
          );
          setState(() => _create = false);
          return;
        }
      } else {
        await app.logIn(email, _password.text);
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      final msg = friendlyError(e);
      if (mounted) {
        showSnack(context, msg.contains('already') ? 'This email already has an account. Log in instead.' : msg);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_create ? 'Create account' : 'Log in')),
      body: Form(
        key: _form,
        child: ListView(padding: const EdgeInsets.all(24), children: [
          const Icon(Icons.cloud_upload, size: 72, color: AppColors.primary),
          const SizedBox(height: 12),
          Text(
            widget.reason ?? (_create ? 'Create an account to continue' : 'Welcome back'),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 24),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: true, label: Text('Create account')),
              ButtonSegment(value: false, label: Text('Log in')),
            ],
            selected: {_create},
            onSelectionChanged: (s) => setState(() => _create = s.first),
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email_outlined)),
            validator: (v) => (v == null || !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v.trim())) ? 'Enter a valid email' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _password,
            obscureText: !_showPassword,
            autofillHints: [_create ? AutofillHints.newPassword : AutofillHints.password],
            decoration: InputDecoration(
              labelText: 'Password',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(_showPassword ? Icons.visibility_off : Icons.visibility),
                onPressed: () => setState(() => _showPassword = !_showPassword),
              ),
            ),
            validator: (v) => (v == null || v.length < 6) ? 'At least 6 characters' : null,
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _busy ? null : _submit,
            child: _busy
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : Text(_create ? 'Create account' : 'Log in'),
          ),
          if (_create) ...[
            const SizedBox(height: 12),
            const Text(
              'Your channels and settings from this device are kept.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.muted),
            ),
          ],
        ]),
      ),
    );
  }
}
