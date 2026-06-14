import 'package:shared_preferences/shared_preferences.dart';

/// Persists user state across launches: favorite channels + last-watched URL.
///
/// Keys are stream URLs (stable per channel), so the saved data survives
/// playlist re-ordering.
class PreferencesService {
  PreferencesService(this._prefs);

  static const _kFavorites = 'favorites';
  static const _kLastWatched = 'last_watched';

  final SharedPreferences _prefs;

  static Future<PreferencesService> create() async =>
      PreferencesService(await SharedPreferences.getInstance());

  Set<String> favorites() =>
      (_prefs.getStringList(_kFavorites) ?? const <String>[]).toSet();

  Future<void> saveFavorites(Set<String> urls) =>
      _prefs.setStringList(_kFavorites, urls.toList());

  String? lastWatched() => _prefs.getString(_kLastWatched);

  Future<void> saveLastWatched(String url) =>
      _prefs.setString(_kLastWatched, url);
}