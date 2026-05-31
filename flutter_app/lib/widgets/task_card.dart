import 'package:flutter/material.dart';

class TaskCard extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(bottom: 12),
      child: Card(
        elevation: isDone ? 0 : 2,
        color: isDone ? Colors.grey.shade100 : null,
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: GestureDetector(
            onTap: onToggle,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDone ? Theme.of(context).colorScheme.primary : Colors.transparent,
                border: Border.all(
                  color: isDone
                      ? Theme.of(context).colorScheme.primary
                      : Colors.grey.shade400,
                  width: 2,
                ),
              ),
              child: isDone
                  ? const Icon(Icons.check, size: 16, color: Colors.white)
                  : null,
            ),
          ),
          title: Text(
            title,
            style: TextStyle(
              decoration: isDone ? TextDecoration.lineThrough : null,
              color: isDone ? Colors.grey : null,
            ),
          ),
          subtitle: time.isNotEmpty
              ? Text(time, style: const TextStyle(fontSize: 12))
              : null,
        ),
      ),
    );
  }
}
