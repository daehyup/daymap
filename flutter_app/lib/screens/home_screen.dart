import 'package:flutter/material.dart';
import 'calendar_screen.dart';
import 'heatmap_screen.dart';
import 'input_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  DateTime _calendarMonth = DateTime(DateTime.now().year, DateTime.now().month);
  int _calendarRefreshKey = 0;

  void _handlePlanCreated(DateTime month) {
    setState(() {
      _calendarMonth = DateTime(month.year, month.month);
      _calendarRefreshKey++;
      _currentIndex = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      CalendarScreen(
        key: ValueKey('calendar-$_calendarRefreshKey'),
        initialMonth: _calendarMonth,
      ),
      InputScreen(onSuccess: _handlePlanCreated),
      const HeatmapScreen(),
    ];

    return Scaffold(
      body: pages[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) => setState(() => _currentIndex = index),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.calendar_month), label: '달력'),
          NavigationDestination(
              icon: Icon(Icons.add_circle_outline), label: '일정 입력'),
          NavigationDestination(
              icon: Icon(Icons.bar_chart_outlined), label: '기록'),
        ],
      ),
    );
  }
}
