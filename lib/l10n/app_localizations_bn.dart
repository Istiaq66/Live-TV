// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Bengali Bangla (`bn`).
class AppLocalizationsBn extends AppLocalizations {
  AppLocalizationsBn([String locale = 'bn']) : super(locale);

  @override
  String get appName => 'Kickora';

  @override
  String get appTagline => 'লাইভ খেলা ও টিভি';

  @override
  String get showOnlineOnly => 'শুধু অনলাইন দেখান';

  @override
  String get healthCheck => 'চ্যানেলগুলো যাচাই করুন';

  @override
  String get searchHint => 'চ্যানেল খুঁজুন…';

  @override
  String get noChannelsMatch => 'কোনো চ্যানেল মেলেনি';

  @override
  String loadFailed(String error) {
    return 'প্লেলিস্ট লোড করা যায়নি:\n$error';
  }

  @override
  String get drawerTodayFootball => 'আজকের ফুটবল';

  @override
  String get drawerMatchesToday => 'আজকের নির্ধারিত ম্যাচ';

  @override
  String get privacyPolicy => 'প্রাইভেসি পলিসি';

  @override
  String get about => 'সম্পর্কে';

  @override
  String versionLabel(String version) {
    return 'সংস্করণ $version';
  }

  @override
  String get madeBy => 'তৈরি করেছেন ইস্তিয়াক আহমেদ';

  @override
  String get language => 'ভাষা';

  @override
  String get aboutBody1 =>
      'Kickora একটি ফ্রি লাইভ-টিভি ও খেলার অ্যাপ, তৈরি করেছেন স্বাধীন ফ্লাটার ডেভেলপার ইস্তিয়াক আহমেদ।';

  @override
  String get aboutBody2 =>
      'চ্যানেলগুলো তৃতীয় পক্ষের সার্ভার থেকে চলে। Kickora কোনো কন্টেন্ট হোস্ট বা মালিকানা করে না।';

  @override
  String get fixturesTitle => 'আজকের ফুটবল';

  @override
  String fixturesLoadError(String error) {
    return 'ম্যাচ তালিকা লোড করা যায়নি।\n$error';
  }

  @override
  String get fixturesEmpty => 'আজ কোনো ফুটবল ম্যাচ নেই।';

  @override
  String get pickChannel => 'দেখা শুরু করতে একটি চ্যানেল বাছুন';

  @override
  String get streamUnavailable => 'স্ট্রিম পাওয়া যাচ্ছে না';

  @override
  String get streamUnavailableHint =>
      'এই সোর্সটি বন্ধ বা জিও-ব্লকড হতে পারে। অন্যটি চেষ্টা করুন।';

  @override
  String get retry => 'আবার চেষ্টা';

  @override
  String get quality => 'মান';

  @override
  String get qualityAuto => 'অটো';

  @override
  String get streamTimedOut => 'স্ট্রিম টাইম আউট';

  @override
  String get noWorkingSource =>
      'কোনো সচল সোর্স পাওয়া যায়নি। উপরে-ডানে যাচাই করুন।';

  @override
  String sourceDownNoOther(String name) {
    return '“$name” বন্ধ — অন্য কোনো সোর্স নেই।';
  }

  @override
  String sourceDownTryingAnother(String name) {
    return '“$name” বন্ধ — অন্য সোর্স চেষ্টা করা হচ্ছে…';
  }

  @override
  String showingSportsFor(String match) {
    return '“$match” এর জন্য খেলার চ্যানেল দেখানো হচ্ছে। ব্রডকাস্টার বাছুন।';
  }
}
