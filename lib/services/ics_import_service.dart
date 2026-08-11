import 'one_drive_sync_service.dart';

class IcsImportService {
  static List<OutlookCalendarEvent> parseEvents(String icsContent) {
    final normalized = icsContent
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n');
    final lines = _unfoldLines(normalized.split('\n'));
    final events = <OutlookCalendarEvent>[];
    final calendarSource = _detectCalendarSource(lines);

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
            calendarSource: calendarSource,
          ),
        );
      }
    }

    for (final rawLine in lines) {
      final line = rawLine.trimRight();
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

      final separatorIndex = line.indexOf(':');
      if (separatorIndex == -1) {
        continue;
      }

      final propertyWithParams = line.substring(0, separatorIndex);
      final propertyName = propertyWithParams
          .split(';')
          .first
          .trim()
          .toUpperCase();

      if (propertyName == 'UID') {
        currentUid = _extractValue(line);
      } else if (propertyName == 'SUMMARY') {
        currentSummary = _decodeValue(_extractValue(line));
      } else if (propertyName == 'DTSTART') {
        currentIsAllDay = propertyWithParams.toUpperCase().contains(
          'VALUE=DATE',
        );
        currentStart = _extractValue(line);
      } else if (propertyName == 'DTEND') {
        currentIsAllDay =
            currentIsAllDay ||
            propertyWithParams.toUpperCase().contains('VALUE=DATE');
        currentEnd = _extractValue(line);
      }
    }

    return events;
  }

  static List<String> _unfoldLines(List<String> lines) {
    final unfolded = <String>[];

    for (final line in lines) {
      if (line.startsWith(' ') || line.startsWith('\t')) {
        if (unfolded.isEmpty) {
          continue;
        }
        unfolded[unfolded.length - 1] += line.substring(1);
      } else {
        unfolded.add(line);
      }
    }

    return unfolded;
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

  static String _detectCalendarSource(List<String> lines) {
    for (final rawLine in lines) {
      final line = rawLine.trimRight();
      if (line.isEmpty) {
        continue;
      }
      final separatorIndex = line.indexOf(':');
      if (separatorIndex == -1) {
        continue;
      }
      final propertyWithParams = line.substring(0, separatorIndex);
      final propertyName = propertyWithParams
          .split(';')
          .first
          .trim()
          .toUpperCase();
      if (propertyName != 'X-WR-CALNAME') {
        continue;
      }
      final value = _decodeValue(_extractValue(line)).toLowerCase();
      if (value.contains('work') ||
          value.contains('office') ||
          value.contains('business')) {
        return 'work';
      }
      return 'home';
    }

    return 'home';
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
