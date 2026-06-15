import 'package:flutter_test/flutter_test.dart';
import 'package:live_tv/models/fixture.dart';

void main() {
  group('Fixture.fromSportsDb', () {
    test('parses a full record with UTC timestamp', () {
      final f = Fixture.fromSportsDb({
        'idEvent': '123',
        'strHomeTeam': 'Arsenal',
        'strAwayTeam': 'Chelsea',
        'strLeague': 'Premier League',
        'strTimestamp': '2026-06-15T18:30:00+00:00',
        'strStatus': 'Not Started',
      })!;
      expect(f.id, '123');
      expect(f.title, 'Arsenal vs Chelsea');
      expect(f.league, 'Premier League');
      expect(f.kickoff, isNotNull);
      expect(f.kickoff!.isUtc, isFalse); // converted to local
    });

    test('returns null when required fields are missing', () {
      expect(
        Fixture.fromSportsDb({'idEvent': '1', 'strHomeTeam': 'A'}),
        isNull,
      );
      expect(
        Fixture.fromSportsDb(
            {'idEvent': '1', 'strHomeTeam': '', 'strAwayTeam': 'B'}),
        isNull,
      );
    });

    test('defaults league to Football when absent', () {
      final f = Fixture.fromSportsDb({
        'idEvent': '9',
        'strHomeTeam': 'A',
        'strAwayTeam': 'B',
      })!;
      expect(f.league, 'Football');
    });

    test('falls back to dateEvent + strTime when no timestamp', () {
      final f = Fixture.fromSportsDb({
        'idEvent': '5',
        'strHomeTeam': 'A',
        'strAwayTeam': 'B',
        'dateEvent': '2026-06-15',
        'strTime': '20:00:00',
      })!;
      expect(f.kickoff, isNotNull);
    });

    test('whenLabel shows status when kickoff unknown', () {
      final f = Fixture.fromSportsDb({
        'idEvent': '7',
        'strHomeTeam': 'A',
        'strAwayTeam': 'B',
        'strStatus': 'TBD',
      })!;
      expect(f.kickoff, isNull);
      expect(f.whenLabel, 'TBD');
    });
  });
}