import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api.dart';
import '../models/admin.dart';
import 'judge_session.dart' show apiProvider;

/// 관리자 API 묶음. 토큰을 들고 있는 것 외에 상태가 없다.
///
/// 심사위원 쪽과 달리 **아무것도 기기에 저장하지 않는다.** 집계는 언제나 최신이어야 하고,
/// 오래된 순위를 최신인 줄 알고 발표하는 사고가 연결 오류보다 무섭다.
/// 토큰도 저장하지 않는다 — 관리자 권한이 잠금 해제된 기기에 남아 있지 않게 한다.
class AdminApi {
  const AdminApi(this._api, this.token, this.event);

  final Api _api;
  final String token;
  final AdminEvent event;

  /// 행사 목록 — 토큰 없이 부른다. 웹의 /events 화면과 같은 목록이다.
  static Future<List<EventSummary>> events(Api api) async {
    final json = await api.get('/events');

    return (json['events'] as List)
        .map((e) => EventSummary.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<AdminApi> signIn(Api api, int eventId, String password) async {
    final session = await api.post('/admin/session', {
      'event_id': eventId,
      'password': password,
    });

    return _withToken(api, session['token'] as String);
  }

  static Future<AdminApi> createEvent(
    Api api, {
    required String name,
    required String password,
    String? description,
  }) async {
    final created = await api.post('/events', {
      'name': name,
      'admin_password': password,
      if (description != null && description.isNotEmpty) 'description': description,
    });

    return _withToken(api, created['token'] as String);
  }

  static Future<AdminApi> _withToken(Api api, String token) async {
    final event = AdminEvent.fromJson(await api.get('/admin/event', token: token));

    return AdminApi(api, token, event);
  }

  /// 설정을 바꾼 뒤에는 행사 정보도 다시 읽어야 화면 제목·마감 상태가 어긋나지 않는다.
  Future<AdminApi> refreshed() => _withToken(_api, token);

  Future<Dashboard> dashboard() async =>
      Dashboard.fromJson(await _api.get('/admin/dashboard', token: token));

  Future<SetupData> setup() async => 
      SetupData.fromJson(await _api.get('/admin/setup', token: token));

  Future<SetupData> addCriterion({
    required String name,
    required int maxScore,
    int? parentId,
    String? description,
  }) async =>
      SetupData.fromJson(await _api.post('/admin/criteria', {
        'name': name,
        'max_score': maxScore,
        'parent_id': ?parentId,
        if (description != null && description.isNotEmpty) 'description': description,
      }, token: token));

  Future<SetupData> removeCriterion(int id) async =>
      SetupData.fromJson(await _api.delete('/admin/criteria/$id', token: token));

  Future<SetupData> addCandidates(String bulk) async =>
      SetupData.fromJson(await _api.post('/admin/candidates', {'bulk': bulk}, token: token));

  Future<SetupData> removeCandidate(int id) async =>
      SetupData.fromJson(await _api.delete('/admin/candidates/$id', token: token));

  Future<SetupData> addJudges(String bulk) async =>
      SetupData.fromJson(await _api.post('/admin/judges', {'bulk': bulk}, token: token));

  Future<SetupData> removeJudge(int id) async =>
      SetupData.fromJson(await _api.delete('/admin/judges/$id', token: token));

  Future<void> updateScoringMethod({
    required String method,
    required bool isBlind,
    int? passCount,
  }) =>
      _api.put('/admin/scoring-method', {
        'scoring_method': method,
        'is_blind': isBlind,
        'pass_count': passCount,
      }, token: token);

  /// 심사 마감/재개. 마감하면 접속 코드와 발급된 앱 토큰이 함께 회수된다.
  Future<String> toggleOpen() async {
    final json = await _api.post('/admin/toggle-open', const {}, token: token);

    return json['message'] as String;
  }

  /// 인쇄물은 네이티브로 다시 그리지 않는다. 결재란이 있는 A4 공식 문서라
  /// 서버의 출력이 유일한 정답이고, 앱이 재현하면 미묘하게 달라질 위험만 크다.
  /// kind: report | csv | judge-cards
  Future<String> printUrl(String kind) async {
    final json = await _api.get('/admin/print-url?kind=$kind', token: token);

    return json['url'] as String;
  }
}

/// 로그인하면 채워지고 로그아웃하면 비워진다.
final adminApiProvider = StateProvider<AdminApi?>((ref) => null);

final adminBaseApiProvider = Provider<Api>((ref) => ref.watch(apiProvider));
