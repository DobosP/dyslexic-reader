import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/app_info.dart';
import 'privacy_screen.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  Future<void> _launch(BuildContext context, Uri uri) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await canLaunchUrl(uri) && await launchUrl(uri);
    if (!ok) {
      messenger.showSnackBar(
        SnackBar(content: Text('Could not open ${uri.scheme} link')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('About')),
      body: ListView(
        children: [
          const SizedBox(height: 24),
          Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Image.asset(
                'assets/branding/app_icon.png',
                width: 88,
                height: 88,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Center(child: Text(kAppName, style: theme.textTheme.headlineSmall)),
          const SizedBox(height: 4),
          Center(
            child: Text('Version $kAppVersion', style: theme.textTheme.bodySmall),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              kAppTagline,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
          ),
          const SizedBox(height: 24),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: const Text('Privacy policy'),
            subtitle: const Text('No data leaves your device'),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const PrivacyScreen()),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.description_outlined),
            title: const Text('Open-source licenses'),
            onTap: () => showLicensePage(
              context: context,
              applicationName: kAppName,
              applicationVersion: 'Version $kAppVersion',
              applicationIcon: Padding(
                padding: const EdgeInsets.all(8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.asset('assets/branding/app_icon.png',
                      width: 56, height: 56),
                ),
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.feedback_outlined),
            title: const Text('Send feedback'),
            subtitle: Text(kSupportEmail),
            onTap: () => _launch(
              context,
              Uri(
                scheme: 'mailto',
                path: kSupportEmail,
                query: 'subject=${Uri.encodeComponent('$kAppName feedback')}',
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.star_outline),
            title: const Text('Rate on Google Play'),
            onTap: () => _launch(
              context,
              Uri.parse('market://details?id=$kAppPackageId'),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              'Free, with no ads and no tracking. Built with care for people '
              'who find reading hard.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall,
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
