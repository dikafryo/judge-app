import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:judge_app/admin/admin_settings_dialogs.dart';
import 'package:judge_app/core/design.dart';
import 'package:judge_app/models/admin.dart';

const event = AdminEvent(
  id: 3,
  name: '가을 심사',
  isOpen: true,
  isBlind: false,
  scoringMethod: 'all',
  scoringNote: '',
  showJudgeSigns: true,
  reportSigners: [],
);

void main() {
  testWidgets('서명란을 생략하면 기록자 이름을 요구한다', (tester) async {
    (bool, List<ReportSigner>)? result;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async =>
                result = await showReportSettingsDialog(context, event),
            child: const Text('열기'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Switch));
    await tester.pump();

    // 창이 길어 버튼이 화면 밖에 있을 수 있다 — 스크롤해 올려놓고 누른다
    await tester.ensureVisible(find.text('저장'));
    await tester.tap(find.text('저장'));
    await tester.pump();

    expect(find.text('서명란을 생략하려면 기록자 이름을 입력하세요.'), findsOneWidget);

    // 결재란 한 줄은 부서·직급·이름 순서다. 첫 줄(기록자)의 이름 칸이 세 번째.
    final recorderName = find.descendant(
      of: find.byType(AppField).at(2),
      matching: find.byType(TextField),
    );

    await tester.enterText(recorderName, '김기록');
    await tester.ensureVisible(find.text('저장'));
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();

    expect(result?.$1, isFalse);
    expect(result?.$2.single.name, '김기록');
  });

  testWidgets('행사명이 정확히 일치해야 영구 삭제를 확인할 수 있다', (tester) async {
    String? result;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async =>
                result = await showEventDeletionDialog(context, event),
            child: const Text('삭제'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('삭제'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '다른 행사');
    await tester.pump();

    final deleteButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, '영구 삭제'),
    );
    expect(deleteButton.onPressed, isNull);

    await tester.enterText(find.byType(TextField), '가을 심사');
    await tester.pump();
    await tester.tap(find.text('영구 삭제'));
    await tester.pumpAndSettle();

    expect(result, '가을 심사');
  });
}
