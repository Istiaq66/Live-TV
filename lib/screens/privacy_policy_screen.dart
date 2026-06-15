import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

/// Static privacy policy. The app stores nothing remotely — favorites and the
/// last-watched channel live only in on-device storage.
class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context).privacyPolicy)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: const [
          _H('Overview'),
          _P('Drishto is a free live-TV aggregator. It does not require an '
              'account and does not collect, store, or transmit any personal '
              'information to its developer.'),
          _H('Data stored on your device'),
          _P('Your favorite channels and your last-watched channel are saved '
              'locally on your device only, so they persist between launches. '
              'This data never leaves your device and is removed when you '
              'uninstall the app.'),
          _H('Third-party streams'),
          _P('Channels play from third-party stream URLs that Drishto does not '
              'own, host, or control. When you play a channel, your device '
              'connects directly to that provider, which may receive your IP '
              'address and standard connection details under its own privacy '
              'policy. Drishto is not responsible for third-party content or '
              'their data practices.'),
          _H('Match fixtures'),
          _P('Today\'s football fixtures are fetched from TheSportsDB '
              '(thesportsdb.com). Only the current date is sent to retrieve the '
              'schedule. No personal data is shared.'),
          _H('Analytics & ads'),
          _P('The app contains no advertising and no analytics or tracking SDKs.'),
          _H('Children'),
          _P('Drishto is not directed at children and collects no data from '
              'anyone.'),
          _H('Changes'),
          _P('This policy may be updated as the app evolves. Continued use '
              'after an update constitutes acceptance of the revised policy.'),
          _H('Contact'),
          _P('Developer: Istiaq Ahmed. For questions about this policy, contact '
              'the developer through the app\'s store listing.'),
        ],
      ),
    );
  }
}

class _H extends StatelessWidget {
  const _H(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 6),
      child: Text(text, style: Theme.of(context).textTheme.titleMedium),
    );
  }
}

class _P extends StatelessWidget {
  const _P(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    return Text(text, style: const TextStyle(height: 1.4));
  }
}