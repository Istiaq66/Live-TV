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
    for (final raw in lines) {
      final line = raw.trim();
      if (line.isEmpty) continue;

      if (line.startsWith('#EXTINF')) {
        // Title is everything after the first comma.
        final comma = line.indexOf(',');
        pendingTitle = comma == -1 ? line : line.substring(comma + 1).trim();
      } else if (line.startsWith('#')) {
        // Other directive (#EXTM3U, #EXTGRP, etc.) — ignore.
        continue;
      } else {
        // A URL line. Pair it with the pending title (or derive a fallback).
        final title = pendingTitle ?? _hostOf(line);
        final (cleanName, flag) = _splitFlag(title);
        channels.add(
          Channel(
            name: cleanName,
            url: line,
            category: _inferCategory(cleanName),
            group: _inferGroup(cleanName),
            flag: flag,
          ),
        );
        pendingTitle = null;
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