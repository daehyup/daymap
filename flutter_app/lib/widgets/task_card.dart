import 'package:flutter/material.dart';

class TaskCard extends StatefulWidget {
  final String title;
  final String time;
  final bool isDone;
  final VoidCallback? onToggle;

  const TaskCard({
    super.key,
    required this.title,
    required this.time,
    required this.isDone,
    this.onToggle,
  });

  @override
  State<TaskCard> createState() => _TaskCardState();
}

class _TaskCardState extends State<TaskCard> with SingleTickerProviderStateMixin {
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
        color: widget.isDone ? colors.surfaceContainerHighest.withOpacity(0.5) : null,
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                  color: widget.isDone ? colors.primary : Colors.transparent,
                  border: Border.all(
                    color: widget.isDone ? colors.primary : Colors.grey.shade400,
                    width: 2,
                  ),
                ),
                child: widget.isDone
                    ? const Icon(Icons.check, size: 16, color: Colors.white)
                    : null,
              ),
            ),
          ),
          title: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 200),
            style: TextStyle(
              decoration: widget.isDone ? TextDecoration.lineThrough : null,
              color: widget.isDone ? Colors.grey.shade500 : Theme.of(context).textTheme.bodyLarge?.color,
            ),
            child: Text(widget.title),
          ),
          subtitle: widget.time.isNotEmpty
              ? Text(_formatTime(widget.time), style: const TextStyle(fontSize: 12))
              : null,
        ),
      ),
    );
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
