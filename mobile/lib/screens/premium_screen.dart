import 'package:flutter/material.dart';

import '../state/app_state.dart';
import '../theme.dart';
import 'login_screen.dart';
import 'profile_screen.dart';

/// Account entry point: no premium plans or subscriptions are offered.
class PremiumScreen extends StatefulWidget {
  final bool standalone;
  const PremiumScreen({super.key, this.standalone = false});

  @override
  State<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends State<PremiumScreen> {
  bool _openingLogin = false;

  @override
  void initState() {
    super.initState();
    app.refreshStatus();
  }

  Future<void> _login() async {
    if (_openingLogin) return;
    setState(() => _openingLogin = true);
    try {
      await Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
      await app.refreshStatus();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open login: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _openingLogin = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        flexibleSpace: const DecoratedBox(
          decoration: BoxDecoration(gradient: AppColors.barGradient),
          child: SizedBox.expand(),
        ),
        automaticallyImplyLeading: widget.standalone,
        title: const Text('Account'),
        actions: [
          IconButton(
            icon: const Icon(Icons.account_circle_outlined, size: 32),
            tooltip: 'Profile',
            onPressed: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const ProfileScreen())),
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: app,
        builder: (context, _) {
          final status = app.status;
          if (status == null) {
            return const Center(child: CircularProgressIndicator());
          }
          final isGuest = status.isGuest;
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceHigh,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Icon(
                        isGuest ? Icons.person_add_alt_1_rounded : Icons.verified_user_rounded,
                        color: AppColors.primary,
                        size: 34,
                      ),
                    ),
                    const SizedBox(height: 22),
                    Text(
                      isGuest ? 'Log in to NexVault' : 'You’re signed in',
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      isGuest
                          ? 'Create an account or log in to keep your account connected across devices and make it easier to access your files.'
                          : 'Your NexVault account is connected. You can manage your profile and continue using your free cloud storage.',
                      style: const TextStyle(
                        fontSize: 15,
                        height: 1.5,
                        color: AppColors.muted,
                      ),
                    ),
                    const SizedBox(height: 24),
                    if (isGuest)
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _openingLogin ? null : _login,
                          icon: _openingLogin
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.login_rounded),
                          label: Text(
                            _openingLogin ? 'Opening login…' : 'Log in / Create account',
                          ),
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(54),
                          ),
                        ),
                      )
                    else
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const ProfileScreen()),
                          ),
                          icon: const Icon(Icons.person_outline_rounded),
                          label: const Text('Manage account'),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(54),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.cloud_done_rounded, color: AppColors.primary, size: 30),
                  title: const Text(
                    '15 GB free cloud storage',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: const Text(
                    'Included for every account. No paid plans, subscriptions, or in-app payments.',
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.security_rounded, color: AppColors.primary, size: 30),
                  title: const Text(
                    'Your account, your files',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: const Text(
                    'Sign in to keep your account details connected when you change devices.',
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
