import 'package:flutter/material.dart' hide DateUtils;
import 'package:flutter/rendering.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';

import 'extensions.dart';
import 'models.dart';
import 'types.dart';
import 'utils.dart';

/// enum indicating the pagination enpoint direction
enum PaginationDirection {
  up,
  down,
}

/// a minimalistic paginated calendar widget providing infinite customisation
/// options and usefull paginated callbacks. all paremeters are optional.
///
/// ```
/// PagedVerticalCalendar(
///       startDate: DateTime(2021, 1, 1),
///       endDate: DateTime(2021, 12, 31),
///       onDayPressed: (day) {
///            print('Date selected: $day');
///          },
///          onMonthLoaded: (year, month) {
///            print('month loaded: $month-$year');
///          },
///          onPaginationCompleted: () {
///            print('end reached');
///          },
///        ),
/// ```
class PagedVerticalCalendar extends StatefulWidget {
  PagedVerticalCalendar({
    this.minDate,
    this.maxDate,
    this.initialDate,
    this.monthBuilder,
    this.dayBuilder,
    this.addAutomaticKeepAlives = false,
    this.onDayPressed,
    this.onMonthLoaded,
    this.onPaginationCompleted,
    this.invisibleMonthsThreshold = 1,
    this.physics,
    this.scrollController,
    this.listPadding = EdgeInsets.zero,
    this.startWeekWithSunday = false,
  });

  /// the [DateTime] to start the calendar from, if no [startDate] is provided
  /// `DateTime.now()` will be used
  final DateTime? minDate;

  /// optional [DateTime] to end the calendar pagination, of no [endDate] is
  /// provided the calendar can paginate indefinitely
  final DateTime? maxDate;

  /// the initial date displayed by the calendar.
  /// if inititial date is nulll, the start date will be used
  final DateTime? initialDate;

  /// a Builder used for month header generation. a default [MonthBuilder] is
  /// used when no custom [MonthBuilder] is provided.
  /// * [context]
  /// * [int] year: 2021
  /// * [int] month: 1-12
  final MonthBuilder? monthBuilder;

  /// a Builder used for day generation. a default [DayBuilder] is
  /// used when no custom [DayBuilder] is provided.
  /// * [context]
  /// * [DateTime] date
  final DayBuilder? dayBuilder;

  /// if the calendar should stay cached when the widget is no longer loaded.
  /// this can be used for maintaining the last state. defaults to `false`
  final bool addAutomaticKeepAlives;

  /// callback that provides the [DateTime] of the day that's been interacted
  /// with
  final ValueChanged<DateTime>? onDayPressed;

  /// callback when a new paginated month is loaded.
  final OnMonthLoaded? onMonthLoaded;

  /// called when the calendar pagination is completed. if no [minDate] or [maxDate] is
  /// provided this method is never called for that direction
  final ValueChanged<PaginationDirection>? onPaginationCompleted;

  /// how many months should be loaded outside of the view. defaults to `1`
  final int invisibleMonthsThreshold;

  /// list padding, defaults to `EdgeInsets.zero`
  final EdgeInsetsGeometry listPadding;

  /// scroll physics, defaults to matching platform conventions
  final ScrollPhysics? physics;

  /// scroll controller for making programmable scroll interactions
  final ScrollController? scrollController;

  /// Select start day of the week to be Sunday
  final bool startWeekWithSunday;

  @override
  _PagedVerticalCalendarState createState() => _PagedVerticalCalendarState();
}

class _PagedVerticalCalendarState extends State<PagedVerticalCalendar> {
  late PagingController<int, Month> _pagingUpController;
  late PagingController<int, Month> _pagingDownController;

  final Key centerKey = UniqueKey();

  late DateTime initialDate;
  late DateTime? minDate;
  late DateTime? maxDate;

  bool get canScrollUp {
    if (minDate == null) return true;
    return initialDate.isAfter(minDate!);
  }

  bool get canScrollDown {
    if (maxDate == null) return true;
    return initialDate.isBefore(maxDate!);
  }

  @override
  void initState() {
    super.initState();

    initialDate = _calculateInitialDate();
    minDate = widget.minDate;
    maxDate = widget.maxDate;

    _pagingUpController = PagingController<int, Month>(
      firstPageKey: 0,
      invisibleItemsThreshold: widget.invisibleMonthsThreshold,
    );
    _pagingUpController.addPageRequestListener(_fetchPreviousPage);
    _pagingUpController.addStatusListener(paginationStatusUp);

    _pagingDownController = PagingController<int, Month>(
      firstPageKey: 0,
      invisibleItemsThreshold: widget.invisibleMonthsThreshold,
    );
    _pagingDownController.addPageRequestListener(_fetchNextPage);
    _pagingDownController.addStatusListener(paginationStatusDown);
  }

  @override
  void didUpdateWidget(covariant PagedVerticalCalendar oldWidget) {
    super.didUpdateWidget(oldWidget);

    initialDate = _calculateInitialDate();
    minDate = widget.minDate;
    maxDate = widget.maxDate;

    if (oldWidget.minDate != widget.minDate ||
        oldWidget.maxDate != widget.maxDate ||
        oldWidget.initialDate != widget.initialDate) {
      _pagingDownController.refresh();
      _pagingUpController.refresh();
    }
  }

  DateTime _calculateInitialDate() {
    if (widget.initialDate != null) return widget.initialDate!;
    final today = DateTime.now().removeTime();

    if (widget.minDate != null && today.isBefore(widget.minDate!)) {
      return widget.minDate!;
    }

    if (widget.maxDate != null && today.isAfter(widget.maxDate!)) {
      return widget.maxDate!;
    }

    return today;
  }

  void paginationStatusUp(PagingStatus state) {
    if (state == PagingStatus.completed)
      return widget.onPaginationCompleted?.call(PaginationDirection.up);
  }

  void paginationStatusDown(PagingStatus state) {
    if (state == PagingStatus.completed)
      return widget.onPaginationCompleted?.call(PaginationDirection.down);
  }

  /// fetch a new [Month] object based on the [pageKey] which is the Nth month
  /// from the start date
  void _fetchPreviousPage(int pageKey) async {
    try {
      final month = DateUtils.getMonth(
        startDate: DateTime(initialDate.year, initialDate.month - 1, 1),
        endDate: minDate,
        monthsFromStartDate: pageKey,
        startWeekWithSunday: widget.startWeekWithSunday,
      );

      WidgetsBinding.instance.addPostFrameCallback(
        (_) => widget.onMonthLoaded?.call(month.year, month.month),
      );

      final isLastPage = minDate != null &&
          minDate!.isSameDayOrAfter(month.weeks.first.firstDay);

      if (isLastPage) {
        return _pagingUpController.appendLastPage([month]);
      }

      final nextPageKey = pageKey - 1;
      _pagingUpController.appendPage([month], nextPageKey);
    } catch (_) {
      _pagingUpController.error;
    }
  }

  void _fetchNextPage(int pageKey) async {
    try {
      final month = DateUtils.getMonth(
        startDate: DateTime(initialDate.year, initialDate.month, 1),
        endDate: maxDate,
        monthsFromStartDate: pageKey,
        startWeekWithSunday: widget.startWeekWithSunday,
      );

      WidgetsBinding.instance.addPostFrameCallback(
        (_) => widget.onMonthLoaded?.call(month.year, month.month),
      );

      final isLastPage = maxDate != null &&
          maxDate!.isSameDayOrBefore(month.weeks.last.lastDay);

      if (isLastPage) {
        return _pagingDownController.appendLastPage([month]);
      }

      final nextPageKey = pageKey + 1;
      _pagingDownController.appendPage([month], nextPageKey);
    } catch (_) {
      _pagingDownController.error;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scrollable(
      controller: widget.scrollController,
      viewportBuilder: (BuildContext context, ViewportOffset position) {
        return Viewport(
          offset: position,
          center: centerKey,
          slivers: [
            if (canScrollUp)
              PagedSliverList(
                pagingController: _pagingUpController,
                builderDelegate: PagedChildBuilderDelegate<Month>(
                  itemBuilder: (BuildContext context, Month month, int index) {
                    return _MonthView(
                      month: month,
                      monthBuilder: widget.monthBuilder,
                      dayBuilder: widget.dayBuilder,
                      onDayPressed: widget.onDayPressed,
                      startWeekWithSunday: widget.startWeekWithSunday,
                    );
                  },
                ),
              ),
            SliverToBoxAdapter(
              key: centerKey,
              child: SizedBox.shrink(),
            ),
            if (canScrollDown)
              PagedSliverList(
                pagingController: _pagingDownController,
                builderDelegate: PagedChildBuilderDelegate<Month>(
                  itemBuilder: (BuildContext context, Month month, int index) {
                    return _MonthView(
                      month: month,
                      monthBuilder: widget.monthBuilder,
                      dayBuilder: widget.dayBuilder,
                      onDayPressed: widget.onDayPressed,
                      startWeekWithSunday: widget.startWeekWithSunday,
                    );
                  },
                ),
              ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _pagingUpController.dispose();
    _pagingDownController.dispose();
    super.dispose();
  }
}

/// builds an widget from a [Month] instance
class _MonthView extends StatelessWidget {
  _MonthView({
    required this.month,
    this.monthBuilder,
    this.dayBuilder,
    this.onDayPressed,
    required this.startWeekWithSunday,
  });

  final Month month;
  final MonthBuilder? monthBuilder;
  final DayBuilder? dayBuilder;
  final ValueChanged<DateTime>? onDayPressed;
  final bool startWeekWithSunday;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        /// display the default month header if none is provided
        monthBuilder?.call(context, month.month, month.year) ??
            _DefaultMonthView(
              month: month.month,
              year: month.year,
            ),
        Table(
          children: month.weeks.map((Week week) {
            return _generateWeekRow(context, week, startWeekWithSunday);
          }).toList(growable: false),
        ),
        SizedBox(
          height: 20,
        ),
      ],
    );
  }

  TableRow _generateWeekRow(
      BuildContext context, Week week, bool startWeekWithSunday) {
    DateTime firstDay = week.firstDay;

    return TableRow(
      children: List<Widget>.generate(
        DateTime.daysPerWeek,
        (int position) {
          DateTime day = DateTime(
            week.firstDay.year,
            week.firstDay.month,
            firstDay.day +
                (position -
                    (DateUtils.getWeekDay(firstDay, startWeekWithSunday) - 1)),
          );

          if ((position + 1) <
                  DateUtils.getWeekDay(week.firstDay, startWeekWithSunday) ||
              (position + 1) >
                  DateUtils.getWeekDay(week.lastDay, startWeekWithSunday)) {
            return const SizedBox();
          } else {
            return AspectRatio(
              aspectRatio: 1.0,
              child: InkWell(
                onTap: onDayPressed == null ? null : () => onDayPressed!(day),
                child: dayBuilder?.call(context, day) ??
                    _DefaultDayView(date: day),
              ),
            );
          }
        },
        growable: false,
      ),
    );
  }
}

/// default widget used for building months
class _DefaultMonthView extends StatelessWidget {
  final int month;
  final int year;

  _DefaultMonthView({required this.month, required this.year});

  final months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Text(
        '${months[month - 1]} $year',
        style: Theme.of(context).textTheme.headline6,
      ),
    );
  }
}

/// default widget used for building months
class _DefaultDayView extends StatelessWidget {
  final DateTime date;

  _DefaultDayView({required this.date});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        date.day.toString(),
      ),
    );
  }
}
