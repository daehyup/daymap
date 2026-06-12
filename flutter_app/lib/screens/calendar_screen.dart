import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../widgets/progress_card.dart';
import '../widgets/streak_widget.dart';
import 'day_detail_screen.dart';

class CalendarScreen extends StatefulWidget {
  final DateTime initialMonth;

  const CalendarScreen({super.key, required this.initialMonth});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  late DateTime _visibleMonth;
  Map<String, dynamic>? _calendar;
  List<Map<String, dynamic>> _progressCards = [];
  int _currentStreak = 0;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _visibleMonth =
        DateTime(widget.initialMonth.year, widget.initialMonth.month);
    _autoRedistribute();
    _loadCalendar();
  }

  Future<void> _autoRedistribute() async {
    try {
      final result = await ApiService.redistributeTasks();
      final count = result['rescheduled_count'] as int? ?? 0;
      if (count > 0 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('어제 못 한 $count개 할일을 자동으로 재배분했어요'),
            backgroundColor: const Color(0xFF6C63FF),
            behavior: SnackBarBehavior.floating,
          ),
        );
        _loadCalendar();
      }
    } catch (_) {
      // 자동 재배분 실패는 조용히 무시
    }
  }

  Future<void> _loadCalendar() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final results = await Future.wait([
        ApiService.getMonthlyCalendar(
          year: _visibleMonth.year,
          month: _visibleMonth.month,
        ),
        ApiService.getStreak(),
      ]);
      if (!mounted) return;
      setState(() {
        _calendar = results[0];
        _currentStreak = (results[1]['current_streak'] as num?)?.toInt() ?? 0;
      });

      try {
        final progress = await ApiService.getProgress();
        if (!mounted) return;
        setState(() {
          _progressCards = List<Map<String, dynamic>>.from(
            progress['cards'] as List? ?? [],
          );
        });
      } catch (_) {
        // 카드 로드 실패는 조용히 무시
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _errorMessage = '월간 일정을 불러오지 못했어요.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _moveMonth(int delta) {
    setState(() {
      _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month + delta);
    });
    _loadCalendar();
  }

  Future<void> _openDay(DateTime date) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => DayDetailScreen(date: date)),
    );
    if (mounted) _loadCalendar();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 8,
        title: Row(
          children: [
            IconButton(
              tooltip: '이전 달',
              onPressed: () => _moveMonth(-1),
              icon: const Icon(Icons.chevron_left),
            ),
            Text(
              '${_visibleMonth.month}월',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            IconButton(
              tooltip: '다음 달',
              onPressed: () => _moveMonth(1),
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: StreakWidget(streak: _currentStreak),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorMessage != null) {
      return _ErrorView(message: _errorMessage!, onRetry: _loadCalendar);
    }

    final days =
        List<Map<String, dynamic>>.from(_calendar?['days'] as List? ?? []);
    return RefreshIndicator(
      onRefresh: _loadCalendar,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
          _buildProgressSection(),
          if (_progressCards.isNotEmpty) const SizedBox(height: 18),
          const _WeekHeader(),
          const SizedBox(height: 8),
          _CalendarGrid(
            month: _visibleMonth,
            days: days,
            onTapDay: _openDay,
          ),
          const SizedBox(height: 24),
          _MonthSummary(days: days),
        ],
      ),
    );
  }

  Widget _buildProgressSection() {
    if (_progressCards.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 150,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _progressCards.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final card = _progressCards[index];
          return ProgressCard(
            eventTitle: card['event_title'] as String? ?? '',
            eventType: card['event_type'] as String? ?? 'goal',
            color: card['color'] as String? ?? 'green',
            daysUntilDeadline: card['days_until_deadline'] as int?,
            completionRate:
                (card['completion_rate'] as num?)?.toDouble() ?? 0.0,
            totalTasks: card['total_tasks'] as int? ?? 0,
            completedTasks: card['completed_tasks'] as int? ?? 0,
            status: card['status'] as String? ?? 'on_track',
            statusLabel: card['status_label'] as String? ?? '순조',
            message: card['message'] as String? ?? '',
          );
        },
      ),
    );
  }
}

class _WeekHeader extends StatelessWidget {
  const _WeekHeader();

  @override
  Widget build(BuildContext context) {
    const labels = ['일', '월', '화', '수', '목', '금', '토'];
    return Row(
      children: labels
          .map(
            (label) => Expanded(
              child: Center(
                child: Text(
                  label,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _CalendarGrid extends StatelessWidget {
  final DateTime month;
  final List<Map<String, dynamic>> days;
  final ValueChanged<DateTime> onTapDay;

  const _CalendarGrid({
    required this.month,
    required this.days,
    required this.onTapDay,
  });

  @override
  Widget build(BuildContext context) {
    final firstDay = DateTime(month.year, month.month);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final leadingBlankCount = firstDay.weekday % 7;
    final cellCount = ((leadingBlankCount + daysInMonth + 6) ~/ 7) * 7;
    final daysByDate = {
      for (final day in days) day['date']?.toString() ?? '': day,
    };

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: cellCount,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        mainAxisSpacing: 6,
        crossAxisSpacing: 6,
        childAspectRatio: 0.82,
      ),
      itemBuilder: (context, index) {
        final dayNumber = index - leadingBlankCount + 1;
        if (dayNumber < 1 || dayNumber > daysInMonth) {
          return const SizedBox.shrink();
        }
        final date = DateTime(month.year, month.month, dayNumber);
        final key = _dateKey(date);
        final dayData = daysByDate[key] ?? <String, dynamic>{};
        return _DayCell(
          date: date,
          data: dayData,
          onTap: () => onTapDay(date),
        );
      },
    );
  }
}

class _DayCell extends StatelessWidget {
  final DateTime date;
  final Map<String, dynamic> data;
  final VoidCallback onTap;

  const _DayCell({
    required this.date,
    required this.data,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final isToday = date.year == today.year &&
        date.month == today.month &&
        date.day == today.day;
    final tasks = List<Map<String, dynamic>>.from(data['tasks'] as List? ?? []);
    final colors = _dotColors(tasks, data['has_deadline'] == true);

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color:
              isToday ? Theme.of(context).colorScheme.primaryContainer : null,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isToday
                ? Theme.of(context).colorScheme.primary
                : Colors.grey.shade200,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${date.day}',
              style: TextStyle(
                fontWeight: isToday ? FontWeight.bold : FontWeight.w500,
                color: isToday
                    ? Theme.of(context).colorScheme.onPrimaryContainer
                    : null,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 8,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: colors
                    .take(3)
                    .map(
                      (color) => Container(
                        width: 6,
                        height: 6,
                        margin: const EdgeInsets.symmetric(horizontal: 1.5),
                        decoration:
                            BoxDecoration(color: color, shape: BoxShape.circle),
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Color> _dotColors(List<Map<String, dynamic>> tasks, bool hasDeadline) {
    final result = <Color>[];
    if (hasDeadline) result.add(const Color(0xFFE5484D));
    for (final task in tasks) {
      final color = task['event_color']?.toString() ?? 'green';
      final mapped = switch (color) {
        'red' => const Color(0xFFE5484D),
        'blue' => const Color(0xFF3772FF),
        'orange' => const Color(0xFFF59E0B),
        _ => const Color(0xFF22A06B),
      };
      if (!result.contains(mapped)) result.add(mapped);
    }
    return result;
  }
}

class _MonthSummary extends StatelessWidget {
  final List<Map<String, dynamic>> days;

  const _MonthSummary({required this.days});

  @override
  Widget build(BuildContext context) {
    final tasks = days
        .expand((day) =>
            List<Map<String, dynamic>>.from(day['tasks'] as List? ?? []))
        .toList();
    final completed =
        tasks.where((task) => task['is_completed'] == true).length;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '이번 달 요약',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text('총 ${tasks.length}개 할일 · 완료 $completed개'),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.calendar_month_outlined,
                size: 56, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(message, style: TextStyle(color: Colors.grey.shade600)),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('다시 시도'),
            ),
          ],
        ),
      ),
    );
  }
}

String _dateKey(DateTime date) {
  final year = date.year.toString().padLeft(4, '0');
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}
