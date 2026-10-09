import 'package:flutter/material.dart';

import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'profile_screen.dart';

/// NexVault is free for everyone. This screen explains the included 15 GB quota.
class PremiumScreen extends StatefulWidget {
  final bool standalone;
  const PremiumScreen({super.key, this.standalone = false});

  @override
  State<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends State<PremiumScreen> {
  @override
  void initState() {
    super.initState();
    app.refreshStatus();
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
        title: const Text('Free Cloud Storage'),
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
          const defaultQuota = 15 * 1024 * 1024 * 1024;
          final quota = status.quotaBytes > 0 ? status.quotaBytes : defaultQuota;
          final used = status.usedBytes;
          final fraction = (used / quota).clamp(0.0, 1.0).toDouble();
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: AppColors.gradient,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x40FF7A1A),
                      blurRadius: 24,
                      offset: Offset(0, 10),
                    ),
                  ],
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.cloud_done_rounded, size: 44, color: Colors.white),
                    SizedBox(height: 18),
                    Text(
                      '15 GB Free Cloud Storage',
                      style: TextStyle(
                        fontSize: 25,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Your storage is included at no cost. No plans, subscriptions, or in-app payments.',
                      style: TextStyle(fontSize: 15, color: Colors.white),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Your storage',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${formatBytes(used)} used of ${formatBytes(quota)}',
                        style: const TextStyle(fontSize: 15, color: AppColors.muted),
                      ),
                      const SizedBox(height: 14),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: fraction,
                          minHeight: 9,
                          color: AppColors.primary,
                          backgroundColor: AppColors.surfaceHigh,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text('${(fraction * 100).round()}% used'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const _FeatureTile(
                icon: Icons.folder_open_rounded,
                title: 'Your files and folders',
                subtitle: 'Upload, preview, organise, rename, and delete your files.',
              ),
              const _FeatureTile(
                icon: Icons.download_rounded,
                title: 'Downloads included',
                subtitle: 'Save your own cloud files to your device without a subscription.',
              ),
              const _FeatureTile(
                icon: Icons.play_circle_outline_rounded,
                title: 'All app features are free',
                subtitle: 'No paid plans or in-app purchases are offered in NexVault.',
              ),
            ],
          );
        },
      ),
    );
  }
}

class _FeatureTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _FeatureTile({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon, color: AppColors.primary, size: 28),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(subtitle),
      ),
    );
  }
}
