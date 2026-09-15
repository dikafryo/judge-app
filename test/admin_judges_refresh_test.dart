// 관리자 심사위원 탭이 마감·재개 후에도 최신 코드를 보여주는지 검증한다.
// IndexedStack 은 탭을 계속 살려 두므로, 탭을 다시 열 때 서버에서 다시 읽지 않으면
// 재시작 전까지 옛 코드가 남는 버그가 생긴다 — 그 경로를 여기서 고정한다.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:judge_app/admin/admin_home_screen.dart';
import 'package:judge_app/core/api.dart';
import 'package:judge_app/models/admin.dart';
import 'package:judge_app/store/admin_api.dart';

class FakeRefreshServer {
  bool isOpen = true;
  String? judgeCode = '483920';
  int setupCalls = 0;

  http.Client get client => MockClient((request) async {
    final path = request.url.path;

    if (path.endsWith('/admin/event')) {
      return _json({
        'id': 3,
        'name': '가을 심사',
        'is_open': isOpen,
        'is_blind': false,
        'scoring_method': 'all',
        'scoring_note': '',
        'pass_count': null,
        'show_judge_signs': true,
        'report_signers': const <Map<String, dynamic>>[],
      });
    }

    if (path.endsWith('/admin/setup')) {
      setupCalls += 1;

      return _json({
        'criteria': const <Map<String, dynamic>>[],
        'candidates': const <Map<String, dynamic>>[],
        'judges': [
          {
            'id': 4,
            'name': '김심사',
            'code': judgeCode,
            'entry_url': null,
            'signed_at': null,
          },
        ],
        'total_max': 0,
      });
    }

    if (path.endsWith('/admin/dashboard')) {
      return _json({
        'event': {
          'name': '가을 심사',
          'is_open': isOpen,
          'total_max': 0,
          'scoring_note': '',
        },
        'rows': const <Map<String, dynamic>>[],
        'judges': const <Map<String, dynamic>>[],
        'generated_at': '',
      });
    }

    return _json({'message': '알 수 없음: $path'}, status: 404);
  });

  static http.Response _json(Map<String, dynamic> body, {int status = 200}) =>
      http.Response(
        jsonEncode(body),
        status,
        headers: {'content-type': 'application/json'},
      );
}

AdminEvent event(FakeRefreshServer server) => AdminEvent(
  id: 3,
  name: '가을 심사',
  isOpen: server.isOpen,
  isBlind: false,
  scoringMethod: 'all',
  scoringNote: '',
  showJudgeSigns: true,
  reportSigners: const [],
);

void main() {
  testWidgets('심사위원 탭을 다시 열면 서버에서 새 코드를 다시 읽는다', (tester) async {
    final server = FakeRefreshServer();
    final api = Api(client: server.client);
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: AdminHomeScreen()),
      ),
    );
    container.read(adminApiProvider.notifier).state = AdminApi(
      api,
      'token',
      event(server),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('심사위원'));
    await tester.pumpAndSettle();
    expect(find.text('483920'), findsOneWidget);

    // 외부(웹)에서 재개로 새 코드가 발급된 상황을 흉내 낸다.
    server.judgeCode = '654321';
    final callsBefore = server.setupCalls;

    await tester.tap(find.text('집계'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('심사위원'));
    await tester.pumpAndSettle();

    expect(
      server.setupCalls,
      greaterThan(callsBefore),
      reason: '방문할 때마다 다시 불러와야 한다',
    );
    expect(find.text('654321'), findsOneWidget);
    expect(find.text('483920'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('앱에서 마감하면 심사위원 코드가 회수 상태로 즉시 갱신된다', (tester) async {
    final server = FakeRefreshServer();
    final api = Api(client: server.client);
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: AdminHomeScreen()),
      ),
    );
    container.read(adminApiProvider.notifier).state = AdminApi(
      api,
      'token',
      event(server),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('심사위원'));
    await tester.pumpAndSettle();
    expect(find.text('483920'), findsOneWidget);

    // 앱에서 마감 버튼을 눌러 상태가 바뀐 상황을 흉내 낸다.
    server.isOpen = false;
    server.judgeCode = null;
    container.read(adminApiProvider.notifier).state = AdminApi(
      api,
      'token',
      event(server),
    );
    await tester.pumpAndSettle();

    expect(find.text('483920'), findsNothing);
    expect(find.text('마감되어 코드가 회수되었습니다'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
