import 'package:flutter/material.dart';

import 'one_drive_sync_service.dart';

class OutlookFormattingService {
  static String formatImportTimestamp(BuildContext context, DateTime value) {
    final localizations = MaterialLocalizations.of(context);
    final date = localizations.formatShortDate(value);
    final time = localizations.formatTimeOfDay(
      TimeOfDay.fromDateTime(value),
      alwaysUse24HourFormat: true,
    );
    return '$date $time';
  }

  static String formatImportDate(BuildContext context, DateTime value) {
    return MaterialLocalizations.of(context).formatShortDate(value);
  }

  static const List<String> _weekdayAbbreviations = [
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];

  static const List<String> _monthAbbreviations = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  static String formatPlannerDate(BuildContext context, DateTime value) {
    final weekday = _weekdayAbbreviations[value.weekday - 1];
    final day = value.day.toString().padLeft(2, '0');
    final month = _monthAbbreviations[value.month - 1];
    final year = (value.year % 100).toString().padLeft(2, '0');
    return '$weekday, $day-$month-$year';
  }

  static String formatOutlookEventTimeRange(OutlookCalendarEvent event) {
    if (event.isAllDay) {
      return 'All day (takes the full day)';
    }
    if (event.start == null) {
      return 'Time unavailable';
    }

    final localStart = event.start!.toLocal();
    final startHour = localStart.hour;
    final startMinute = localStart.minute.toString().padLeft(2, '0');
    final startSuffix = startHour >= 12 ? 'PM' : 'AM';
    final startHour12 = startHour % 12 == 0 ? 12 : startHour % 12;

    if (event.end == null) {
      return '$startHour12:$startMinute $startSuffix';
    }

    final localEnd = event.end!.toLocal();
    final endHour = localEnd.hour;
    final endMinute = localEnd.minute.toString().padLeft(2, '0');
    final endSuffix = endHour >= 12 ? 'PM' : 'AM';
    final endHour12 = endHour % 12 == 0 ? 12 : endHour % 12;

    return '$startHour12:$startMinute $startSuffix - $endHour12:$endMinute $endSuffix';
  }

  static String formatOutlookDayDivider(DateTime date) {
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    final weekday = weekdays[date.weekday - 1];
    final day = date.day.toString().padLeft(2, '0');
    final month = months[date.month - 1];
    final year = date.year.toString().substring(2);

    return '$weekday, $day-$month-$year';
  }

  static bool isMultiDayOutlookEvent(OutlookCalendarEvent event) {
    final start = event.start?.toLocal();
    final end = event.end?.toLocal();
    if (start == null || end == null) {
      return false;
    }

    final startDay = DateTime(start.year, start.month, start.day);
    final endDay = DateTime(end.year, end.month, end.day);

    if (event.isAllDay) {
      final inclusiveEndDay = endDay.subtract(const Duration(days: 1));
      return inclusiveEndDay.isAfter(startDay);
    }

    return endDay.isAfter(startDay);
  }

  static String formatOutlookEventDateRange(
    BuildContext context,
    OutlookCalendarEvent event,
  ) {
    final start = event.start?.toLocal();
    final end = event.end?.toLocal();
    if (start == null) {
      return '';
    }

    final startDay = DateTime(start.year, start.month, start.day);
    DateTime endDay = startDay;

    if (end != null) {
      final rawEndDay = DateTime(end.year, end.month, end.day);
      if (event.isAllDay) {
        final inclusiveEndDay = rawEndDay.subtract(const Duration(days: 1));
        endDay = inclusiveEndDay.isBefore(startDay)
            ? startDay
            : inclusiveEndDay;
      } else {
        endDay = rawEndDay;
      }
    }

    return '${formatImportDate(context, startDay)} - ${formatImportDate(context, endDay)}';
  }
}
