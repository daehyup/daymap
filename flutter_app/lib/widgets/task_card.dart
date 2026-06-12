import 'package:flutter/material.dart';

class TaskCard extends StatefulWidget {
  final String title;
  final String time;
  final bool isDone;
  final VoidCallback? onToggle;
  final String eventColor;
  final int durationMinutes;

  const TaskCard({
    super.key,
    required this.title,
    required this.time,
    required this.isDone,
    this.onToggle,
    this.eventColor = 'green',
    this.durationMinutes = 0,
  });

  @override
  State<TaskCard> createState() => _TaskCardState();
}

class _TaskCardState extends State<TaskCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _scaleAnim = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.35), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.35, end: 0.9), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 0.9, end: 1.0), weight: 30),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
  }

  @override
  void didUpdateWidget(TaskCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.isDone && widget.isDone) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(bottom: 12),
      child: Card(
        elevation: widget.isDone ? 0 : 2,
        color: widget.isDone
            ? colors.surfaceContainerHighest.withValues(alpha: 0.5)
            : null,
        clipBehavior: Clip.antiAlias,
        child: Row(
          children: [
            Container(width: 4, height: 76, color: _eventColor()),
            Expanded(
              child: ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                leading: GestureDetector(
                  onTap: widget.onToggle,
                  child: ScaleTransition(
                    scale: _scaleAnim,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color:
                            widget.isDone ? colors.primary : Colors.transparent,
                        border: Border.all(
                          color: widget.isDone
                              ? colors.primary
                              : Colors.grey.shade400,
                          width: 2,
                        ),
                      ),
                      child: widget.isDone
                          ? const Icon(Icons.check,
                              size: 16, color: Colors.white)
                          : null,
                    ),
                  ),
                ),
                title: AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 200),
                  style: TextStyle(
                    decoration:
                        widget.isDone ? TextDecoration.lineThrough : null,
                    color: widget.isDone
                        ? Colors.grey.shade500
                        : Theme.of(context).textTheme.bodyLarge?.color,
                    fontWeight: FontWeight.w600,
                  ),
                  child: Text(widget.title),
                ),
                subtitle: Text(
                  [
                    if (widget.time.isNotEmpty) _formatTime(widget.time),
                    if (widget.durationMinutes > 0)
                      _formatDuration(widget.durationMinutes),
                  ].join(' · '),
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _eventColor() {
    switch (widget.eventColor) {
      case 'red':
        return const Color(0xFFE5484D);
      case 'blue':
        return const Color(0xFF3772FF);
      case 'orange':
        return const Color(0xFFF59E0B);
      case 'green':
      default:
        return const Color(0xFF22A06B);
    }
  }

  String _formatDuration(int minutes) {
    if (minutes >= 60 && minutes % 60 == 0) return '${minutes ~/ 60}시간';
    if (minutes > 60) return '${minutes ~/ 60}시간 ${minutes % 60}분';
    return '$minutes분';
  }

  String _formatTime(String rawTime) {
    try {
      final dt = DateTime.parse(rawTime).toLocal();
      final h = dt.hour.toString().padLeft(2, '0');
      final m = dt.minute.toString().padLeft(2, '0');
      return '$h:$m';
    } catch (_) {
      return rawTime;
    }
  }
}
