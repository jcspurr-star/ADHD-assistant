import 'one_drive_sync_service.dart';

class IcsImportService {
  static List<OutlookCalendarEvent> parseEvents(String icsContent) {
    final normalized = icsContent
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n');
    final lines = normalized.split('\n');
    final events = <OutlookCalendarEvent>[];

    String? currentUid;
    String? currentSummary;
    String? currentStart;
    String? currentEnd;
    bool currentIsAllDay = false;

    void flushCurrentEvent() {
      if (currentUid == null &&
          currentSummary == null &&
          currentStart == null) {
        return;
      }

      final start = _parseDateTime(currentStart, currentIsAllDay);
      final end = _parseDateTime(currentEnd, currentIsAllDay);

      if (start != null) {
        events.add(
          OutlookCalendarEvent(
            id: currentUid ?? 'event-${events.length}',
            subject: (currentSummary ?? '').trim().isEmpty
                ? '(No title)'
                : currentSummary!.trim(),
            start: start,
            end: end,
            isAllDay: currentIsAllDay,
            calendarSource: 'work',
          ),
        );
      }
    }

    for (final rawLine in lines) {
      final line = rawLine.trim();
      if (line.isEmpty) {
        continue;
      }

      if (line == 'BEGIN:VEVENT') {
        currentUid = null;
        currentSummary = null;
        currentStart = null;
        currentEnd = null;
        currentIsAllDay = false;
        continue;
      }

      if (line == 'END:VEVENT') {
        flushCurrentEvent();
        currentUid = null;
        currentSummary = null;
        currentStart = null;
        currentEnd = null;
        currentIsAllDay = false;
        continue;
      }

      if (line.startsWith('UID:')) {
        currentUid = line.substring(4).trim();
      } else if (line.startsWith('SUMMARY:')) {
        currentSummary = _decodeValue(line.substring(8));
      } else if (line.startsWith('DTSTART')) {
        currentIsAllDay = line.contains('VALUE=DATE');
        currentStart = _extractValue(line);
      } else if (line.startsWith('DTEND')) {
        currentIsAllDay = currentIsAllDay || line.contains('VALUE=DATE');
        currentEnd = _extractValue(line);
      }
    }

    return events;
  }

  static String _extractValue(String line) {
    final separatorIndex = line.indexOf(':');
    if (separatorIndex == -1) {
      return '';
    }
    return line.substring(separatorIndex + 1).trim();
  }

  static String _decodeValue(String value) {
    return value
        .replaceAll(r'\\n', '\n')
        .replaceAll(r'\\N', '\n')
        .replaceAll(r'\\,', ',')
        .replaceAll(r'\\;', ';')
        .replaceAll(r'\\\\', '\\')
        .trim();
  }

  static DateTime? _parseDateTime(String? value, bool isAllDay) {
    if (value == null || value.isEmpty) {
      return null;
    }

    final trimmed = value.trim();
    if (trimmed.length == 8 && isAllDay) {
      final year = int.parse(trimmed.substring(0, 4));
      final month = int.parse(trimmed.substring(4, 6));
      final day = int.parse(trimmed.substring(6, 8));
      return DateTime(year, month, day);
    }

    if (trimmed.length >= 8 && trimmed.contains('T')) {
      final parts = trimmed.split('T');
      if (parts.length == 2) {
        final datePart = parts[0];
        final timePart = parts[1].replaceAll('Z', '');

        if (datePart.length == 8 && timePart.length >= 4) {
          final year = int.parse(datePart.substring(0, 4));
          final month = int.parse(datePart.substring(4, 6));
          final day = int.parse(datePart.substring(6, 8));
          final hour = int.parse(timePart.substring(0, 2));
          final minute = int.parse(timePart.substring(2, 4));
          final second = timePart.length >= 6
              ? int.parse(timePart.substring(4, 6))
              : 0;

          if (trimmed.endsWith('Z')) {
            return DateTime.utc(year, month, day, hour, minute, second);
          }
          return DateTime(year, month, day, hour, minute, second);
        }
      }
    }

    return null;
  }
}
