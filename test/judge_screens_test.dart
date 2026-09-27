// 심사위원이 실제로 보는 세 화면이 예외 없이 그려지는지, 그리고 연결이 끊겼다는 사실이
// **목록과 채점 양쪽에서** 보이는지 확인한다. 예전에는 목록에만 띠가 있어서,
// 채점하는 동안에는 연결이 끊긴 줄도 모르고 계속 입력했다.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:judge_app/core/api.dart';
import 'package:judge_app/core/design.dart';
import 'package:judge_app/judge/candidates_screen.dart';
import 'package:judge_app/judge/scoring_screen.dart';
import 'package:judge_app/judge/signature_screen.dart';
import 'package:judge_app/store/judge_session.dart';
import 'package:judge_app/store/local_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'session_test.dart' show FakeServer;

/// 입장까지 마친 앱을 세워 준다. 반환값의 [FakeServer] 로 연결을 끊었다 붙였다 한다.
Future<(FakeServer, ProviderContainer)> boot(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});

  final server = FakeServer();
  final store = await LocalStore.open();
  final container = ProviderContainer(
    overrides: [
      apiProvider.overrideWithValue(Api(client: server.client)),
      localStoreProvider.overrideWithValue(store),
    ],
  );
  await container.read(judgeSessionProvider.notifier).signIn('483920');

  return (server, container);
}

Future<void> show(
  WidgetTester tester,
  ProviderContainer container,
  Widget screen,
) async {
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(theme: buildAppTheme(), home: screen),
    ),
  );
  await tester.pump();
}

/// 화면과 세션을 순서대로 닫는다.
///
/// 목록 화면의 시계와 세션의 확인 주기 둘 다 타이머다. 테스트가 끝날 때까지
/// 살아 있으면 flutter_test 가 "타이머가 남았다" 로 실패시킨다 — 그 경고가
/// 옳다. 실제 앱에서도 화면을 떠난 뒤 타이머가 남으면 안 된다.
Future<void> close(WidgetTester tester, ProviderContainer container) async {
  await tester.pumpWidget(const SizedBox());
  container.dispose();
}

void main() {
  testWidgets('목록 화면이 진행률·이어서 채점하기와 함께 그려진다', (tester) async {
    final (_, container) = await boot(tester);

    await show(tester, container, const CandidatesScreen());

    expect(find.text('심사 진행'), findsOneWidget);
    expect(find.textContaining('이어서 채점하기'), findsOneWidget);
    expect(find.text('방금 전 전송됨'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await close(tester, container);
  });

  testWidgets('찾는 말이 하나도 걸리지 않으면 빈 화면 안내가 뜬다', (tester) async {
    final (_, container) = await boot(tester);

    await show(tester, container, const CandidatesScreen());
    await tester.enterText(find.byType(TextField).first, '없는이름zzz');
    await tester.pump();

    expect(find.text('해당하는 평가 대상이 없습니다'), findsOneWidget);

    await close(tester, container);
  });

  testWidgets('연결이 끊기면 채점 화면에서도 그 사실이 보인다', (tester) async {
    final (server, container) = await boot(tester);
    final session = container.read(judgeSessionProvider.notifier);

    server.offline = true;
    await session.saveScores(102, {11: 20});

    await show(tester, container, const ScoringScreen(candidateId: 102));

    expect(find.textContaining('연결이 끊겼습니다'), findsOneWidget);
    expect(find.text('입력한 항목'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await close(tester, container);
  });

  testWidgets('보낼 것이 없고 연결도 멀쩡하면 상태 띠를 그리지 않는다', (tester) async {
    final (_, container) = await boot(tester);

    await show(tester, container, const CandidatesScreen());

    expect(find.byType(StatusStrip), findsNothing);

    await close(tester, container);
  });

  testWidgets('좁은 화면에서는 항목명과 점수 단추를 두 줄로 나눈다', (tester) async {
    // 한 줄에 − 값 + 를 같이 두면 항목명이 ~150dp 에 갇혀 글자 중간에서 끊겼다.
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final (_, container) = await boot(tester);

    await show(tester, container, const ScoringScreen(candidateId: 102));

    expect(
      find.widgetWithText(StatusPill, '배점 30점'),
      findsWidgets,
      reason: '좁은 화면에서는 배점을 항목명 옆 알약으로 보인다',
    );
    expect(tester.takeException(), isNull);

    await close(tester, container);
  });

  testWidgets('빈 서명 칸에는 어디에 서명할지 안내한다', (tester) async {
    final (_, container) = await boot(tester);

    await show(tester, container, const SignatureScreen());

    expect(find.text('칸을 가득 채워 크게 서명하세요'), findsOneWidget);

    await tester.drag(
      find.text('칸을 가득 채워 크게 서명하세요'),
      const Offset(80, 10),
      warnIfMissed: false, // 안내는 IgnorePointer 라 그 아래 서명 칸이 받는다
    );
    await tester.pump();

    expect(
      find.text('칸을 가득 채워 크게 서명하세요'),
      findsNothing,
      reason: '긋기 시작하면 안내는 사라진다',
    );

    await close(tester, container);
  });

  group('서명 PNG 크기 한도', () {
    // 서버는 dataURL 을 20만 자까지만 받는다. 넘기면 422 로 버려져 서명이 사라진다.
    Future<String> Function(double) fake(
      Map<double, int> lengths,
      List<double> tried,
    ) => (scale) async {
      tried.add(scale);

      return 'x' * lengths[scale]!;
    };

    test('한도 안이면 2배로 굽는다', () async {
      final tried = <double>[];
      final result = await encodeWithinLimit(
        fake({2.0: 1000, 1.5: 500, 1.0: 100}, tried),
      );

      expect(result.length, 1000);
      expect(tried, [2.0]);
    });

    test('2배가 한도를 넘으면 1.5배, 그래도 넘으면 1배로 낮춘다', () async {
      final tried = <double>[];
      final result = await encodeWithinLimit(
        fake({2.0: 250000, 1.5: 195000, 1.0: 120000}, tried),
      );

      expect(result.length, 120000);
      expect(tried, [2.0, 1.5, 1.0]);
      expect(result.length, lessThanOrEqualTo(kSignatureMaxChars));
    });

    test('가장 작은 배율로도 넘치면 그 결과를 돌려준다', () async {
      final tried = <double>[];
      final result = await encodeWithinLimit(
        fake({2.0: 400000, 1.5: 300000, 1.0: 200000}, tried),
      );

      expect(result.length, 200000);
    });
  });

  group('서명 굵기는 칸 크기와 무관하다', () {
    // 같은 서명을 폰(작은 칸)과 태블릿(큰 칸)에서 쓴 경우 — 저장 이미지 안의 위치가 같아야
    // 출력물에서 같은 크기·같은 굵기로 보인다.
    List<List<Offset>> signature(double k) => [
      [
        Offset(40 * k, 60 * k),
        Offset(120 * k, 30 * k),
        Offset(200 * k, 90 * k),
      ],
      [Offset(90 * k, 100 * k), Offset(160 * k, 110 * k)],
    ];

    test('폰과 태블릿의 같은 서명은 같은 이미지로 옮겨진다', () {
      final phone = fitStrokes(signature(1), kSignatureOutput);
      final tablet = fitStrokes(signature(2.4), kSignatureOutput);

      for (var i = 0; i < phone.length; i++) {
        for (var j = 0; j < phone[i].length; j++) {
          expect((phone[i][j] - tablet[i][j]).distance, lessThan(0.001));
        }
      }
    });

    test('작게 써도 이미지를 채운다(여백 안에 닿는다)', () {
      final tiny = fitStrokes(signature(0.3), kSignatureOutput);
      final xs = [
        for (final s in tiny)
          for (final p in s) p.dx,
      ];
      final ys = [
        for (final s in tiny)
          for (final p in s) p.dy,
      ];
      final w =
          xs.reduce((a, b) => a > b ? a : b) -
          xs.reduce((a, b) => a < b ? a : b);
      final h =
          ys.reduce((a, b) => a > b ? a : b) -
          ys.reduce((a, b) => a < b ? a : b);
      final fillsWidth =
          (w - (kSignatureOutput.width - kSignatureMargin * 2)).abs() < 0.01;
      final fillsHeight =
          (h - (kSignatureOutput.height - kSignatureMargin * 2)).abs() < 0.01;

      expect(fillsWidth || fillsHeight, isTrue);
    });

    test('점 하나만 찍어도 나눗셈 오류 없이 가운데에 놓인다', () {
      final dot = fitStrokes([
        [const Offset(10, 10)],
      ], kSignatureOutput);

      expect(dot.single.single, const Offset(360, 120));
    });

    test('화면 선 굵기는 칸 폭에 비례하고 3~10 사이다', () {
      expect(onScreenStroke(720), 9);
      expect(onScreenStroke(360), 4.5);
      expect(onScreenStroke(100), 3);
      expect(onScreenStroke(2000), 10);
    });
  });
}
