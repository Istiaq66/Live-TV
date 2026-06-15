import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';

import 'l10n/app_localizations.dart';
import 'screens/home_screen.dart';
import 'services/preferences_service.dart';

/// Selected UI locale; null = follow the device/system language. Updated by the
/// in-app language switcher and persisted across launches.
final ValueNotifier<Locale?> localeNotifier = ValueNotifier<Locale?>(null);

PreferencesService? _localePrefs;

/// Switches the app language at runtime and persists the choice.
Future<void> setAppLocale(Locale? locale) async {
  localeNotifier.value = locale;
  await _localePrefs?.saveLocaleCode(locale?.languageCode);
}

void main() async {
  // Required before any Player/VideoController is created (initializes libmpv).
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();

  // Restore the saved language before first frame so there's no flicker.
  _localePrefs = await PreferencesService.create();
  final saved = _localePrefs!.localeCode();
  if (saved != null) localeNotifier.value = Locale(saved);

  runApp(const LiveTvApp());
}

class LiveTvApp extends StatelessWidget {
  const LiveTvApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Locale?>(
      valueListenable: localeNotifier,
      builder: (context, locale, _) {
        return MaterialApp(
          onGenerateTitle: (ctx) => AppLocalizations.of(ctx).appName,
          debugShowCheckedModeBanner: false,
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          // Let mouse/trackpad drag scroll horizontal lists (filter chips) on
          // desktop — Flutter disables mouse-drag scrolling by default there.
          scrollBehavior: const _DragScrollBehavior(),
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF2E7D32), // pitch green
              brightness: Brightness.dark,
            ),
            useMaterial3: true,
            // Bengali glyphs aren't in the default web font — fall back to the
            // bundled Noto Sans Bengali so বাংলা renders everywhere.
            fontFamilyFallback: const ['NotoSansBengali'],
          ),
          home: const HomeScreen(),
        );
      },
    );
  }
}

/// Enables drag-to-scroll for mouse and trackpad (in addition to touch/stylus),
/// so the horizontal filter chip rows can be swiped on Windows/desktop.
class _DragScrollBehavior extends MaterialScrollBehavior {
  const _DragScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
      };
}