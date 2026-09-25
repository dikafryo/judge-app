// 관리자 계층은 오프라인을 지원하지 않으므로 상태 기계가 단순하다.
// 대신 **주소를 잘못 부르면 조용히 404 가 나는** 실수가 나기 쉬워 그 부분을 고정한다.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:judge_app/core/api.dart';
import 'package:judge_app/models/admin.dart';
import 'package:judge_app/store/admin_api.dart';

/// 서버 AdminApiController::show() 와 같은 모양의 행사 정보.
/// scoring-method · report-signers 저장도 이 모양을 그대로 돌려준다.
Map<String, dynamic> showEvent({bool isDemo = false}) => {
  'id': 3,
  'name': '가을 심사',
  'description': null,
  'event_date': '2026-10-01',
  'is_open': true,
  'is_demo': isDemo,
  'is_blind': true,
  'scoring_method': 'trimmed',
  'scoring_note': '최고·최저 제외',
  'pass_count': 2,
  'default_score_percent': 90,
  'show_judge_signs': false,
  'report_signers': [
    {'role': '기록자', 'dept': '총무과', 'position': '주무관', 'name': '김기록'},
  ],
};

/// 로그인·생성 응답에 함께 실리는 행사 요약 (SessionController::admin, EventApiController::store).
const sessionEvent = {'id': 3, 'name': '가을 심사', 'is_open': true};

/// 앱이 실제로 부른 주소를 기록하는 가짜 서버.
class FakeAdminServer {
  FakeAdminServer({this.isDemo = false, this.failSignOut = false});

  final bool isDemo;

  /// 참이면 로그아웃 요청에 연결 오류처럼 500 을 돌려준다.
  final bool failSignOut;
  final List<String> calls = [];
  final List<Map<String, dynamic>> bodies = [];

  http.Client get client => MockClient((request) async {
    calls.add(
      '${request.method} ${request.url.path}${request.url.hasQuery ? '?${request.url.query}' : ''}',
    );
    if (request.body.isNotEmpty) {
      bodies.add(jsonDecode(request.body) as Map<String, dynamic>);
    }

    final path = request.url.path;

    if (path.endsWith('/admin/session')) {
      return _json({'token': 'admin-token', 'event': sessionEvent});
    }
    if (path.endsWith('/session') && request.method == 'DELETE') {
      return failSignOut
          ? _json({'message': '서버 오류'}, status: 500)
          : _json({'message': '로그아웃되었습니다.'});
    }
    if (path.endsWith('/events') && request.method == 'POST') {
      return _json({
        'token': 'admin-token',
        'event': sessionEvent,
      }, status: 201);
    }
    if (path.endsWith('/events')) {
      return _json({
        'events': [
          {
            'id': 3,
            'name': '가을 심사',
            'is_open': true,
            'event_date': '2026-10-01',
            'candidates_count': 12,
            'criteria_count': 3,
            'judges_count': 5,
          },
        ],
      });
    }
    if (path.endsWith('/admin/event') && request.method == 'DELETE') {
      return _json({'message': "'가을 심사' 행사와 모든 심사 데이터가 삭제되었습니다."});
    }
    if (path.endsWith('/admin/event')) return _json(showEvent(isDemo: isDemo));
    if (path.endsWith('/admin/setup')) {
      return _json({
        'criteria': [
          {
            'id': 1,
            'name': '기획',
            'max_score': 60,
            'parent_id': null,
            'has_scores': true,
          },
          {
            'id': 2,
            'name': '창의성',
            'max_score': 30,
            'parent_id': 1,
            'has_scores': false,
          },
        ],
        'candidates': [
          {'id': 9, 'name': '가나다', 'affiliation': '가람'},
        ],
        'judges': [
          {
            'id': 4,
            'name': '김심사',
            'code': '483920',
            'entry_url': 'https://judge.sw4u.kr/judge/483920',
            'signed_at': null,
          },
        ],
        'total_max': 60,
      });
    }
    if (path.endsWith('/admin/print-url')) {
      return _json({
        'url': 'https://judge.sw4u.kr/admin/3/print?signature=abc',
      });
    }
    if (path.endsWith('/admin/toggle-open')) {
      return _json({'message': '심사가 마감되었습니다.', 'is_open': false});
    }
    if (path.endsWith('/admin/scoring-method') ||
        path.endsWith('/admin/report-signers')) {
      return _json(showEvent(isDemo: isDemo));
    }

    return _json({'message': '알 수 없는 요청: $path'}, status: 404);
  });

  static http.Response _json(Map<String, dynamic> body, {int status = 200}) =>
      http.Response(
        jsonEncode(body),
        status,
        headers: {'content-type': 'application/json'},
      );
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
    expect(admin.event.showJudgeSigns, isFalse);
    expect(admin.event.reportSigners.single.name, '김기록');
    expect(server.calls, [
      'POST /api/v1/admin/session',
      'GET /api/v1/admin/event',
    ]);
  });

  test('최종집계표 설정과 행사 삭제를 관리자 API로 보낸다', () async {
    final (admin, server) = await signedIn();
    server.calls.clear();
    server.bodies.clear();

    await admin.updateReportSigners(
      showJudgeSigns: false,
      signers: const [
        ReportSigner(role: '기록자', dept: '총무과', position: '주무관', name: '김기록'),
      ],
    );
    await admin.deleteEvent('가을 심사');

    expect(server.calls, [
      'PUT /api/v1/admin/report-signers',
      'DELETE /api/v1/admin/event',
    ]);
    expect(server.bodies.first['show_judge_signs'], isFalse);
    expect((server.bodies.first['signers'] as List).single['role'], '기록자');
    expect(server.bodies.last['confirm_name'], '가을 심사');
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
    expect(
      setup.topLevel.first.hasScores,
      isTrue,
      reason: '이미 채점된 항목은 화면에서 알려 줘야 한다',
    );
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
      'event': {
        'name': '가을 심사',
        'is_open': true,
        'total_max': 100,
        'scoring_method': 'trimmed',
        'scoring_note': '평가대상별 최고·최저 총점 심사위원을 제외하고 집계합니다.',
        'pass_count': 2,
      },
      'pass_tie': {'rank': 2, 'tied': 2, 'slots': 1},
      'judges': [
        {
          'judge_id': 4,
          'name': '김심사',
          'done': 3,
          'total': 5,
          'signed': true,
          'code': '483920',
        },
      ],
      'rows': [
        {
          'candidate_id': 9,
          'number': '01',
          'name': '가나다',
          'affiliation': '가람',
          'by_judge': {'4': 88.0},
          'by_judge_excluded': <String, dynamic>{},
          'sum': 88.0,
          'avg': 88.0,
          'rank': 1,
          'pass': 'pass',
          'judged_count': 1,
        },
        {
          'candidate_id': 10,
          'number': '02',
          'name': '라마바',
          'affiliation': null,
          'by_judge': {'4': null},
          'by_judge_excluded': <String, dynamic>{},
          // 서버는 채점 전에도 합계를 0 으로 보낸다(round(array_sum([]))). 순위·평균만 null.
          'sum': 0,
          'avg': null,
          'rank': null,
          'pass': null,
          'judged_count': 0,
        },
      ],
      'generated_at': '2026-09-04 15:00:00',
    });

    expect(dashboard.rows.first.rank, 1);
    expect(dashboard.rows.first.pass, 'pass');
    expect(dashboard.rows.last.avg, isNull, reason: '아직 채점 안 된 대상은 순위가 없다');
    expect(dashboard.rows.last.sum, 0);
    expect(
      dashboard.scoringMethod,
      'trimmed',
      reason: '설명문을 뒤지지 않고 서버의 집계 방식 값을 그대로 쓴다',
    );
    expect(dashboard.passTie, isNotNull, reason: '선정 경계 동점은 발표 전에 알려야 한다');
    expect(dashboard.judges.single.done, 3);
  });

  test('체험 행사 여부를 행사 정보에서 읽는다', () async {
    final real = await AdminApi.signIn(
      Api(client: FakeAdminServer().client),
      3,
      'pw',
    );
    final demo = await AdminApi.signIn(
      Api(client: FakeAdminServer(isDemo: true).client),
      3,
      'pw',
    );

    expect(real.event.isDemo, isFalse);
    expect(demo.event.isDemo, isTrue);
  });

  test('집계 설정 저장 응답(행사 정보)을 받아도 오류 없이 끝난다', () async {
    final (admin, server) = await signedIn();
    server.calls.clear();

    await admin.updateScoringMethod(method: 'all', isBlind: false);
    await admin.updateReportSigners(showJudgeSigns: true, signers: const []);

    expect(server.calls, [
      'PUT /api/v1/admin/scoring-method',
      'PUT /api/v1/admin/report-signers',
    ]);
  });

  test('행사를 만들면 받은 토큰으로 행사 정보를 읽는다', () async {
    final server = FakeAdminServer();
    final admin = await AdminApi.createEvent(
      Api(client: server.client),
      name: '가을 심사',
      password: 'secret12',
    );

    expect(admin.token, 'admin-token');
    expect(server.calls, ['POST /api/v1/events', 'GET /api/v1/admin/event']);
  });

  group('로그아웃', () {
    test('서버에서 토큰을 폐기한다', () async {
      final (admin, server) = await signedIn();
      server.calls.clear();

      await admin.signOut();

      expect(server.calls, ['DELETE /api/v1/session']);
    });

    test('서버가 실패해도 로그아웃을 막지 않는다', () async {
      final server = FakeAdminServer(failSignOut: true);
      final admin = await AdminApi.signIn(Api(client: server.client), 3, 'pw');

      await expectLater(admin.signOut(), completes);
    });
  });

  group('심사 기본점수', () {
    test('행사 정보에서 읽어 온다', () async {
      final server = FakeAdminServer();
      final admin = await AdminApi.signIn(Api(client: server.client), 3, 'pw');

      expect(admin.event.defaultScorePercent, 90);
    });

    test('집계 설정을 저장할 때 함께 보낸다', () async {
      final server = FakeAdminServer();
      final admin = await AdminApi.signIn(Api(client: server.client), 3, 'pw');

      await admin.updateScoringMethod(
        method: 'all',
        isBlind: true,
        passCount: 2,
        defaultScorePercent: 90,
      );

      // 빠뜨리면 서버가 값을 그대로 두므로 조용히 안 바뀐다 — 보냈는지까지 고정한다
      expect(server.bodies.last['default_score_percent'], 90);
    });
  });
}
