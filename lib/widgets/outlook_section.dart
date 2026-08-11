import 'package:flutter/material.dart';

import '../services/one_drive_sync_service.dart';
import '../services/storage_service.dart';

class OutlookSection extends StatelessWidget {
  const OutlookSection({
    super.key,
    required this.upcomingOutlookEventsFuture,
    required this.loadUpcomingOutlookEvents,
    required this.isNarrow,
    required this.outlookLookAheadDays,
    required this.useWideWebOverviewColumns,
    required this.importedOutlookSummary,
    required this.onImportIcsCalendarFile,
    required this.formatOutlookDayDivider,
    required this.formatOutlookEventTimeRange,
    required this.formatOutlookEventDateRange,
    required this.isMultiDayOutlookEvent,
    required this.formatImportTimestamp,
    required this.formatImportDate,
  });

  final Future<List<OutlookCalendarEvent>>? upcomingOutlookEventsFuture;
  final Future<List<OutlookCalendarEvent>> Function() loadUpcomingOutlookEvents;
  final bool isNarrow;
  final int outlookLookAheadDays;
  final bool useWideWebOverviewColumns;
  final ImportedOutlookEventsSummary importedOutlookSummary;
  final VoidCallback onImportIcsCalendarFile;
  final String Function(DateTime day) formatOutlookDayDivider;
  final String Function(OutlookCalendarEvent event) formatOutlookEventTimeRange;
  final String Function(BuildContext context, OutlookCalendarEvent event)
  formatOutlookEventDateRange;
  final bool Function(OutlookCalendarEvent event) isMultiDayOutlookEvent;
  final String Function(BuildContext context, DateTime value)
  formatImportTimestamp;
  final String Function(BuildContext context, DateTime value) formatImportDate;

  bool _isOutlookEventCurrent(OutlookCalendarEvent event) {
    final start = event.start?.toLocal();
    if (start == null) {
      return false;
    }
    final current = DateTime.now().toLocal();

    if (event.isAllDay) {
      final startDay = DateTime(start.year, start.month, start.day);
      final rawEnd = event.end?.toLocal();
      final exclusiveEndDay = rawEnd == null
          ? startDay.add(const Duration(days: 1))
          : DateTime(rawEnd.year, rawEnd.month, rawEnd.day);
      final currentDay = DateTime(current.year, current.month, current.day);
      return !currentDay.isBefore(startDay) &&
          currentDay.isBefore(exclusiveEndDay);
    }

    final rawEnd = event.end?.toLocal();
    final effectiveEnd = rawEnd != null && rawEnd.isAfter(start)
        ? rawEnd
        : start.add(const Duration(minutes: 5));
    return !current.isBefore(start) && current.isBefore(effectiveEnd);
  }

  Widget _buildTimedEventCard(
    BuildContext context,
    OutlookCalendarEvent event,
  ) {
    final workColor = const Color(0xFF008E7A);
    final homeColor = const Color(0xFF1E63D0);
    final isWorkCalendarEvent = event.calendarSource == 'work';
    final isMultiDayEvent = isMultiDayOutlookEvent(event);
    final isCurrentEvent = _isOutlookEventCurrent(event);
    final cardColor = isWorkCalendarEvent
        ? workColor.withAlpha(44)
        : homeColor.withAlpha(44);
    final borderColor = isWorkCalendarEvent
        ? workColor.withAlpha(170)
        : homeColor.withAlpha(170);
    final badgeColor = isWorkCalendarEvent ? workColor : homeColor;
    final badgeLabel = isWorkCalendarEvent ? 'Work' : 'Home';
    final timeLabel = formatOutlookEventTimeRange(event);
    final detailsLabel = isMultiDayEvent
        ? '$timeLabel • ${formatOutlookEventDateRange(context, event)}'
        : timeLabel;

    final timeSplit = detailsLabel.split(' - ');
    final startLabel = timeSplit.isNotEmpty ? timeSplit.first : detailsLabel;
    final endLabel = timeSplit.length > 1 ? timeSplit[1] : '';

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 62,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  startLabel,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Colors.blueGrey.shade700,
                  ),
                ),
                if (endLabel.isNotEmpty)
                  Text(
                    endLabel,
                    style: TextStyle(
                      fontSize: 9,
                      color: Colors.blueGrey.shade500,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 2,
            margin: const EdgeInsets.only(top: 2),
            height: 74,
            decoration: BoxDecoration(
              color: badgeColor.withAlpha(isCurrentEvent ? 220 : 130),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              width: double.infinity,
              constraints: const BoxConstraints(minHeight: 80),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
              decoration: BoxDecoration(
                color: isCurrentEvent ? cardColor.withAlpha(74) : cardColor,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isCurrentEvent
                      ? badgeColor.withAlpha(255)
                      : borderColor,
                  width: isCurrentEvent ? 2.2 : 1,
                ),
                boxShadow: isCurrentEvent
                    ? [
                        BoxShadow(
                          color: badgeColor.withAlpha(90),
                          blurRadius: 12,
                          spreadRadius: 0.8,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          event.subject,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isCurrentEvent)
                        Container(
                          margin: const EdgeInsets.only(right: 4),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: badgeColor.withAlpha(230),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: const Text(
                            'NOW',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: badgeColor.withAlpha(40),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          badgeLabel,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: badgeColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final outlookEventsContent = FutureBuilder<List<OutlookCalendarEvent>>(
      future: upcomingOutlookEventsFuture ?? loadUpcomingOutlookEvents(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 10),
                Text('Loading Outlook events...'),
              ],
            ),
          );
        }

        if (snapshot.hasError) {
          return Text(
            'Outlook not connected yet. Use the cloud sync button above to link permissions.',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
          );
        }

        final events = snapshot.data ?? const <OutlookCalendarEvent>[];

        final baseHeight = isNarrow ? 220 : 280;
        final additionalPerDay = isNarrow ? 12 : 14;
        final maxHeightCap = isNarrow ? 300 : 360;
        final eventListMaxHeight =
            (baseHeight + ((outlookLookAheadDays - 1) * additionalPerDay))
                .clamp(baseHeight, maxHeightCap)
                .toDouble();

        final eventWidgets = <Widget>[];
        final eventsByDay = <DateTime, List<OutlookCalendarEvent>>{};
        final now = DateTime.now().toLocal();
        final firstDay = DateTime(now.year, now.month, now.day);
        final lastDay = firstDay.add(Duration(days: outlookLookAheadDays - 1));

        DateTime dateOnly(DateTime value) {
          return DateTime(value.year, value.month, value.day);
        }

        void addEventToDay(DateTime day, OutlookCalendarEvent event) {
          eventsByDay.putIfAbsent(day, () => <OutlookCalendarEvent>[]);
          eventsByDay[day]!.add(event);
        }

        for (final event in events) {
          final eventStart = event.start?.toLocal();
          if (eventStart == null) {
            continue;
          }

          if (event.isAllDay) {
            final startDay = dateOnly(eventStart);
            final rawEnd = event.end?.toLocal();
            final exclusiveEndDay = rawEnd == null
                ? startDay.add(const Duration(days: 1))
                : dateOnly(rawEnd);
            var inclusiveEndDay = exclusiveEndDay.subtract(
              const Duration(days: 1),
            );
            if (inclusiveEndDay.isBefore(startDay)) {
              inclusiveEndDay = startDay;
            }

            var cursor = startDay;
            while (!cursor.isAfter(inclusiveEndDay)) {
              if (!cursor.isBefore(firstDay) && !cursor.isAfter(lastDay)) {
                addEventToDay(cursor, event);
              }
              cursor = cursor.add(const Duration(days: 1));
            }
            continue;
          }

          final dayKey = dateOnly(eventStart);
          addEventToDay(dayKey, event);
        }

        final sortedDays = List<DateTime>.generate(
          outlookLookAheadDays,
          (offset) => firstDay.add(Duration(days: offset)),
        );

        final workColor = const Color(0xFF008E7A);
        final homeColor = const Color(0xFF1E63D0);
        final neutralColor = const Color(0xFF546E7A);

        for (var dayIndex = 0; dayIndex < sortedDays.length; dayIndex++) {
          final day = sortedDays[dayIndex];
          final dayEvents = eventsByDay[day] ?? const <OutlookCalendarEvent>[];
          final allDayEvents = dayEvents
              .where((event) => event.isAllDay)
              .toList();
          const maxAllDayChips = 4;
          final hasAllDayOverflow = allDayEvents.length > maxAllDayChips;
          final visibleAllDayLimit = hasAllDayOverflow
              ? maxAllDayChips - 1
              : maxAllDayChips;
          final visibleAllDayEvents = allDayEvents
              .take(visibleAllDayLimit)
              .toList();
          final hiddenAllDayCount =
              allDayEvents.length - visibleAllDayEvents.length;
          final timedEvents = dayEvents
              .where((event) => !event.isAllDay)
              .toList();
          timedEvents.sort((a, b) {
            final aStart = a.start?.toLocal();
            final bStart = b.start?.toLocal();
            if (aStart == null && bStart == null) return 0;
            if (aStart == null) return 1;
            if (bStart == null) return -1;
            return aStart.compareTo(bStart);
          });
          final isStripedDay = dayIndex.isOdd;
          final daySurfaceColor = isStripedDay
              ? const Color(0xFFF8FBFF)
              : Colors.white;
          final dayBorderColor = isStripedDay
              ? const Color(0xFFD3E3FB)
              : const Color(0xFFE3ECFA);

          if (eventWidgets.isNotEmpty) {
            eventWidgets.add(const SizedBox(height: 2));
          }
          eventWidgets.add(
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Container(
                width: double.infinity,
                constraints: const BoxConstraints(minHeight: 72),
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: daySurfaceColor,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: dayBorderColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE7F0FF),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 26,
                            height: 26,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: const Color(0xFFBED2F6),
                              ),
                            ),
                            child: Text(
                              day.day.toString(),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: Colors.blue.shade900,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              formatOutlookDayDivider(day),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: Colors.blue.shade900,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    if (allDayEvents.isNotEmpty) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: neutralColor.withAlpha(36),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: neutralColor.withAlpha(130),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'All-day',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: neutralColor,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ...visibleAllDayEvents.asMap().entries.map((
                                  entry,
                                ) {
                                  final index = entry.key;
                                  final event = entry.value;
                                  final isWorkCalendarEvent =
                                      event.calendarSource == 'work';
                                  final isCurrentEvent = _isOutlookEventCurrent(
                                    event,
                                  );
                                  final eventColor = isWorkCalendarEvent
                                      ? workColor
                                      : homeColor;
                                  return Expanded(
                                    child: Padding(
                                      padding: EdgeInsets.only(
                                        right:
                                            index ==
                                                    visibleAllDayEvents.length -
                                                        1 &&
                                                !hasAllDayOverflow
                                            ? 0
                                            : 4,
                                      ),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isCurrentEvent
                                              ? eventColor.withAlpha(72)
                                              : eventColor.withAlpha(44),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          border: Border.all(
                                            color: eventColor.withAlpha(
                                              isCurrentEvent ? 255 : 170,
                                            ),
                                            width: isCurrentEvent ? 2.2 : 1,
                                          ),
                                          boxShadow: isCurrentEvent
                                              ? [
                                                  BoxShadow(
                                                    color: eventColor.withAlpha(
                                                      80,
                                                    ),
                                                    blurRadius: 10,
                                                    spreadRadius: 0.6,
                                                    offset: const Offset(0, 2),
                                                  ),
                                                ]
                                              : null,
                                        ),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              event.subject,
                                              maxLines: 3,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700,
                                                color: Colors.black,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 6,
                                                    vertical: 1,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: Colors.white.withAlpha(
                                                  210,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(999),
                                                border: Border.all(
                                                  color: eventColor.withAlpha(
                                                    140,
                                                  ),
                                                ),
                                              ),
                                              child: Text(
                                                isWorkCalendarEvent
                                                    ? 'Work'
                                                    : 'Home',
                                                style: const TextStyle(
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.w700,
                                                  color: Colors.black,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                }),
                                if (hasAllDayOverflow)
                                  Expanded(
                                    child: Container(
                                      height: 80,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 7,
                                      ),
                                      decoration: BoxDecoration(
                                        color: neutralColor.withAlpha(44),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: neutralColor.withAlpha(150),
                                        ),
                                      ),
                                      child: Text(
                                        '+$hiddenAllDayCount more',
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          color: neutralColor,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                    ],
                    if (timedEvents.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F8FF),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          allDayEvents.isEmpty
                              ? 'No events for this day.'
                              : 'No timed events for this day.',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ),
                    ...timedEvents.map(
                      (event) => _buildTimedEventCard(context, event),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        final eventsList = SingleChildScrollView(
          child: Column(children: eventWidgets),
        );

        if (useWideWebOverviewColumns) {
          return eventsList;
        }

        return SizedBox(height: eventListMaxHeight, child: eventsList);
      },
    );

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FBFF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFC7D8F6)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: Colors.blue.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.calendar_view_day,
                  size: 16,
                  color: Colors.blue.shade900,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Outlook Calendar',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      'Agenda view for next $outlookLookAheadDays ${outlookLookAheadDays == 1 ? 'day' : 'days'}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.blueGrey.shade700,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: const Color(0xFFC7D8F6)),
                ),
                child: Text(
                  '$outlookLookAheadDays-day',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Colors.blueGrey.shade700,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              TextButton.icon(
                onPressed: onImportIcsCalendarFile,
                icon: const Icon(Icons.upload_file, size: 16),
                label: const Text('Import .ics'),
              ),
            ],
          ),
          Align(
            alignment: Alignment.centerRight,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 14,
                  color: Colors.blue.shade500.withAlpha(170),
                ),
                const SizedBox(width: 2),
                Text(
                  'scroll',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Colors.blue.shade500.withAlpha(170),
                  ),
                ),
              ],
            ),
          ),
          if (importedOutlookSummary.hasImport) ...[
            const SizedBox(height: 4),
            Text(
              'Last import: ${formatImportTimestamp(context, importedOutlookSummary.lastImportedAt!)} (${importedOutlookSummary.eventCount} events)',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
            ),
            if (importedOutlookSummary.rangeStart != null &&
                importedOutlookSummary.rangeEnd != null)
              Text(
                'Imported date range: ${formatImportDate(context, importedOutlookSummary.rangeStart!)} to ${formatImportDate(context, importedOutlookSummary.rangeEnd!)}',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
              ),
          ],
          const SizedBox(height: 6),
          if (useWideWebOverviewColumns)
            Expanded(child: outlookEventsContent)
          else
            outlookEventsContent,
        ],
      ),
    );
  }
}
