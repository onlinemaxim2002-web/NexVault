import 'package:flutter/material.dart';

import '../config.dart';
import '../theme.dart';

// Policy texts shown in the app (login screen, Settings). When they change,
// bump Config.policyVersion so users are asked to agree again.
const policies = {
  'privacy': (
    'Privacy Policy',
    '${Config.appName} ("we") respects your privacy. This policy explains what we collect and why.\n\n'
        'What we collect\n'
        '• Account: your email address and display name when you create an account. Before that you use the '
        'app as a guest with an anonymous account.\n'
        '• Your content: files you store in your cloud, channels you create or join, and posts you upload.\n'
        '• Usage: what you watch or open in the app, and a random install ID that tells us how the app was '
        'installed (for example from an ad). We do not collect your advertising ID, contacts or location.\n\n'
        'How we use it\n'
        'To run the app, keep your files private to you, show channel content to the right audience, activate '
        'your plan, prevent fraud, and improve the app.\n\n'
        'Advertising measurement (Meta)\n'
        'We run ads on Meta (Facebook / Instagram). To measure them, we send Meta events such as app install, '
        'registration, content view, checkout and purchase (plan name and price), together with a scrambled '
        '(hashed) version of your email and user ID. Meta uses this to match events to its users; it does not '
        'receive your files or the content you watch.\n\n'
        'Sharing\n'
        'We do not sell your data. Besides Meta (above) we use service providers to host the app and store '
        'files (Supabase). Content you post in a channel is visible to that channel\'s audience once approved.\n\n'
        'Your choices\n'
        'You can change your name in your profile and delete your account at any time from Settings → Delete '
        'account. This removes your profile, files and channel memberships.\n\n'
        'Children\n'
        'You must be 18 or older, or use ${Config.appName} with a parent\'s or guardian\'s consent.\n\n'
        'Contact\n'
        'Questions or requests about your data: ${Config.supportEmail}. You can also request account deletion '
        'by emailing ${Config.supportEmail}.',
  ),
  'terms': (
    'Terms & Conditions',
    'By using ${Config.appName} you agree to these terms.\n\n'
        '• Use the app lawfully. Upload only content you own or have the right to share.\n'
        '• Channels you create are reviewed before they become visible. You are responsible for what you post. '
        'We may hide or remove content, channels or accounts that break these terms or our Community Guidelines.\n'
        '• This free build does not offer in-app purchases or collect payments. Premium access, where available, '
        'is controlled by the service and is not purchased inside this app.\n'
        '• Keep your login details private. You are responsible for activity on your account.\n'
        '• The service is provided as is. We may change features or these terms; we will ask you to agree again '
        'when the terms change.\n'
        '• Contact: ${Config.supportEmail}',
  ),
  'community': (
    'Community Guidelines',
    'Keep ${Config.appName} safe and respectful.\n\n'
        '• No illegal content, sexual content involving minors, hate speech, harassment, violence, scams or spam.\n'
        '• No content that copies others\' work without permission (movies, music, shows you don\'t own).\n'
        '• No misleading titles, thumbnails or trailers.\n\n'
        'All channels are reviewed before they go live, and we may remove posts, channels or accounts that break '
        'these rules.\n\n'
        'Copyright complaints (DMCA)\n'
        'If your work was posted without permission, report it at ${Config.website}/report-content or email '
        '${Config.supportEmail} with a link to the content and proof that you own it. We remove infringing content '
        'promptly and may close repeat infringers\' accounts.',
  ),
  'refund': (
    'Refund Policy',
    '${Config.appName} is distributed as a free app and this build does not process in-app purchases or collect '
        'payments. Therefore there are no app purchases to refund. If you believe you were charged by mistake in '
        'connection with ${Config.appName}, contact ${Config.supportEmail} with the relevant details so we can '
        'investigate.',
  ),
};

class PolicyScreen extends StatelessWidget {
  final String policyKey;
  const PolicyScreen({super.key, required this.policyKey});

  @override
  Widget build(BuildContext context) {
    final (title, body) = policies[policyKey]!;
    return Scaffold(
      appBar: AppBar(
        flexibleSpace: const DecoratedBox(
          decoration: BoxDecoration(gradient: AppColors.barGradient),
          child: SizedBox.expand(),
        ),
        title: Text(title),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(body, style: const TextStyle(fontSize: 16, height: 1.5)),
        ],
      ),
    );
  }
}
