import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:judge_app/models/payload.dart';

Map<String, dynamic> sample({bool blind = false}) => {
      'judge': {'id': 7, 'name': '홍길동'},
      'event': {'name': '샘플 행사', 'is_open': true, 'is_blind': blind},
      'groups': [
        {
          'id': 1,
          'name': '기획',
          'max_score': 60,
          'has_children': true,
          'items': [
            {'id': 11, 'name': '창의성', 'max_score': 30, 'description': null},
            {'id': 12, 'name': '완성도', 'max_score': 30, 'description': '마감 상태'},
          ],
        },
        {
          'id': 2,
          'name': '발표',
          'max_score': 40,
          'has_children': false,
          'items': [
            {'id': 2, 'name': '발표', 'max_score': 40, 'description': null},
          ],
        },
      ],
      'candidates': [
        {'id': 101, 'number': '01', if (!blind) 'name': '가나다', if (!blind) 'affiliation': '가람'},
        {'id': 102, 'number': '02', if (!blind) 'name': '라마바', if (!blind) 'affiliation': '나람'},
      ],
      'scores': {
        '101': {'11': 25, '12': 20, '2': 35},
        '102': {'11': 10},
      },
      'hasSignature': false,
      'totalMax': 100,
    };

void main() {
  test('말단 항목은 자식이 있는 대분류의 자식들과, 자식이 없는 대분류 자신이다', () {
    final payload = JudgePayload.fromJson(sample());

    expect(payload.leafItems.map((e) => e.id), [11, 12, 2]);
  });

  test('말단 항목을 모두 채워야 완료다', () {
    final payload = JudgePayload.fromJson(sample());

    expect(payload.isComplete(101), isTrue);
    expect(payload.isComplete(102), isFalse, reason: '부분 입력은 미완료로 봐야 한다');
    expect(payload.completedCount, 1);
    expect(payload.totalOf(101), 80);
  });

  test('블라인드 행사는 이름이 아예 내려오지 않는다', () {
    final payload = JudgePayload.fromJson(sample(blind: true));

    expect(payload.candidates.first.name, isNull);
    expect(payload.candidates.first.label, '01번', reason: '이름이 없으면 번호로 부른다');
  });

  test('기기에 저장했다 되읽어도 상태가 같다', () {
    // 오프라인 동작이 통째로 이 왕복에 달려 있다.
    final original = JudgePayload.fromJson(sample());
    final restored = JudgePayload.fromJson(
      jsonDecode(jsonEncode(original.toJson())) as Map<String, dynamic>,
    );

    expect(restored.judgeName, original.judgeName);
    expect(restored.leafItems.length, original.leafItems.length);
    expect(restored.scores, original.scores);
    expect(restored.isComplete(101), isTrue);
  });

  test('점수 표기는 정수면 소수점을 붙이지 않는다', () {
    expect(formatScore(8), '8');
    expect(formatScore(8.5), '8.5');
  });
}
