// 다이얼로그의 "누를 수 있는가" 판정은 고장 나면 사용자에게 바로 보인다 —
// 버튼이 흐린 채로 있으면 왜 안 되는지 모른 채 막힌다. 그 판정만 고정한다.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:judge_app/admin/admin_setup_tabs.dart';
import 'package:judge_app/core/api.dart';
import 'package:judge_app/core/design.dart';
import 'package:judge_app/models/admin.dart';
import 'package:judge_app/store/admin_api.dart';

/// 설정 탭이 읽고 지우는 가짜 서버. 삭제 요청이 언제 나갔는지만 기록한다.
class FakeSetupServer {
  final List<String> deletes = [];

  static const _setup = {
    'criteria': [
      {
        'id': 1,
        'name': '기획',
        'description': null,
        'max_score': 60,
        'parent_id': null,
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
        'signed_at': null,
        'entry_url': 'https://judge.sw4u.kr/judge/4',
      },
    ],
    'total_max': 60,
  };

  http.Client get client => MockClient((request) async {
    if (request.method == 'DELETE') deletes.add(request.url.path);

    return http.Response(
      jsonEncode(_setup),
      200,
      headers: {'content-type': 'application/json'},
    );
  });
}

const _event = AdminEvent(
  id: 3,
  name: '가을 심사',
  isOpen: true,
  isBlind: false,
  scoringMethod: 'all',
  scoringNote: '',
  showJudgeSigns: true,
  reportSigners: [],
);

/// 창을 띄우고 확인 버튼을 돌려준다.
Future<FilledButton> openAndFind(
  WidgetTester tester,
  Widget Function(BuildContext) dialog,
  String confirmLabel,
) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: buildAppTheme(),
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () => showDialog<void>(context: context, builder: dialog),
          child: const Text('열기'),
        ),
      ),
    ),
  );

  await tester.tap(find.text('열기'));
  await tester.pumpAndSettle();

  return tester.widget<FilledButton>(
    find.widgetWithText(FilledButton, confirmLabel),
  );
}

void main() {
  group('배점 항목 추가', () {
    Widget dialog(BuildContext context) =>
        criterionDialogForTest(parent: null, limit: 40);

    testWidgets('이름과 배점이 다 있어야 추가할 수 있다', (tester) async {
      var button = await openAndFind(tester, dialog, '추가');
      expect(button.onPressed, isNull, reason: '비어 있으면 누를 수 없다');

      await tester.enterText(
        find.descendant(
          of: find.byType(AppField).at(0),
          matching: find.byType(TextField),
        ),
        '기획',
      );
      await tester.pump();

      button = tester.widget(find.widgetWithText(FilledButton, '추가'));
      expect(button.onPressed, isNull, reason: '배점이 아직 없다');

      await tester.enterText(
        find.descendant(
          of: find.byType(AppField).at(1),
          matching: find.byType(TextField),
        ),
        '30',
      );
      await tester.pump();

      button = tester.widget(find.widgetWithText(FilledButton, '추가'));
      expect(button.onPressed, isNotNull);
    });

    testWidgets('남은 배점을 넘으면 이유를 보여 준다', (tester) async {
      await openAndFind(tester, dialog, '추가');

      await tester.enterText(
        find.descendant(
          of: find.byType(AppField).at(0),
          matching: find.byType(TextField),
        ),
        '기획',
      );
      await tester.enterText(
        find.descendant(
          of: find.byType(AppField).at(1),
          matching: find.byType(TextField),
        ),
        '50',
      );
      await tester.pump();

      expect(find.text('남은 배점(40점)을 넘을 수 없습니다.'), findsOneWidget);

      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, '추가'),
      );
      expect(button.onPressed, isNull);
    });
  });

  testWidgets('AppField 의 라벨은 스크린리더에도 전달된다', (tester) async {
    final handle = tester.ensureSemantics();
    final controller = TextEditingController();

    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(
          body: AppField(label: '배점', controller: controller),
        ),
      ),
    );

    // 화면에 그린 글자 말고, 칸 자체가 이름을 갖고 있어야 한다
    expect(
      tester.getSemantics(find.byType(TextField)),
      matchesSemantics(
        label: '배점',
        isTextField: true,
        hasEnabledState: true,
        isEnabled: true,
        isFocusable: true,
        hasTapAction: true,
        hasFocusAction: true,
      ),
    );

    handle.dispose();
  });

  // 삭제는 점수까지 함께 사라져 되돌릴 수 없다. 휴지통을 누르자마자 지워지면 안 된다.
  group('삭제는 확인한 뒤에만 서버로 보낸다', () {
    final cases = <(String, Widget, String, String)>[
      ('평가 항목', const AdminCriteriaTab(), '기획', '/api/v1/admin/criteria/1'),
      (
        '평가 대상',
        const AdminCandidatesTab(),
        '가나다',
        '/api/v1/admin/candidates/9',
      ),
      ('심사위원', const AdminJudgesTab(), '김심사', '/api/v1/admin/judges/4'),
    ];

    for (final (label, tab, name, path) in cases) {
      testWidgets(label, (tester) async {
        final server = FakeSetupServer();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              adminApiProvider.overrideWith(
                (ref) => AdminApi(Api(client: server.client), 'token', _event),
              ),
            ],
            child: MaterialApp(
              theme: buildAppTheme(),
              home: Scaffold(body: tab),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byTooltip('삭제').first);
        await tester.pumpAndSettle();

        expect(find.text('$name 을(를) 삭제할까요?'), findsOneWidget);
        expect(server.deletes, isEmpty, reason: '창만 떴고 아직 지우지 않았다');

        await tester.tap(find.widgetWithText(OutlinedButton, '취소'));
        await tester.pumpAndSettle();
        expect(server.deletes, isEmpty, reason: '취소하면 아무것도 지우지 않는다');

        await tester.tap(find.byTooltip('삭제').first);
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(FilledButton, '삭제'));
        await tester.pumpAndSettle();

        expect(server.deletes, [path]);
      });
    }
  });
}
