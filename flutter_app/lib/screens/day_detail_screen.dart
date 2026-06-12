import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../widgets/task_card.dart';

class DayDetailScreen extends StatefulWidget {
  final DateTime date;

  const DayDetailScreen({super.key, required this.date});

  @override
  State<DayDetailScreen> createState() => _DayDetailScreenState();
}

class _DayDetailScreenState extends State<DayDetailScreen> {
  List<Map<String, dynamic>> _tasks = [];
  String _summary = '';
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadDay();
  }

  Future<void> _loadDay() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final data = await ApiService.getDayDetail(date: _dateKey(widget.date));
      if (!mounted) return;
      setState(() {
        _tasks = List<Map<String, dynamic>>.from(data['tasks'] as List? ?? []);
        _summary = data['summary']?.toString() ?? '';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _errorMessage = '이날 할일을 불러오지 못했어요.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _completeTask(int index) async {
    final task = _tasks[index];
    if (task['is_completed'] == true) return;

    setState(() => _tasks[index] = {...task, 'is_completed': true});
    try {
      await ApiService.completeTask(task['id'].toString());
      await _loadDay();
    } catch (_) {
      if (!mounted) return;
      setState(() => _tasks[index] = task);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('완료 처리에 실패했어요.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_titleText(widget.date)),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_errorMessage != null) {
      return _ErrorView(message: _errorMessage!, onRetry: _loadDay);
    }
    if (_tasks.isEmpty) {
      return const Center(child: Text('이날 할일이 없어요.'));
    }

    return RefreshIndicator(
      onRefresh: _loadDay,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          _SummaryChip(text: _summary),
          const SizedBox(height: 16),
          ..._tasks.asMap().entries.map(
                (entry) => TaskCard(
                  title: entry.value['title']?.toString() ?? '(제목 없음)',
                  time: entry.value['scheduled_at']?.toString() ?? '',
                  isDone: entry.value['is_completed'] == true,
                  eventColor: entry.value['event_color']?.toString() ?? 'green',
                  durationMinutes:
                      ((entry.value['duration_minutes'] as num?)?.toInt() ?? 0),
                  onToggle: () => _completeTask(entry.key),
                ),
              ),
        ],
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  final String text;

  const _SummaryChip({required this.text});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.secondaryContainer,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          text.isEmpty ? '요약 없음' : text,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSecondaryContainer,
            fontWeight: FontWeight.w600,
          ),
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
          Icon(Icons.event_busy_outlined,
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
    );
  }
}

String _titleText(DateTime date) {
  const weekdays = ['월', '화', '수', '목', '금', '토', '일'];
  return '${date.month}월 ${date.day}일 ${weekdays[date.weekday - 1]}요일';
}

String _dateKey(DateTime date) {
  final year = date.year.toString().padLeft(4, '0');
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}
