import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:judge_app/admin/admin_home_screen.dart';
import 'package:judge_app/models/admin.dart';

AdminEvent event({required bool isOpen}) => AdminEvent(
  id: 3,
  name: '가을 심사',
  isOpen: isOpen,
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
}
