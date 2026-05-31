import 'package:flutter/material.dart';
import '../widgets/task_card.dart';
import '../widgets/streak_widget.dart';

class TodayScreen extends StatelessWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('오늘의 일정'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: const StreakWidget(streak: 0),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          // TODO: 실제 태스크 목록으로 교체
          TaskCard(
            title: '일정을 입력하면 AI가 자동으로 배분해줍니다.',
            time: '',
            isDone: false,
          ),
        ],
      ),
    );
  }
}
