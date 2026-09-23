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

    await show(
      tester,
      container,
      const ScoringScreen(candidateId: 102),
    );

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
}
