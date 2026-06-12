import 'package:flutter/material.dart';
import '../widgets/task_card.dart';
import '../widgets/streak_widget.dart';
import '../services/api_service.dart';

class TodayScreen extends StatefulWidget {
  const TodayScreen({super.key});

  @override
  State<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends State<TodayScreen> {
  List<Map<String, dynamic>> _tasks = [];
  int _currentStreak = 0;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final results = await Future.wait([
        ApiService.getTodayTasks(),
        ApiService.getStreak(),
      ]);
      if (!mounted) return;
      setState(() {
        _tasks = results[0] as List<Map<String, dynamic>>;
        _currentStreak =
            ((results[1] as Map<String, dynamic>)['current_streak'] as num?)
                    ?.toInt() ??
                0;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = '일정을 불러오지 못했어요.\n잠시 후 다시 시도해주세요.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadTasks() => _loadAll();

  Future<void> _toggleTask(int index) async {
    final task = _tasks[index];
    final taskId = task['id']?.toString() ?? '';
    final wasCompleted = task['is_completed'] == true;

    // 낙관적 업데이트
    setState(() => _tasks[index] = {...task, 'is_completed': !wasCompleted});

    try {
      if (!wasCompleted) await ApiService.completeTask(taskId);
    } catch (_) {
      if (!mounted) return;
      // 실패 시 롤백
      setState(() => _tasks[index] = {...task, 'is_completed': wasCompleted});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('완료 처리에 실패했어요. 다시 시도해주세요.')),
      );
    }
  }

  int get _completedCount =>
      _tasks.where((t) => t['is_completed'] == true).length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('오늘의 일정'),
        centerTitle: false,
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
    if (_isLoading) return const _LoadingView();
    if (_errorMessage != null) {
      return _ErrorView(message: _errorMessage!, onRetry: _loadTasks);
    }
    if (_tasks.isEmpty) return const _EmptyView();

    return RefreshIndicator(
      onRefresh: _loadTasks,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: _ProgressHeader(
              completed: _completedCount,
              total: _tasks.length,
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final task = _tasks[index];
                  return TaskCard(
                    title: task['title']?.toString() ?? '(제목 없음)',
                    time: task['scheduled_at']?.toString() ?? '',
                    isDone: task['is_completed'] == true,
                    onToggle: () => _toggleTask(index),
                  );
                },
                childCount: _tasks.length,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressHeader extends StatelessWidget {
  final int completed;
  final int total;

  const _ProgressHeader({required this.completed, required this.total});

  @override
  Widget build(BuildContext context) {
    final ratio = total == 0 ? 0.0 : completed / total;
    final colors = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                completed == total && total > 0 ? '모든 일정 완료! 🎉' : '오늘의 진행 현황',
                style:
                    const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
              ),
              Text(
                '$completed / $total',
                style: TextStyle(
                  color: colors.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 8,
              backgroundColor: colors.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation(colors.primary),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('일정을 불러오는 중...', style: TextStyle(color: Colors.grey)),
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
            Icon(Icons.cloud_off_rounded,
                size: 56, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600, height: 1.6),
            ),
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

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.today_outlined, size: 56, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            const Text(
              '오늘 일정이 없어요.',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              '일정 입력 탭에서 할 일을 추가해보세요.',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }
}
