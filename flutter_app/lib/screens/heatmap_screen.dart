import 'package:flutter/material.dart';

import '../services/api_service.dart';
import 'day_detail_screen.dart';

class HeatmapScreen extends StatefulWidget {
  const HeatmapScreen({super.key});

  @override
  State<HeatmapScreen> createState() => _HeatmapScreenState();
}

class _HeatmapScreenState extends State<HeatmapScreen> {
  static const _levelColors = [
    Color(0xFFEEEEEE),
    Color(0xFFD4CCFF),
    Color(0xFF9F94F0),
    Color(0xFF6C63FF),
    Color(0xFF4B44CC),
  ];

  final int _year = DateTime.now().year;
  Map<String, Map<String, dynamic>> _daysByDate = {};
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadHeatmap();
  }

  Future<void> _loadHeatmap() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final data = await ApiService.getHeatmap(year: _year);
      final days = List<Map<String, dynamic>>.from(data['days'] as List? ?? []);
      if (!mounted) return;
      setState(() {
        _daysByDate = {
          for (final day in days) day['date']?.toString() ?? '': day,
        };
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _errorMessage = '활동 기록을 불러오지 못했어요.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('$_year년 활동 기록'),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_errorMessage != null) {
      return _ErrorView(message: _errorMessage!, onRetry: _loadHeatmap);
    }

    return RefreshIndicator(
      onRefresh: _loadHeatmap,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          _YearSummary(days: _daysByDate.values.toList()),
          const SizedBox(height: 20),
          for (var month = 1; month <= 12; month++) ...[
            _MonthHeatmap(
              year: _year,
              month: month,
              daysByDate: _daysByDate,
              levelColors: _levelColors,
              onTapDate: _openDay,
            ),
            const SizedBox(height: 24),
          ],
          const _Legend(levelColors: _levelColors),
        ],
      ),
    );
  }

  Future<void> _openDay(DateTime date) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => DayDetailScreen(date: date)),
    );
    if (mounted) _loadHeatmap();
  }
}

class _YearSummary extends StatelessWidget {
  final List<Map<String, dynamic>> days;

  const _YearSummary({required this.days});

  @override
  Widget build(BuildContext context) {
    final total = days.fold<int>(
      0,
      (sum, day) => sum + ((day['total'] as num?)?.toInt() ?? 0),
    );
    final completed = days.fold<int>(
      0,
      (sum, day) => sum + ((day['completed'] as num?)?.toInt() ?? 0),
    );
    final rate = total == 0 ? 0 : ((completed / total) * 100).round();

    return Container(
      padding: const EdgeInsets.all(16),
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
            '이번 해 총 요약',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text('$completed개 완료 · 달성률 $rate%'),
        ],
      ),
    );
  }
}

class _MonthHeatmap extends StatelessWidget {
  final int year;
  final int month;
  final Map<String, Map<String, dynamic>> daysByDate;
  final List<Color> levelColors;
  final ValueChanged<DateTime> onTapDate;

  const _MonthHeatmap({
    required this.year,
    required this.month,
    required this.daysByDate,
    required this.levelColors,
    required this.onTapDate,
  });

  @override
  Widget build(BuildContext context) {
    final firstDay = DateTime(year, month);
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final leadingBlankCount = firstDay.weekday % 7;
    final cellCount = ((leadingBlankCount + daysInMonth + 6) ~/ 7) * 7;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$month월',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        const _WeekLabels(),
        const SizedBox(height: 6),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: cellCount,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisSpacing: 3,
            crossAxisSpacing: 3,
            childAspectRatio: 1,
          ),
          itemBuilder: (context, index) {
            final dayNumber = index - leadingBlankCount + 1;
            if (dayNumber < 1 || dayNumber > daysInMonth) {
              return const SizedBox.shrink();
            }

            final date = DateTime(year, month, dayNumber);
            final data = daysByDate[_dateKey(date)];
            final level = ((data?['level'] as num?)?.toInt() ?? 0).clamp(0, 4);
            final total = (data?['total'] as num?)?.toInt() ?? 0;
            final completed = (data?['completed'] as num?)?.toInt() ?? 0;

            return Tooltip(
              message: '${date.month}/${date.day} · $completed/$total 완료',
              child: InkWell(
                borderRadius: BorderRadius.circular(3),
                onTap: () => onTapDate(date),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: levelColors[level],
                    borderRadius: BorderRadius.circular(3),
                    border: Border.all(color: Colors.black12, width: 0.5),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _WeekLabels extends StatelessWidget {
  const _WeekLabels();

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
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _Legend extends StatelessWidget {
  final List<Color> levelColors;

  const _Legend({required this.levelColors});

  @override
  Widget build(BuildContext context) {
    const labels = ['없음', '낮음', '보통', '높음', '완료'];
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      children: List.generate(
        labels.length,
        (index) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: levelColors[index],
                borderRadius: BorderRadius.circular(3),
                border: Border.all(color: Colors.black12, width: 0.5),
              ),
            ),
            const SizedBox(width: 5),
            Text(labels[index], style: const TextStyle(fontSize: 12)),
          ],
        ),
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.bar_chart_outlined, size: 56, color: Colors.grey.shade400),
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
    );
  }
}

String _dateKey(DateTime date) {
  final year = date.year.toString().padLeft(4, '0');
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}
