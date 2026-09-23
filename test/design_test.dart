// 마지막 전송 시각을 사람 말로 바꾸는 규칙. 이 글이 틀리면 심사위원이 오래된 화면을
// 최신인 줄 알게 되므로, 경계값을 못으로 박아 둔다.

import 'package:flutter_test/flutter_test.dart';
import 'package:judge_app/core/design.dart';

void main() {
  final now = DateTime(2026, 9, 23, 14, 30);

  test('한 번도 못 보냈으면 그렇다고 말한다', () {
    expect(formatSyncedAt(null, now: now), '아직 전송 전');
  });

  test('45초 안쪽은 방금 전', () {
    expect(
      formatSyncedAt(now.subtract(const Duration(seconds: 44)), now: now),
      '방금 전 전송됨',
    );
  });

  test('한 시간 안쪽은 분으로 센다', () {
    expect(
      formatSyncedAt(now.subtract(const Duration(minutes: 7)), now: now),
      '7분 전 전송됨',
    );
  });

  test('한 시간이 넘으면 시각을 그대로 보여 준다', () {
    expect(
      formatSyncedAt(now.subtract(const Duration(minutes: 97)), now: now),
      '12:53 전송됨',
      reason: '"97분 전"은 세어 봐야 안다',
    );
  });
}
