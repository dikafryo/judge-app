// 관리자 계층은 오프라인을 지원하지 않으므로 상태 기계가 단순하다.
// 대신 **주소를 잘못 부르면 조용히 404 가 나는** 실수가 나기 쉬워 그 부분을 고정한다.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:judge_app/core/api.dart';
import 'package:judge_app/models/admin.dart';
import 'package:judge_app/store/admin_api.dart';

/// 앱이 실제로 부른 주소를 기록하는 가짜 서버.
class FakeAdminServer {
  final List<String> calls = [];

  http.Client get client => MockClient((request) async {
        calls.add('${request.method} ${request.url.path}${request.url.hasQuery ? '?${request.url.query}' : ''}');

        final path = request.url.path;

        if (path.endsWith('/admin/session')) return _json({'token': 'admin-token'});
        if (path.endsWith('/events') && request.method == 'POST') {
          return _json({'token': 'admin-token'}, status: 201);
        }
        if (path.endsWith('/events')) {
          return _json({
            'events': [
              {
                'id': 3, 'name': '가을 심사', 'is_open': true, 'event_date': '2026-10-01',
                'candidates_count': 12, 'criteria_count': 3, 'judges_count': 5,
              },
            ],
          });
        }
        if (path.endsWith('/admin/event')) {
          return _json({
            'id': 3, 'name': '가을 심사', 'is_open': true, 'is_blind': true,
            'scoring_method': 'trimmed', 'scoring_note': '최고·최저 제외', 'pass_count': 2,
          });
        }
        if (path.endsWith('/admin/setup')) {
          return _json({
            'criteria': [
              {'id': 1, 'name': '기획', 'max_score': 60, 'parent_id': null, 'has_scores': true},
              {'id': 2, 'name': '창의성', 'max_score': 30, 'parent_id': 1, 'has_scores': false},
            ],
            'candidates': [{'id': 9, 'name': '가나다', 'affiliation': '가람'}],
            'judges': [
              {'id': 4, 'name': '김심사', 'code': '483920', 'entry_url': 'https://judge.sw4u.kr/judge/483920', 'signed_at': null},
            ],
            'total_max': 60,
          });
        }
        if (path.endsWith('/admin/print-url')) {
          return _json({'url': 'https://judge.sw4u.kr/admin/3/print?signature=abc'});
        }
        if (path.endsWith('/admin/toggle-open')) {
          return _json({'message': '심사가 마감되었습니다.', 'is_open': false});
        }

        return _json({'message': '알 수 없는 요청: $path'}, status: 404);
      });

  static http.Response _json(Map<String, dynamic> body, {int status = 200}) =>
      http.Response(jsonEncode(body), status, headers: {'content-type': 'application/json'});
}

Future<(AdminApi, FakeAdminServer)> signedIn() async {
  final server = FakeAdminServer();
  final api = Api(client: server.client);
  final admin = await AdminApi.signIn(api, 3, 'pw');

  return (admin, server);
}

void main() {
  test('로그인하면 행사 정보를 함께 읽는다', () async {
    final (admin, server) = await signedIn();

    expect(admin.token, 'admin-token');
    expect(admin.event.name, '가을 심사');
    expect(admin.event.scoringMethod, 'trimmed');
    expect(server.calls, ['POST /api/v1/admin/session', 'GET /api/v1/admin/event']);
  });

  test('모든 관리 요청이 /api/v1/admin 아래로 간다', () async {
    // 접두어를 빠뜨리면 서버가 조용히 404 를 돌려주고 화면만 비어 보인다.
    final (admin, server) = await signedIn();

    server.calls.clear();

    await admin.setup();
    await admin.printUrl('report');
    await admin.toggleOpen();

    expect(server.calls, [
      'GET /api/v1/admin/setup',
      'GET /api/v1/admin/print-url?kind=report',
      'POST /api/v1/admin/toggle-open',
    ]);
  });

  test('설정 데이터에서 2단계 구조를 읽어낸다', () async {
    final (admin, _) = await signedIn();
    final setup = await admin.setup();

    expect(setup.topLevel.map((c) => c.name), ['기획']);
    expect(setup.childrenOf(1).map((c) => c.name), ['창의성']);
    expect(setup.topLevel.first.hasScores, isTrue, reason: '이미 채점된 항목은 화면에서 알려 줘야 한다');
    expect(setup.judges.first.code, '483920');
  });

  test('행사 목록은 토큰 없이 읽는다', () async {
    final server = FakeAdminServer();
    final events = await AdminApi.events(Api(client: server.client));

    expect(events.single.name, '가을 심사');
    expect(events.single.candidates, 12);
    expect(server.calls, ['GET /api/v1/events']);
  });

  test('집계 응답을 서버 계산 그대로 읽는다', () {
    // 앱이 순위를 다시 매기면 웹 대시보드와 숫자가 어긋난다.
    final dashboard = Dashboard.fromJson({
      'event': {'name': '가을 심사', 'is_open': true, 'total_max': 100, 'scoring_note': '전체 합계', 'pass_count': 2},
      'pass_tie': {'rank': 2},
      'judges': [{'name': '김심사', 'done': 3, 'total': 5, 'signed': true, 'code': '483920'}],
      'rows': [
        {'candidate_id': 9, 'number': '01', 'name': '가나다', 'sum': 88.0, 'avg': 88.0, 'rank': 1, 'pass': 'pass', 'judged_count': 1},
        {'candidate_id': 10, 'number': '02', 'name': '라마바', 'sum': null, 'avg': null, 'rank': null, 'judged_count': 0},
      ],
      'generated_at': '2026-09-04 15:00:00',
    });

    expect(dashboard.rows.first.rank, 1);
    expect(dashboard.rows.first.pass, 'pass');
    expect(dashboard.rows.last.avg, isNull, reason: '아직 채점 안 된 대상은 순위가 없다');
    expect(dashboard.passTie, isNotNull, reason: '선정 경계 동점은 발표 전에 알려야 한다');
    expect(dashboard.judges.single.done, 3);
  });
}
