import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'config.dart';

/// API 실패. status 가 null 이면 **연결 자체가 안 된 것**이고, 이 구분이 중요하다.
/// 연결 실패는 대기열에 남겨 나중에 다시 보내야 하고, 서버가 거절한 것(422·423)은
/// 다시 보내봐야 같은 결과라 대기열에서 빼야 한다.
class ApiException implements Exception {
  ApiException(this.message, {this.status});

  final String message;
  final int? status;

  bool get isOffline => status == null;

  /// 토큰이 죽었다. 행사를 마감하면 서버가 발급된 토큰을 폐기하므로 여기로 온다.
  bool get isExpired => status == 401 || status == 403;

  /// 심사 마감. 점수는 더 저장되지 않는다.
  bool get isLocked => status == 423;

  /// 다시 보내도 결과가 같은 거절 — 대기열에서 빼야 한다.
  bool get isPermanent => status != null && status! >= 400 && status! < 500 && status != 429;

  @override
  String toString() => message;
}

class Api {
  Api({http.Client? client, this.timeout = const Duration(seconds: 15)})
      : _client = client ?? http.Client();

  final http.Client _client;
  final Duration timeout;

  Future<Map<String, dynamic>> get(String path, {String? token}) => _send('GET', path, token: token);

  Future<Map<String, dynamic>> post(String path, Map<String, dynamic> body, {String? token}) =>
      _send('POST', path, body: body, token: token);

  Future<Map<String, dynamic>> put(String path, Map<String, dynamic> body, {String? token}) =>
      _send('PUT', path, body: body, token: token);

  Future<Map<String, dynamic>> delete(String path, {String? token}) =>
      _send('DELETE', path, token: token);

  Future<Map<String, dynamic>> _send(
    String method,
    String path, {
    Map<String, dynamic>? body,
    String? token,
  }) async {
    final request = http.Request(method, Uri.parse('$kApiBase$path'))
      ..headers['Accept'] = 'application/json';

    if (token != null) request.headers['Authorization'] = 'Bearer $token';

    if (body != null) {
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(body);
    }

    http.Response response;

    try {
      response = await http.Response.fromStream(await _client.send(request)).timeout(timeout);
    } on TimeoutException {
      throw ApiException('서버가 응답하지 않습니다.');
    } on SocketException {
      throw ApiException('인터넷에 연결되어 있지 않습니다.');
    } on http.ClientException {
      throw ApiException('서버에 연결하지 못했습니다.');
    }

    Map<String, dynamic> decoded = const {};

    try {
      final value = jsonDecode(utf8.decode(response.bodyBytes));
      if (value is Map<String, dynamic>) decoded = value;
    } catch (_) {
      // HTML 오류 페이지 등 — 아래에서 상태 코드로 처리한다.
    }

    if (response.statusCode >= 200 && response.statusCode < 300) return decoded;

    throw ApiException(
      decoded['message'] as String? ?? _defaultMessage(response.statusCode),
      status: response.statusCode,
    );
  }

  static String _defaultMessage(int status) => switch (status) {
        401 || 403 => '접속 권한이 없습니다. 다시 입장해 주세요.',
        404 => '대상을 찾을 수 없습니다.',
        423 => '심사가 마감되었습니다.',
        429 => '시도가 너무 잦습니다. 잠시 후 다시 해 주세요.',
        _ => '서버 오류가 발생했습니다. ($status)',
      };
}
