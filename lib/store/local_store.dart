import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/payload.dart';
import 'queued_op.dart';

/// 기기 저장소. 심사위원 한 명의 데이터는 작아서 DB 를 들이지 않고 shared_preferences 로 충분하다.
///
/// 저장하는 것은 셋이다: 토큰 · payload(오프라인에서 화면을 그릴 전부) · 전송 대기열.
/// 서명 이미지는 대기열 안에만 잠시 머문다 — 전송되면 사라진다.
class LocalStore {
  LocalStore(this._prefs);

  final SharedPreferences _prefs;

  static const _kToken = 'judge.token';
  static const _kPayload = 'judge.payload';
  static const _kQueue = 'judge.queue';

  static Future<LocalStore> open() async => LocalStore(await SharedPreferences.getInstance());

  String? get token => _prefs.getString(_kToken);

  Future<void> saveToken(String value) => _prefs.setString(_kToken, value);

  JudgePayload? get payload {
    final raw = _prefs.getString(_kPayload);

    if (raw == null) return null;

    try {
      return JudgePayload.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      // 앱 버전이 바뀌어 모양이 달라졌을 수 있다. 캐시를 버리고 서버에서 다시 받는다.
      return null;
    }
  }

  Future<void> savePayload(JudgePayload value) =>
      _prefs.setString(_kPayload, jsonEncode(value.toJson()));

  List<QueuedOp> get queue {
    final raw = _prefs.getString(_kQueue);

    if (raw == null) return [];

    try {
      return (jsonDecode(raw) as List)
          .map((e) => QueuedOp.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveQueue(List<QueuedOp> value) =>
      _prefs.setString(_kQueue, jsonEncode(value.map((e) => e.toJson()).toList()));

  /// 로그아웃. 대기열까지 지우므로 **보내지 못한 점수가 사라진다** —
  /// 호출하는 쪽에서 대기열이 빈 것을 확인하거나 사용자에게 먼저 알려야 한다.
  Future<void> clear() async {
    await _prefs.remove(_kToken);
    await _prefs.remove(_kPayload);
    await _prefs.remove(_kQueue);
  }
}
