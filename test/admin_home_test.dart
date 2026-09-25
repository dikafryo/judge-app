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

AdminEvent event({required bool isOpen, bool isDemo = false}) => AdminEvent(
  id: 3,
  name: '가을 심사',
  isOpen: isOpen,
  isDemo: isDemo,
  isBlind: false,
  scoringMethod: 'all',
  scoringNote: '',
  showJudgeSigns: true,
  reportSigners: const [],
);

void main() {
  test('마감 또는 재개하면 설정 탭을 새 상태로 교체한다', () {
    expect(
      adminSetupRevision(event(isOpen: true), 0),
      const ValueKey('setup-3-true-0'),
    );
    expect(
      adminSetupRevision(event(isOpen: false), 0),
      const ValueKey('setup-3-false-0'),
    );
    expect(
      adminSetupRevision(event(isOpen: true), 2),
      const ValueKey('setup-3-true-2'),
      reason: '심사위원 탭을 다시 방문할 때도 새로 읽도록 키가 바뀌어야 한다',
    );
  });

  group('관리자 홈', () {
    late List<String> calls;

    http.Client client() => MockClient((request) async {
      calls.add('${request.method} ${request.url.path}');
      final path = request.url.path;
      final body = path.endsWith('/admin/dashboard')
          ? {
              'event': {'name': '가을 심사', 'is_open': true, 'total_max': 0},
              'rows': const <Object>[],
              'judges': const <Object>[],
              'generated_at': '',
            }
          : {'message': 'ok'};

      return http.Response(
        jsonEncode(body),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    Future<ProviderContainer> open(WidgetTester tester, AdminEvent e) async {
      calls = [];
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(adminApiProvider.notifier).state = AdminApi(
        Api(client: client()),
        'token',
        e,
      );

      // 나가기가 pop 할 수 있도록 앞 화면을 하나 깔아 둔다.
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Builder(
              builder: (context) => TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const AdminHomeScreen(),
                  ),
                ),
                child: const Text('들어가기'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('들어가기'));
      await tester.pumpAndSettle();

      return container;
    }

    testWidgets('체험 행사면 둘러보기만 된다고 알린다', (tester) async {
      await open(tester, event(isOpen: true, isDemo: true));

      expect(find.text('체험 행사는 둘러보기만 할 수 있습니다'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('실제 행사에는 체험 안내가 없다', (tester) async {
      await open(tester, event(isOpen: true));

      expect(find.text('체험 행사는 둘러보기만 할 수 있습니다'), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('나가면 서버에서 토큰을 폐기한 뒤 로그아웃한다', (tester) async {
      final container = await open(tester, event(isOpen: true));

      await tester.tap(find.byTooltip('나가기'));
      await tester.pumpAndSettle();

      expect(calls, contains('DELETE /api/v1/session'));
      expect(container.read(adminApiProvider), isNull);
      expect(find.text('들어가기'), findsOneWidget, reason: '앞 화면으로 돌아간다');
    });
  });
}
