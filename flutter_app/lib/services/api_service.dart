import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static const String _baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://127.0.0.1:8000',
  );
  static String? _cachedUserId;

  static Future<String> getUserId() async {
    if (_cachedUserId != null) return _cachedUserId!;

    final prefs = await SharedPreferences.getInstance();
    var userId = prefs.getString('user_id');

    if (userId == null) {
      userId = _generateUuid();
      await prefs.setString('user_id', userId);
    }

    _cachedUserId = userId;
    return userId;
  }

  static String _generateUuid() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  // AI 일정 자동 배분 요청
  static Future<Map<String, dynamic>> generateSchedule(String rawText) async {
    final userId = await getUserId();
    final response = await http.post(
      Uri.parse('$_baseUrl/events/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'user_id': userId, 'raw_text': rawText}),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(utf8.decode(response.bodyBytes))
          as Map<String, dynamic>;
    }
    throw Exception('일정 생성 실패 (${response.statusCode}): ${response.body}');
  }

  // 월간 AI 계획 생성
  static Future<Map<String, dynamic>> generateMonthlyPlan({
    required String rawText,
    required int year,
    required int month,
  }) async {
    final userId = await getUserId();
    final response = await http.post(
      Uri.parse('$_baseUrl/schedule/generate'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'user_id': userId,
        'raw_text': rawText,
        'plan_year': year,
        'plan_month': month,
      }),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(utf8.decode(response.bodyBytes))
          as Map<String, dynamic>;
    }
    throw Exception('월간 계획 생성 실패 (${response.statusCode}): ${response.body}');
  }

  // 월간 달력 데이터 조회
  static Future<Map<String, dynamic>> getMonthlyCalendar({
    required int year,
    required int month,
  }) async {
    final userId = await getUserId();
    final response = await http.get(
      Uri.parse('$_baseUrl/schedule/$userId/month?year=$year&month=$month'),
    );

    if (response.statusCode == 200) {
      return jsonDecode(utf8.decode(response.bodyBytes))
          as Map<String, dynamic>;
    }
    throw Exception('월간 달력 조회 실패: ${response.statusCode}');
  }

  // 날짜 상세 데이터 조회
  static Future<Map<String, dynamic>> getDayDetail(
      {required String date}) async {
    final userId = await getUserId();
    final response = await http.get(
      Uri.parse('$_baseUrl/schedule/$userId/day?date=$date'),
    );

    if (response.statusCode == 200) {
      return jsonDecode(utf8.decode(response.bodyBytes))
          as Map<String, dynamic>;
    }
    throw Exception('날짜 상세 조회 실패: ${response.statusCode}');
  }

  // 미완료 태스크 AI 재배분 요청
  static Future<Map<String, dynamic>> redistributeTasks() async {
    final userId = await getUserId();
    final response = await http.post(
      Uri.parse('$_baseUrl/schedule/$userId/redistribute'),
      headers: {'Content-Type': 'application/json'},
    );

    if (response.statusCode == 200) {
      return jsonDecode(utf8.decode(response.bodyBytes))
          as Map<String, dynamic>;
    }
    throw Exception('재배분 실패 (${response.statusCode}): ${response.body}');
  }

  // 달성 가능성 피드백 카드 조회
  static Future<Map<String, dynamic>> getProgress() async {
    final userId = await getUserId();
    final response = await http.get(
      Uri.parse('$_baseUrl/schedule/$userId/progress'),
    );

    if (response.statusCode == 200) {
      return jsonDecode(utf8.decode(response.bodyBytes))
          as Map<String, dynamic>;
    }
    throw Exception('진행 현황 조회 실패: ${response.statusCode}');
  }

  // 태스크 완료 처리
  static Future<void> completeTask(String taskId) async {
    final response = await http.patch(
      Uri.parse('$_baseUrl/tasks/$taskId/complete'),
      headers: {'Content-Type': 'application/json'},
    );

    if (response.statusCode != 200) {
      throw Exception('태스크 완료 처리 실패: ${response.statusCode}');
    }
  }

  // 스트릭 및 XP 조회
  static Future<Map<String, dynamic>> getStreak() async {
    final userId = await getUserId();
    final response = await http.get(
      Uri.parse('$_baseUrl/streaks/$userId'),
    );

    if (response.statusCode == 200) {
      return jsonDecode(utf8.decode(response.bodyBytes))
          as Map<String, dynamic>;
    }
    throw Exception('스트릭 조회 실패: ${response.statusCode}');
  }

  // 오늘의 태스크 목록 조회
  static Future<List<Map<String, dynamic>>> getTodayTasks() async {
    final userId = await getUserId();
    final response = await http.get(
      Uri.parse('$_baseUrl/tasks/$userId/today'),
    );

    if (response.statusCode == 200) {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      // 백엔드가 리스트 또는 {"tasks": [...]} 형태 모두 허용
      if (decoded is List) {
        return List<Map<String, dynamic>>.from(decoded);
      }
      return List<Map<String, dynamic>>.from(decoded['tasks'] as List);
    }
    throw Exception('태스크 조회 실패: ${response.statusCode}');
  }

  // 연간 히트맵 조회
  static Future<Map<String, dynamic>> getHeatmap({required int year}) async {
    final userId = await getUserId();
    final response = await http.get(
      Uri.parse('$_baseUrl/schedule/$userId/heatmap?year=$year'),
    );

    if (response.statusCode == 200) {
      return jsonDecode(utf8.decode(response.bodyBytes))
          as Map<String, dynamic>;
    }
    throw Exception('히트맵 조회 실패: ${response.statusCode}');
  }

  // FCM 토큰 등록
  static Future<void> registerFcmToken(String token) async {
    final userId = await getUserId();
    final response = await http.post(
      Uri.parse('$_baseUrl/users/$userId/fcm-token'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'fcm_token': token}),
    );

    if (response.statusCode != 200) {
      throw Exception('FCM 토큰 등록 실패: ${response.statusCode}');
    }
  }
}
