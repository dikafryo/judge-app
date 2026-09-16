// 다이얼로그의 "누를 수 있는가" 판정은 고장 나면 사용자에게 바로 보인다 —
// 버튼이 흐린 채로 있으면 왜 안 되는지 모른 채 막힌다. 그 판정만 고정한다.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:judge_app/admin/admin_setup_tabs.dart';
import 'package:judge_app/core/design.dart';

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
}
