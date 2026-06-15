import '../models/channel.dart';

/// Parses M3U / M3U8 playlist text into [Channel]s.
///
/// Handles the common extended-M3U shape:
/// ```
/// #EXTM3U
/// #EXTINF:-1 [attrs],Display Name 🇦🇷
/// http://host/stream.m3u8
/// ```
/// Country flag emoji at the end of the title is split out, and a coarse
/// [Channel.group] is inferred from keywords in the name.
class M3uParser {
  static List<Channel> parse(String content) {
    final lines = content.split(RegExp(r'\r?\n'));
    final channels = <Channel>[];

    String? pendingTitle;
    String? pendingGroupTitle; // from the EXTINF group-title="..." attribute
    for (final raw in lines) {
      final line = raw.trim();
      if (line.isEmpty) continue;

      if (line.startsWith('#EXTINF')) {
        // Title is everything after the first comma (attrs never contain one).
        final comma = line.indexOf(',');
        pendingTitle = comma == -1 ? line : line.substring(comma + 1).trim();
        // Capture the playlist-declared category, if any.
        final attrs = comma == -1 ? line : line.substring(0, comma);
        pendingGroupTitle = _groupTitleRegex.firstMatch(attrs)?.group(1)?.trim();
      } else if (line.startsWith('#')) {
        // Other directive (#EXTM3U, #EXTGRP, etc.) — ignore.
        continue;
      } else {
        // A URL line. Pair it with the pending title (or derive a fallback).
        final title = pendingTitle ?? _hostOf(line);
        final (cleanName, flag) = _splitFlag(title);
        // Trust the playlist's own group-title when present; else infer.
        final category = _mapGroupTitle(pendingGroupTitle) ?? _inferCategory(cleanName);
        channels.add(
          Channel(
            name: cleanName,
            url: line,
            category: category,
            group: _inferGroup(cleanName),
            flag: flag,
          ),
        );
        pendingTitle = null;
        pendingGroupTitle = null;
      }
    }
    return channels;
  }

  /// Splits a trailing flag emoji (regional-indicator pair) off the title.
  static (String, String?) _splitFlag(String title) {
    final match = _flagRegex.firstMatch(title);
    if (match != null) {
      final flag = match.group(0)!;
      final name = title.replaceAll(_flagRegex, '').trim();
      return (name.isEmpty ? title : name, flag);
    }
    return (title, null);
  }

  // Pulls the value out of a group-title="..." attribute.
  static final RegExp _groupTitleRegex = RegExp(r'group-title="([^"]*)"');

  /// Folds a playlist's free-form group-title into one of the app's top-level
  /// categories. Returns null for empty/unknown so the caller can keyword-infer.
  static String? _mapGroupTitle(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final g = raw.toUpperCase();
    if (g.contains('NEWS')) return 'News';
    if (g.contains('MOVIE') || g.contains('CINEMA') || g.contains('FILM')) return 'Movies';
    if (g.contains('KID') || g.contains('CARTOON') || g.contains('CHILD')) return 'Kids';
    if (g.contains('MUSIC')) return 'Music';
    if (g.contains('SPORT')) return 'Sports';
    if (g == 'UNDEFINED' || g == 'OTHER') return null; // fall back to inference
    // Entertainment, General, Family, Culture, Documentary, Religious, etc.
    return 'Entertainment';
  }

  static String _hostOf(String url) {
    final uri = Uri.tryParse(url);
    return uri?.host.isNotEmpty == true ? uri!.host : 'Unknown';
  }

  /// Top-level genre. Sports is the default since most entries are sports.
  static String _inferCategory(String name) {
    final n = name.toUpperCase();
    for (final entry in _categoryKeywords.entries) {
      for (final kw in entry.value) {
        if (n.contains(kw)) return entry.key;
      }
    }
    return 'Sports';
  }

  /// Coarse grouping by recognisable broadcaster keywords.
  static String _inferGroup(String name) {
    final n = name.toUpperCase();
    for (final entry in _groupKeywords.entries) {
      for (final kw in entry.value) {
        if (n.contains(kw)) return entry.key;
      }
    }
    return 'Other';
  }

  // Regional-indicator symbol pairs render as country flags. Match one or more.
  static final RegExp _flagRegex = RegExp(
    r'(?:[\u{1F1E6}-\u{1F1FF}]{2})+',
    unicode: true,
  );

  // Genre keywords. Checked before defaulting to Sports — keep these specific
  // so sports channels don't get mislabelled.
  static const Map<String, List<String>> _categoryKeywords = {
    'Test (always-on)': ['TEST', 'BIG BUCK', 'SAMPLE', 'DEMO', 'TEARS OF'],
    'News': [
      'NEWS', 'NOTICIAS', 'AL JAZEERA', 'ALJAZEERA', ' DW', 'FRANCE 24',
      'FRANCE24', 'EURONEWS', 'CGTN', 'TRT WORLD', 'CNN', 'BBC NEWS',
      'BLOOMBERG', 'RT NEWS', 'AJ ',
    ],
    'Movies': [
      'MOVIE', 'CINE', 'CINEMA', 'FILM', 'PELICULA', 'PELÍCULA', 'PELICULAS',
      'PELÍCULAS', 'RUNTIME', 'ACTION', 'CLASSIC',
    ],
    'Kids': [
      'KIDS', 'CARTOON', 'NICK', 'DISNEY', 'BABY', 'TOON', 'INFANTIL',
      'JUNIOR', 'NIÑOS',
    ],
    'Music': ['MUSIC', 'MTV', 'VEVO', 'TRACE', 'STINGRAY', 'HITS'],
    'Entertainment': [
      'COMEDY', 'NOVELA', 'NOVELAS', 'TELENOVELA', 'ENTRETENIMIENTO',
      'REALITY', 'GARAGE', 'RED BULL',
    ],
  };

  // Order matters: first match wins.
  static const Map<String, List<String>> _groupKeywords = {
    // Bangladesh sports broadcasters — keep first so their mirrors group
    // together and auto-skip can hop between servers of the same channel.
    'T Sports': ['T SPORTS', 'TSPORTS'],
    'Gazi TV': ['GAZI', 'GTV'],
    'Maasranga': ['MAASRANGA', 'MASRANGA'],
    'ESPN': ['ESPN'],
    'beIN': ['BEIN'],
    'DAZN': ['DAZN'],
    'FOX': ['FOX'],
    'TNT': ['TNT'],
    'TyC': ['TYC'],
    'Win Sports': ['WIN'],
    'DIRECTV / DSports': ['DSPORT', 'DSPORTS', 'DIRECTV', 'DSPORT '],
    'TUDN': ['TUDN'],
    'Match (RU)': ['МАТЧ', 'MATCH', 'ФУТБOЛ', 'ФУТБОЛ'],
    'Eurosport': ['EUROSPORT'],
    'Sky': ['SKY'],
    'Claro': ['CLARO'],
    'Real Madrid': ['REAL MADRID'],
    'Max Sport': ['MAX SPORT'],
    'Arena/Nova/CT': ['ARENA', 'NOVA', 'CT SPORT', 'SPORT 1', 'SPORT 2'],
    'Setanta': ['SETANTA', 'SETENTA'],
    'Ziggo': ['ZIGGO'],
  };
}