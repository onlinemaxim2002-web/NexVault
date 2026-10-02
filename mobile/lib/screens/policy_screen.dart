import 'package:flutter/material.dart';

import '../config.dart';

// Placeholder policy texts. Replace with the final, reviewed versions before
// a public release.
const policies = {
  'privacy': (
    'Privacy Policy',
    'We collect the information needed to run ${Config.appName}: your account details (email when you '
        'create an account), the files you store, channels you join or create, content you view, and a random '
        'install ID used to understand how the app was installed. We do not collect advertising IDs.\n\n'
        'Your files are private to your account. Content you post to a channel is visible to that channel\'s '
        'audience once the channel is approved.\n\n'
        'You can delete your account at any time from Settings → Delete account; this removes your profile, '
        'files and channel memberships.\n\nContact: support (to be added).',
  ),
  'terms': (
    'Terms & Conditions',
    'By using ${Config.appName} you agree to use it lawfully and to upload only content you have the right to share. '
        'Channels you create are reviewed before they become visible. We may remove content or accounts that '
        'break these terms or our Community Guidelines.\n\nPremium plans give access to premium content, '
        'more storage and faster transfers for the plan period.\n\nThe service is provided as is.',
  ),
  'community': (
    'Community Guidelines',
    'Be respectful. Do not post illegal, hateful, sexual or violent content, spam, or content that '
        'infringes others\' rights. Report anything that breaks these rules. Breaking them can lead to removal '
        'of posts, channels or your account.',
  ),
  'refund': (
    'Refund Policy',
    'Plans are activated for the period shown on the Premium page. Refund requests are handled case by case; '
        'contact support with your account email and plan details.',
  ),
};

class PolicyScreen extends StatelessWidget {
  final String policyKey;
  const PolicyScreen({super.key, required this.policyKey});

  @override
  Widget build(BuildContext context) {
    final (title, body) = policies[policyKey]!;
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(body, style: const TextStyle(fontSize: 16, height: 1.5)),
        ],
      ),
    );
  }
}
