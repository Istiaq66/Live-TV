import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_bn.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('bn'),
    Locale('en'),
  ];

  /// No description provided for @appName.
  ///
  /// In en, this message translates to:
  /// **'Kickora'**
  String get appName;

  /// No description provided for @appTagline.
  ///
  /// In en, this message translates to:
  /// **'Live sports & TV'**
  String get appTagline;

  /// No description provided for @showOnlineOnly.
  ///
  /// In en, this message translates to:
  /// **'Show online only'**
  String get showOnlineOnly;

  /// No description provided for @healthCheck.
  ///
  /// In en, this message translates to:
  /// **'Health-check visible channels'**
  String get healthCheck;

  /// No description provided for @searchHint.
  ///
  /// In en, this message translates to:
  /// **'Search channels…'**
  String get searchHint;

  /// No description provided for @noChannelsMatch.
  ///
  /// In en, this message translates to:
  /// **'No channels match'**
  String get noChannelsMatch;

  /// No description provided for @loadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load playlist:\n{error}'**
  String loadFailed(String error);

  /// No description provided for @drawerTodayFootball.
  ///
  /// In en, this message translates to:
  /// **'Today\'s Football'**
  String get drawerTodayFootball;

  /// No description provided for @drawerMatchesToday.
  ///
  /// In en, this message translates to:
  /// **'Matches scheduled today'**
  String get drawerMatchesToday;

  /// No description provided for @privacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get privacyPolicy;

  /// No description provided for @about.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get about;

  /// No description provided for @versionLabel.
  ///
  /// In en, this message translates to:
  /// **'Version {version}'**
  String versionLabel(String version);

  /// No description provided for @madeBy.
  ///
  /// In en, this message translates to:
  /// **'Made by Istiaq Ahmed'**
  String get madeBy;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @aboutBody1.
  ///
  /// In en, this message translates to:
  /// **'Kickora is a free live-TV and sports aggregator built by Istiaq Ahmed, an independent Flutter developer.'**
  String get aboutBody1;

  /// No description provided for @aboutBody2.
  ///
  /// In en, this message translates to:
  /// **'Channels stream from third-party providers. Kickora does not host or own any content.'**
  String get aboutBody2;

  /// No description provided for @fixturesTitle.
  ///
  /// In en, this message translates to:
  /// **'Today\'s Football'**
  String get fixturesTitle;

  /// No description provided for @fixturesLoadError.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load fixtures.\n{error}'**
  String fixturesLoadError(String error);

  /// No description provided for @fixturesEmpty.
  ///
  /// In en, this message translates to:
  /// **'No football listed for today.'**
  String get fixturesEmpty;

  /// No description provided for @pickChannel.
  ///
  /// In en, this message translates to:
  /// **'Pick a channel to start watching'**
  String get pickChannel;

  /// No description provided for @streamUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Stream unavailable'**
  String get streamUnavailable;

  /// No description provided for @streamUnavailableHint.
  ///
  /// In en, this message translates to:
  /// **'This source may be offline or geo-blocked. Try another.'**
  String get streamUnavailableHint;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @quality.
  ///
  /// In en, this message translates to:
  /// **'Quality'**
  String get quality;

  /// No description provided for @qualityAuto.
  ///
  /// In en, this message translates to:
  /// **'Auto'**
  String get qualityAuto;

  /// No description provided for @streamTimedOut.
  ///
  /// In en, this message translates to:
  /// **'Stream timed out'**
  String get streamTimedOut;

  /// No description provided for @noWorkingSource.
  ///
  /// In en, this message translates to:
  /// **'No working source found. Try Health-check (top-right).'**
  String get noWorkingSource;

  /// No description provided for @sourceDownNoOther.
  ///
  /// In en, this message translates to:
  /// **'“{name}” is down — no other source available.'**
  String sourceDownNoOther(String name);

  /// No description provided for @sourceDownTryingAnother.
  ///
  /// In en, this message translates to:
  /// **'“{name}” down — trying another source…'**
  String sourceDownTryingAnother(String name);

  /// No description provided for @showingSportsFor.
  ///
  /// In en, this message translates to:
  /// **'Showing Sports channels for “{match}”. Pick a broadcaster.'**
  String showingSportsFor(String match);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['bn', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'bn':
      return AppLocalizationsBn();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
