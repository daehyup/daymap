import 'package:flutter/material.dart';

class ProgressCard extends StatelessWidget {
  final String eventTitle;
  final String eventType;
  final String color;
  final int? daysUntilDeadline;
  final double completionRate;
  final int totalTasks;
  final int completedTasks;
  final String status;
  final String statusLabel;
  final String message;

  const ProgressCard({
    super.key,
    required this.eventTitle,
    required this.eventType,
    required this.color,
    this.daysUntilDeadline,
    required this.completionRate,
    required this.totalTasks,
    required this.completedTasks,
    required this.status,
    required this.statusLabel,
    required this.message,
  });

  Color get _accentColor => switch (color) {
        'red' => const Color(0xFFE53935),
        'blue' => const Color(0xFF1E88E5),
        'orange' => const Color(0xFFFB8C00),
        _ => const Color(0xFF43A047),
      };

  Color get _statusBg => switch (status) {
        'critical' => const Color(0xFFFFEBEE),
        'warning' => const Color(0xFFFFF8E1),
        'comfortable' => const Color(0xFFE8F5E9),
        _ => const Color(0xFFF3F4FF),
      };

  Color get _statusColor => switch (status) {
        'critical' => const Color(0xFFE53935),
        'warning' => const Color(0xFFFB8C00),
        'comfortable' => const Color(0xFF43A047),
        _ => const Color(0xFF6C63FF),
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _statusBg,
        borderRadius: BorderRadius.circular(8),
        border: Border(left: BorderSide(color: _accentColor, width: 4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  eventTitle,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (daysUntilDeadline != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: _accentColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    daysUntilDeadline! <= 0 ? '마감' : 'D-$daysUntilDeadline',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (completionRate / 100).clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: Colors.black12,
              valueColor: AlwaysStoppedAnimation(_accentColor),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$completedTasks / $totalTasks 완료',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
              ),
              Text(
                '${completionRate.toStringAsFixed(0)}%',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: _accentColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: _statusColor,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  statusLabel,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
