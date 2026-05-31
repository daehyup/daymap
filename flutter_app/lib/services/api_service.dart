import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static const String _baseUrl = 'http://127.0.0.1:8000';
  static const String _userId = 'test-user';

  // AI 일정 자동 배분 요청
  static Future<Map<String, dynamic>> generateSchedule(String rawText) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/events/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'user_id': _userId, 'raw_text': rawText}),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    }
    throw Exception('일정 생성 실패 (${response.statusCode}): ${response.body}');
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
    final response = await http.get(
      Uri.parse('$_baseUrl/streaks/$_userId'),
    );

    if (response.statusCode == 200) {
      return jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    }
    throw Exception('스트릭 조회 실패: ${response.statusCode}');
  }

  // 오늘의 태스크 목록 조회
  static Future<List<Map<String, dynamic>>> getTodayTasks() async {
    final response = await http.get(
      Uri.parse('$_baseUrl/tasks/$_userId/today'),
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
}
