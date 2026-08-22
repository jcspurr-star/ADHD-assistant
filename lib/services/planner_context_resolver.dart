import '../models/activity_recommendation.dart';
import 'one_drive_sync_service.dart';

class ResolvedPlannerContext {
  const ResolvedPlannerContext({
    required this.dayContext,
    required this.isWeekend,
    required this.isHoliday,
    this.holidayName,
  });

  final DayContext dayContext;
  final bool isWeekend;
  final bool isHoliday;
  final String? holidayName;
}

class PlannerContextResolver {
  static ResolvedPlannerContext resolve({
    required DateTime day,
    required DayContext manualContext,
    Iterable<OutlookCalendarEvent> calendarEvents = const [],
  }) {
    final isWeekend =
        day.weekday == DateTime.saturday || day.weekday == DateTime.sunday;
    OutlookCalendarEvent? holiday;
    for (final event in calendarEvents) {
      final subject = event.subject.toLowerCase();
      if (event.isAllDay &&
          (subject.contains('holiday') || subject.contains('bank holiday'))) {
        holiday = event;
        break;
      }
    }
    return ResolvedPlannerContext(
      dayContext: manualContext,
      isWeekend: isWeekend,
      isHoliday: holiday != null,
      holidayName: holiday?.subject,
    );
  }
}
