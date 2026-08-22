import 'package:adhd_assistant/models/activity_recommendation.dart';
import 'package:adhd_assistant/services/one_drive_sync_service.dart';
import 'package:adhd_assistant/services/planner_context_resolver.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('resolves weekends and all-day holiday calendar events', () {
    final result = PlannerContextResolver.resolve(
      day: DateTime(2026, 8, 22),
      manualContext: const DayContext(
        gymMorning: false,
        workLocation: WorkLocation.home,
        eveningAvailable: true,
      ),
      calendarEvents: [
        OutlookCalendarEvent(
          id: 'holiday',
          subject: 'Summer holiday',
          start: DateTime(2026, 8, 22),
          end: DateTime(2026, 8, 23),
          isAllDay: true,
        ),
      ],
    );

    expect(result.isWeekend, isTrue);
    expect(result.isHoliday, isTrue);
    expect(result.holidayName, 'Summer holiday');
  });
}
