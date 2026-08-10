import 'package:adhd_assistant/services/ics_import_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('IcsImportService', () {
    test('parses basic timed and all-day events from an ICS file', () {
      const icsContent = '''BEGIN:VCALENDAR
VERSION:2.0
PRODID:-//Example//Example Calendar//EN
BEGIN:VEVENT
UID:evt-1
DTSTAMP:20260810T090000Z
DTSTART:20260810T090000Z
DTEND:20260810T100000Z
SUMMARY:Team sync
END:VEVENT
BEGIN:VEVENT
UID:evt-2
DTSTART;VALUE=DATE:20260811
DTEND;VALUE=DATE:20260812
SUMMARY:Vacation
END:VEVENT
END:VCALENDAR''';

      final events = IcsImportService.parseEvents(icsContent);

      expect(events.length, 2);
      expect(events.first.subject, 'Team sync');
      expect(events.first.start, DateTime.utc(2026, 8, 10, 9));
      expect(events.first.end, DateTime.utc(2026, 8, 10, 10));
      expect(events.first.isAllDay, isFalse);

      expect(events.last.subject, 'Vacation');
      expect(events.last.isAllDay, isTrue);
      expect(events.last.start, DateTime(2026, 8, 11));
      expect(events.last.end, DateTime(2026, 8, 12));
    });
  });
}
