import 'package:flutter/material.dart';

import '../models.dart';
import '../services/backend.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/gates.dart';
import '../widgets/reload.dart';
import 'profile_screen.dart';

/// Premium plans. Also the Profile tab; the person icon opens the profile.
class PremiumScreen extends StatefulWidget {
  final bool standalone;
  const PremiumScreen({super.key, this.standalone = false});

  @override
  State<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends State<PremiumScreen> with ContentReload {
  List<Plan>? plans;
  String? selected;
  String? error;
  bool sending = false;

  @override
  Future<void> reload() async {
    try {
      final list = await Backend.plans();
      await app.refreshStatus();
      if (!mounted) return;
      setState(() {
        plans = list;
        selected ??= list.isEmpty ? null : list.first.id;
        error = null;
      });
    } catch (e) {
      if (mounted) setState(() => error = friendlyError(e));
    }
  }

  Future<void> _next() async {
    final plan = plans?.firstWhere((p) => p.id == selected);
    if (plan == null) return;
    if (!await ensureLoggedIn(context, reason: 'Log in to get ${plan.name}')) return;
    setState(() => sending = true);
    try {
      // Payments aren't connected yet: send a request that the owner grants.
      await Backend.requestPlan(plan.id);
      await app.refreshStatus();
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Request sent'),
          content: Text('Thanks! Your ${plan.name} request has been sent. Your plan will be activated shortly.'),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
        ),
      );
    } catch (e) {
      if (mounted) showSnack(context, friendlyError(e));
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: widget.standalone,
        title: const Text('Premium'),
        actions: [
          IconButton(
            icon: const Icon(Icons.account_circle_outlined, size: 32),
            tooltip: 'Profile',
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ProfileScreen())),
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: app,
        builder: (context, _) {
          if (error != null && plans == null) return ErrorRetry(message: error!, onRetry: reload);
          if (plans == null) return const Center(child: CircularProgressIndicator());
          final s = app.status;
          final perks = plans!.isNotEmpty && plans!.first.perks.isNotEmpty
              ? plans!.first.perks
              : const ['Ad-Free Experience', 'Access 2 TB Cloud Storage', 'Fast Upload & Download Speed'];
          return ListView(padding: const EdgeInsets.all(16), children: [
            if (s?.isPremium == true)
              _Banner(
                color: const Color(0xFFE8F5E9),
                icon: Icons.verified,
                text: 'You have ${s!.planName}${s.planEndsAt != null ? ' until ${s.planEndsAt!.toLocal().toString().substring(0, 10)}' : ''}.',
              )
            else if (s?.openRequest != null)
              _Banner(
                color: const Color(0xFFFFF8E1),
                icon: Icons.hourglass_top,
                text: 'Your ${s!.openRequest} request is being processed.',
              ),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFFBE0DE),
                borderRadius: BorderRadius.circular(16),
                border: const Border(top: BorderSide(color: AppColors.primary, width: 6)),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(8)),
                  child: const Text('Premium', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
                ),
                const SizedBox(height: 12),
                for (final perk in perks)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(children: [
                      const Icon(Icons.check, color: AppColors.primary, size: 26),
                      const SizedBox(width: 10),
                      Expanded(child: Text(perk, style: const TextStyle(fontSize: 16))),
                    ]),
                  ),
              ]),
            ),
            const SizedBox(height: 16),
            RadioGroup<String>(
              groupValue: selected,
              onChanged: (v) => setState(() => selected = v),
              child: Column(children: [for (final p in plans!) _PlanCard(plan: p, selected: p.id == selected, onTap: () => setState(() => selected = p.id))]),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: sending || selected == null || s?.openRequest != null ? null : _next,
              child: Text(sending ? 'Sending…' : 'Next'),
            ),
          ]);
        },
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  final Plan plan;
  final bool selected;
  final VoidCallback onTap;
  const _PlanCard({required this.plan, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: selected ? AppColors.primary : const Color(0xFFBDBDBD), width: 2),
          ),
          child: Row(children: [
            Radio<String>(value: plan.id, activeColor: AppColors.primary),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(plan.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                Text(plan.durationLabel, style: const TextStyle(fontSize: 15)),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Text('₹ ${plan.priceInr}', style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
            ),
          ]),
        ),
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String text;
  const _Banner({required this.color, required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)),
      child: Row(children: [Icon(icon), const SizedBox(width: 10), Expanded(child: Text(text, style: const TextStyle(fontSize: 15)))]),
    );
  }
}
