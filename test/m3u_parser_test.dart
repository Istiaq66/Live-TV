import 'package:flutter_test/flutter_test.dart';
import 'package:live_tv/services/m3u_parser.dart';

void main() {
  group('M3uParser.parse', () {
    test('parses name, url and trailing flag', () {
      final channels = M3uParser.parse('''
#EXTM3U
#EXTINF:-1 group-title="News",Al Jazeera 🇶🇦
http://example.com/aj/index.m3u8
''');
      expect(channels, hasLength(1));
      final c = channels.single;
      expect(c.name, 'Al Jazeera');
      expect(c.flag, '🇶🇦');
      expect(c.url, 'http://example.com/aj/index.m3u8');
      expect(c.category, 'News');
    });

    test('folds free-form group-title into app categories', () {
      String catOf(String group, String name) => M3uParser.parse(
            '#EXTINF:-1 group-title="$group",$name\nhttp://h/$name.m3u8',
          ).single.category;

      expect(catOf('Cinema HD', 'X'), 'Movies');
      expect(catOf('Kids & Family', 'X'), 'Kids');
      expect(catOf('Top Music', 'X'), 'Music');
      expect(catOf('Live Sports', 'X'), 'Sports');
      expect(catOf('Islamic', 'X'), 'Religious');
      expect(catOf('Breaking News', 'X'), 'News');
      // Unknown/empty group → inference falls back to Entertainment for a
      // non-sports name.
      expect(catOf('Documentary', 'Planet Earth'), 'Entertainment');
    });

    test('UNDEFINED/OTHER group falls back to name inference', () {
      final c = M3uParser.parse(
        '#EXTINF:-1 group-title="Undefined",CNN International\nhttp://h/cnn.m3u8',
      ).single;
      expect(c.category, 'News'); // inferred from the name, not the group
    });

    test('infers Sports from a recognised broadcaster with no group-title', () {
      final c = M3uParser.parse(
        '#EXTINF:-1 ,ESPN 2\nhttp://h/espn.m3u8',
      ).single;
      expect(c.category, 'Sports');
      expect(c.group, 'ESPN');
    });

    test('collects EXTVLCOPT headers', () {
      final c = M3uParser.parse('''
#EXTINF:-1 ,Gated Stream
#EXTVLCOPT:http-user-agent=MyAgent/1.0
#EXTVLCOPT:http-referrer=https://ref.example/
#EXTVLCOPT:http-origin=https://orig.example
http://h/gated.m3u8
''').single;
      expect(c.headers['User-Agent'], 'MyAgent/1.0');
      expect(c.headers['Referer'], 'https://ref.example/');
      expect(c.headers['Origin'], 'https://orig.example');
    });

    test('parses #EXTHTTP JSON headers', () {
      final c = M3uParser.parse('''
#EXTINF:-1 ,JsonHeaders
#EXTHTTP:{"User-Agent":"UA2","Referer":"https://r2/"}
http://h/j.m3u8
''').single;
      expect(c.headers['User-Agent'], 'UA2');
      expect(c.headers['Referer'], 'https://r2/');
    });

    test('reads user-agent from an EXTINF attribute', () {
      final c = M3uParser.parse(
        '#EXTINF:-1 user-agent="AttrUA",Chan\nhttp://h/a.m3u8',
      ).single;
      expect(c.headers['User-Agent'], 'AttrUA');
    });

    test('headers do not leak from one channel to the next', () {
      final list = M3uParser.parse('''
#EXTINF:-1 ,First
#EXTVLCOPT:http-user-agent=OnlyFirst
http://h/1.m3u8
#EXTINF:-1 ,Second
http://h/2.m3u8
''');
      expect(list[0].headers['User-Agent'], 'OnlyFirst');
      expect(list[1].headers, isEmpty);
    });

    test('falls back to host when title is missing', () {
      final c = M3uParser.parse('http://cdn.example.com/x/stream.m3u8').single;
      expect(c.name, 'cdn.example.com');
    });

    test('ignores blank lines and unknown directives', () {
      final list = M3uParser.parse('''
#EXTM3U

#EXTGRP:whatever
#EXTINF:-1 ,Only
http://h/o.m3u8
''');
      expect(list, hasLength(1));
    });
  });
}