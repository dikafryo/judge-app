// 플레이스토어 스크린샷 생성기.
//
// 실기기 없이 앱 화면을 **그대로 렌더링해** PNG 로 굽는다. 테스트 러너의 소프트웨어
// 래스터라이저를 쓰므로 실제 위젯·색·글꼴이 그대로 나온다. 가짜 서버로 데모 행사와
// 같은 합성 데이터를 넣는다 — 실제 사람 이름이 스토어에 실리면 안 된다.
//
//   scripts/make_screenshots.sh   (내부적으로 --dart-define=SHOTS=true 로 이 파일만 돌린다)
//
// SHOTS 가 없으면 아무것도 하지 않는다. 일반 `flutter test` 에서 파일을 쓰면 안 된다.

import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:judge_app/admin/admin_events_screen.dart';
import 'package:judge_app/admin/admin_home_screen.dart';
import 'package:judge_app/core/api.dart';
import 'package:judge_app/core/design.dart';
import 'package:judge_app/judge/candidates_screen.dart';
import 'package:judge_app/judge/entry_screen.dart';
import 'package:judge_app/judge/scoring_screen.dart';
import 'package:judge_app/models/admin.dart';
import 'package:judge_app/store/admin_api.dart';
import 'package:judge_app/store/judge_session.dart';
import 'package:judge_app/store/local_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

const bool _enabled = bool.fromEnvironment('SHOTS');

/// 1080×2100 — 플레이 휴대전화 스크린샷 규격(각 변 320~3840, 비율 2:1 이하) 안이다.
const _physical = Size(1080, 2100);
const _dpr = 3.0;

const _fontDir = '/usr/share/fonts/opentype/noto';
const _materialIcons =
    '/home/dikafryo/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf';

const _eventName = '제12회 학생 창업 아이디어 경진대회';

// ── 합성 데이터 ───────────────────────────────────────────────────────────────

const _candidates = [
  ('스마트 급식 잔반 알리미', '도담초등학교'),
  ('교실 공기질 자동 환기 시스템', '한빛중학교'),
  ('점자 학습 보조 키보드', '새싹고등학교'),
  ('학교 분실물 찾기 앱', '늘봄중학교'),
  ('노인 복약 알림 스피커', '미래고등학교'),
  ('교내 재활용 분리배출 도우미', '푸른초등학교'),
  ('통학버스 승하차 알림', '가온초등학교'),
  ('급식 알레르기 안내 챗봇', '다솜중학교'),
];

Map<String, dynamic> judgePayload() => {
  'judge': {'id': 7, 'name': '김서연'},
  'event': {'name': _eventName, 'is_open': true, 'is_blind': false},
  'groups': [
    {
      'id': 1,
      'name': '창의성',
      'max_score': 30,
      'has_children': true,
      'items': [
        {'id': 11, 'name': '착상의 참신성', 'max_score': 15, 'description': null},
        {'id': 12, 'name': '기존 사례와의 차별성', 'max_score': 15, 'description': null},
      ],
    },
    {
      'id': 2,
      'name': '실현가능성',
      'max_score': 30,
      'has_children': true,
      'items': [
        {'id': 21, 'name': '기술적 구현 가능성', 'max_score': 15, 'description': null},
        {'id': 22, 'name': '비용·기간의 현실성', 'max_score': 15, 'description': null},
      ],
    },
    {
      'id': 3,
      'name': '효과성',
      'max_score': 25,
      'has_children': false,
      'items': [
        {
          'id': 3,
          'name': '효과성',
          'max_score': 25,
          'description': '문제 해결에 실제로 기여하는 정도',
        },
      ],
    },
    {
      'id': 4,
      'name': '발표력',
      'max_score': 15,
      'has_children': false,
      'items': [
        {
          'id': 4,
          'name': '발표력',
          'max_score': 15,
          'description': '전달력과 질의응답 대응',
        },
      ],
    },
  ],
  'candidates': [
    for (final (i, c) in _candidates.indexed)
      {
        'id': 101 + i,
        'number': (i + 1).toString().padLeft(2, '0'),
        'name': c.$1,
        'affiliation': c.$2,
      },
  ],
  'scores': {
    '101': {'11': 13, '12': 12, '21': 14, '22': 12, '3': 21, '4': 13},
    '102': {'11': 12, '12': 11, '21': 13, '22': 11, '3': 20, '4': 12},
    '103': {'11': 14, '12': 13, '21': 12, '22': 13, '3': 22, '4': 14},
    '104': {'11': 12, '12': 12, '21': 11, '22': 12, '3': 19, '4': 11},
    '105': {'11': 13, '12': 12, '21': 12},
  },
  'hasSignature': true,
  'totalMax': 100,
};

Map<String, dynamic> adminEvent() => {
  'id': 3,
  'name': _eventName,
  'is_open': true,
  'is_blind': false,
  'scoring_method': 'trimmed',
  'scoring_note':
      '총점·평균은 평가 대상별로 최고 총점·최저 총점을 부여한 심사위원의 점수를 제외한 합계·평균입니다. (채점 3인 이상일 때 적용)',
  'pass_count': 3,
  'default_score_percent': null,
  'show_judge_signs': true,
  'report_signers': [
    {'role': '기록자', 'dept': '창의교육과', 'position': '주무관', 'name': '홍길동'},
  ],
};

Map<String, dynamic> dashboard() {
  const avgs = [88.5, 86.0, 84.5, 84.5, 79.0, 76.5, null, null];
  const judged = [5, 5, 5, 5, 5, 4, 0, 0];
  const pass = ['pass', 'pass', 'tie', 'tie', null, null, null, null];
  var rank = 0;

  return {
    'event': {
      'name': _eventName,
      'is_open': true,
      'total_max': 100,
      'scoring_note': (adminEvent()['scoring_note'] as String),
      'pass_count': 3,
    },
    'pass_tie': {'rank': 3},
    'judges': [
      {'name': '김서연', 'done': 8, 'total': 8, 'signed': true, 'code': '700101'},
      {'name': '박준호', 'done': 8, 'total': 8, 'signed': true, 'code': '700102'},
      {'name': '이하은', 'done': 6, 'total': 8, 'signed': false, 'code': '700103'},
      {'name': '정민석', 'done': 5, 'total': 8, 'signed': false, 'code': '700104'},
      {'name': '최윤아', 'done': 3, 'total': 8, 'signed': false, 'code': '700105'},
    ],
    'rows': [
      for (final (i, c) in _candidates.indexed)
        {
          'candidate_id': 101 + i,
          'number': (i + 1).toString().padLeft(2, '0'),
          'name': c.$1,
          'affiliation': c.$2,
          'sum': avgs[i] == null ? null : avgs[i]! * 3,
          'avg': avgs[i],
          'rank': avgs[i] == null
              ? null
              : (i > 0 && avgs[i] == avgs[i - 1] ? rank : ++rank),
          'pass': pass[i],
          'judged_count': judged[i],
        },
    ],
    'generated_at': '2026-10-02 14:32:05',
  };
}

Map<String, dynamic> setup() => {
  'criteria': [
    {
      'id': 1,
      'name': '창의성',
      'max_score': 30,
      'parent_id': null,
      'has_scores': true,
    },
    {
      'id': 11,
      'name': '착상의 참신성',
      'max_score': 15,
      'parent_id': 1,
      'has_scores': true,
    },
    {
      'id': 12,
      'name': '기존 사례와의 차별성',
      'max_score': 15,
      'parent_id': 1,
      'has_scores': true,
    },
    {
      'id': 3,
      'name': '효과성',
      'max_score': 25,
      'parent_id': null,
      'has_scores': true,
    },
  ],
  'candidates': [
    for (final (i, c) in _candidates.indexed)
      {'id': 101 + i, 'name': c.$1, 'affiliation': c.$2},
  ],
  'judges': [
    {
      'id': 1,
      'name': '김서연',
      'code': '700101',
      'entry_url': '',
      'signed_at': '2026-10-02',
    },
    {
      'id': 2,
      'name': '박준호',
      'code': '700102',
      'entry_url': '',
      'signed_at': null,
    },
  ],
  'total_max': 55,
};

List<Map<String, dynamic>> events() => [
  {
    'id': 3,
    'name': _eventName,
    'is_open': true,
    'candidates_count': 8,
    'criteria_count': 6,
    'judges_count': 5,
    'event_date': '2026-10-02',
  },
  {
    'id': 2,
    'name': '2026 교육용 소프트웨어 공모전',
    'is_open': true,
    'candidates_count': 14,
    'criteria_count': 4,
    'judges_count': 3,
    'event_date': '2026-09-18',
  },
  {
    'id': 1,
    'name': '봄 학기 발표회 심사',
    'is_open': false,
    'candidates_count': 6,
    'criteria_count': 3,
    'judges_count': 4,
    'event_date': '2026-05-21',
  },
];

// ── 가짜 서버 ────────────────────────────────────────────────────────────────

http.Response _json(Object body, {int status = 200}) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

class _Server {
  bool offline = false;

  http.Client get client => MockClient((request) async {
    if (offline) throw const SocketException('offline');

    final path = request.url.path;

    if (path.endsWith('/judge/session')) {
      return _json({
        'token': 'shot-token',
        'judge': {'id': 7, 'name': '김서연'},
      });
    }
    if (path.endsWith('/judge/me')) return _json(judgePayload());
    if (path.contains('/scores')) return _json({'message': 'ok', 'total': 0});
    if (path.endsWith('/events')) return _json({'events': events()});
    if (path.endsWith('/admin/event')) return _json(adminEvent());
    if (path.endsWith('/admin/dashboard')) return _json(dashboard());
    if (path.endsWith('/admin/setup')) return _json(setup());

    return _json({'message': '없음'}, status: 404);
  });
}

// ── 찍기 ────────────────────────────────────────────────────────────────────

Future<void> _loadFonts() async {
  Future<void> load(String family, String path) async {
    final bytes = await File(path).readAsBytes();
    final loader = FontLoader(family)
      ..addFont(Future.value(ByteData.view(bytes.buffer)));
    await loader.load();
  }

  // 같은 family 에 Regular·Bold 를 모두 넣어야 w700 이상이 진짜 굵게 나온다.
  // 화면 곳곳의 인라인 TextStyle 은 family 를 적지 않으므로(기기에서는 시스템 글꼴),
  // 테스트 러너가 기본으로 찾는 이름(FlutterTest·Roboto)에도 같은 글꼴을 등록한다.
  for (final family in ['NotoSansKR', 'Roboto', 'FlutterTest']) {
    await load(family, '$_fontDir/NotoSansCJK-Regular.ttc');
    await load(family, '$_fontDir/NotoSansCJK-Bold.ttc');
  }
  await load('MaterialIcons', _materialIcons);
}

ThemeData _theme() {
  final base = buildAppTheme();
  const family = 'NotoSansKR';
  const button = WidgetStatePropertyAll(
    TextStyle(fontFamily: family, fontSize: 15, fontWeight: FontWeight.w700),
  );

  // 테마의 글씨 스타일에 family 를 넣는다. 화면의 인라인 TextStyle 은 이것과 합쳐지므로
  // family 를 따로 적지 않아도 같은 글꼴로 나온다.
  return base.copyWith(
    textTheme: base.textTheme.apply(fontFamily: family),
    primaryTextTheme: base.primaryTextTheme.apply(fontFamily: family),
    appBarTheme: base.appBarTheme.copyWith(
      titleTextStyle: base.appBarTheme.titleTextStyle?.copyWith(
        fontFamily: family,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: base.filledButtonTheme.style?.copyWith(textStyle: button),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: base.outlinedButtonTheme.style?.copyWith(textStyle: button),
    ),
    textButtonTheme: TextButtonThemeData(
      style: base.textButtonTheme.style?.copyWith(textStyle: button),
    ),
    floatingActionButtonTheme: base.floatingActionButtonTheme.copyWith(
      extendedTextStyle: base.floatingActionButtonTheme.extendedTextStyle
          ?.copyWith(fontFamily: family),
    ),
    snackBarTheme: base.snackBarTheme.copyWith(
      contentTextStyle: base.snackBarTheme.contentTextStyle?.copyWith(
        fontFamily: family,
      ),
    ),
  );
}

Widget _app(Widget screen) => RepaintBoundary(
  key: const ValueKey('shot'),
  child: MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: _theme(),
    home: screen,
  ),
);

Future<void> _capture(WidgetTester tester, String name) async {
  // flutter_test 는 그림자를 꺼 둔다(debugDisableShadows = true). 그대로 찍으면 카드
  // 그림자가 납작한 띠로 나온다. 찍는 동안만 켜고 곧바로 되돌린다 — 테스트 본문이
  // 끝날 때 이 값이 바뀌어 있으면 flutter_test 가 실패시킨다.
  debugDisableShadows = false;
  for (final e in tester.allElements) {
    e.renderObject?.markNeedsPaint();
  }
  await tester.pumpAndSettle(const Duration(milliseconds: 600));

  final boundary =
      tester.renderObject(find.byKey(const ValueKey('shot')))
          as RenderRepaintBoundary;

  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: _dpr);
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('store/$name.png');

    await file.writeAsBytes(png!.buffer.asUint8List());
    stdout.writeln('wrote ${file.path} ${image.width}x${image.height}');
  });
  debugDisableShadows = true;
}

void _phone(WidgetTester tester) {
  tester.view.physicalSize = _physical;
  tester.view.devicePixelRatio = _dpr;
  // 상태바 자리(위)와 제스처 바 자리(아래). 화면이 인셋을 어떻게 비키는지도 함께 찍힌다.
  tester.view.padding = const FakeViewPadding(top: 84, bottom: 48);
  addTearDown(tester.view.reset);
}

Future<ProviderContainer> _judgeContainer(_Server server) async {
  SharedPreferences.setMockInitialValues({});
  final store = await LocalStore.open();
  final container = ProviderContainer(
    overrides: [
      apiProvider.overrideWithValue(Api(client: server.client)),
      localStoreProvider.overrideWithValue(store),
    ],
  );
  return container;
}

Widget _scoped(ProviderContainer container, Widget screen) =>
    UncontrolledProviderScope(container: container, child: _app(screen));

void main() {
  if (!_enabled) {
    test('스크린샷 생성은 SHOTS=true 일 때만 돈다', () {});

    return;
  }

  setUpAll(_loadFonts);

  testWidgets('1 입장', (tester) async {
    _phone(tester);
    final container = await _judgeContainer(_Server());

    await tester.pumpWidget(_scoped(container, EntryScreen(onAdmin: () {})));
    await _capture(tester, 'screenshot-1');
    await tester.pumpWidget(const SizedBox());
    container.dispose();
  });

  testWidgets('2 목록', (tester) async {
    _phone(tester);
    final container = await _judgeContainer(_Server());
    await container.read(judgeSessionProvider.notifier).signIn('700101');

    await tester.pumpWidget(_scoped(container, const CandidatesScreen()));
    await _capture(tester, 'screenshot-2');
    await tester.pumpWidget(const SizedBox());
    container.dispose();
  });

  testWidgets('3 채점', (tester) async {
    _phone(tester);
    final container = await _judgeContainer(_Server());
    await container.read(judgeSessionProvider.notifier).signIn('700101');

    await tester.pumpWidget(
      _scoped(container, const ScoringScreen(candidateId: 105)),
    );
    await _capture(tester, 'screenshot-3');
    await tester.pumpWidget(const SizedBox());
    container.dispose();
  });

  testWidgets('4 오프라인 채점', (tester) async {
    _phone(tester);
    final server = _Server();
    final container = await _judgeContainer(server);
    final session = container.read(judgeSessionProvider.notifier);
    await session.signIn('700101');

    server.offline = true;
    await session.saveScores(106, {11: 12, 12: 13, 21: 11});
    await session.saveScores(107, {11: 14});

    await tester.pumpWidget(
      _scoped(container, const ScoringScreen(candidateId: 106)),
    );
    await _capture(tester, 'screenshot-4');
    await tester.pumpWidget(const SizedBox());
    container.dispose();
  });

  testWidgets('5 집계', (tester) async {
    _phone(tester);
    final server = _Server();
    final api = Api(client: server.client);
    final admin = AdminApi(
      api,
      'shot-token',
      AdminEvent.fromJson(adminEvent()),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiProvider.overrideWithValue(api),
          adminApiProvider.overrideWith((ref) => admin),
        ],
        child: _app(const AdminHomeScreen()),
      ),
    );
    await _capture(tester, 'screenshot-5');
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('6 행사 목록', (tester) async {
    _phone(tester);
    final server = _Server();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [apiProvider.overrideWithValue(Api(client: server.client))],
        child: _app(const AdminEventsScreen()),
      ),
    );
    await _capture(tester, 'screenshot-6');
    await tester.pumpWidget(const SizedBox());
  });
}
