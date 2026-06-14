import 'package:flutter/material.dart';

/// The privacy policy, shown in-app so it works offline. Keep in sync with
/// docs/PRIVACY_POLICY.md (the hosted copy linked from the Play listing).
const String _kPrivacyPolicy = '''
Dyslexic Reader is a free, on-device reading app. This explains, in plain language, what the app does and does not do with your information.

The short version: Dyslexic Reader does not collect, transmit, or sell any personal data. Everything you read stays on your device.

WHAT WE COLLECT
Nothing. There are no user accounts, no sign-in, no advertising, and no third-party analytics or tracking. We do not operate any servers that receive your data.

YOUR DOCUMENTS STAY ON YOUR DEVICE
Documents you open (PDF, Word, text, or pasted text) are read and processed entirely on your device. Their text is never uploaded anywhere. Your library, reading position, bookmarks, notes, and reading settings are stored only in the app's private storage on your device, and are removed when you uninstall the app.

NETWORK USE
The app works fully offline once set up. It uses the internet only in these limited, content-free ways:
• One-time OCR model download. The first time you import a scanned (image-only) PDF, the app downloads a ~20 MB text-recognition model so OCR can run offline thereafter. This fetches the model only — none of your documents or text are sent.
• Text-to-speech voices. Read-aloud uses your device's built-in text-to-speech engine. Depending on the engine and voice installed, that system component may itself use the network to fetch or stream voices. This is handled by your device's TTS engine, not by Dyslexic Reader, and is governed by that engine's own privacy policy. You can choose fully offline voices in your device's settings.

PERMISSIONS
• Internet — used only for the two purposes above. The app sends no personal data over the network.
• Opening files — when you choose to open or share a document into the app, Android grants temporary access to that single file. The app does not browse or scan your storage on its own.

CHILDREN'S PRIVACY
Dyslexic Reader is suitable for all ages. Because it collects no personal data, it does not knowingly collect information from anyone, including children.

DATA SHARING AND SALE
We do not share or sell any data, because we do not collect any.

CONTACT
Questions? Contact the developer at the address shown on the About screen.
''';

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Privacy policy')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'No data leaves your device',
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          SelectableText(
            _kPrivacyPolicy.trim(),
            style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
          ),
        ],
      ),
    );
  }
}
