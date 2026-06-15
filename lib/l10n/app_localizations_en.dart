// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'Kickora';

  @override
  String get appTagline => 'Live sports & TV';

  @override
  String get showOnlineOnly => 'Show online only';

  @override
  String get healthCheck => 'Health-check visible channels';

  @override
  String get searchHint => 'Search channels…';

  @override
  String get noChannelsMatch => 'No channels match';

  @override
  String loadFailed(String error) {
    return 'Failed to load playlist:\n$error';
  }

  @override
  String get drawerTodayFootball => 'Today\'s Football';

  @override
  String get drawerMatchesToday => 'Matches scheduled today';

  @override
  String get privacyPolicy => 'Privacy Policy';

  @override
  String get about => 'About';

  @override
  String versionLabel(String version) {
    return 'Version $version';
  }

  @override
  String get madeBy => 'Made by Istiaq Ahmed';

  @override
  String get language => 'Language';

  @override
  String get aboutBody1 =>
      'Kickora is a free live-TV and sports aggregator built by Istiaq Ahmed, an independent Flutter developer.';

  @override
  String get aboutBody2 =>
      'Channels stream from third-party providers. Kickora does not host or own any content.';

  @override
  String get fixturesTitle => 'Today\'s Football';

  @override
  String fixturesLoadError(String error) {
    return 'Couldn\'t load fixtures.\n$error';
  }

  @override
  String get fixturesEmpty => 'No football listed for today.';

  @override
  String get pickChannel => 'Pick a channel to start watching';

  @override
  String get streamUnavailable => 'Stream unavailable';

  @override
  String get streamUnavailableHint =>
      'This source may be offline or geo-blocked. Try another.';

  @override
  String get retry => 'Retry';

  @override
  String get quality => 'Quality';

  @override
  String get qualityAuto => 'Auto';

  @override
  String get streamTimedOut => 'Stream timed out';

  @override
  String get noWorkingSource =>
      'No working source found. Try Health-check (top-right).';

  @override
  String sourceDownNoOther(String name) {
    return '“$name” is down — no other source available.';
  }

  @override
  String sourceDownTryingAnother(String name) {
    return '“$name” down — trying another source…';
  }

  @override
  String showingSportsFor(String match) {
    return 'Showing Sports channels for “$match”. Pick a broadcaster.';
  }
}
