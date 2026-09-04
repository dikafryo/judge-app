import 'package:flutter_test/flutter_test.dart';
import 'package:judge_app/judge/scan_screen.dart';

void main() {
  group('QR 코드에서 접속 코드 뽑기', () {
    test('인쇄된 심사위원 카드의 QR 은 주소를 담고 있다', () {
      // 이미 배포된 카드를 다시 만들 수 없으므로 이 형식은 반드시 통해야 한다.
      expect(ScanScreen.extractCode('https://judge.sw4u.kr/judge/483920'), '483920');
    });

    test('숫자만 든 QR 도 받는다', () {
      expect(ScanScreen.extractCode('483920'), '483920');
      expect(ScanScreen.extractCode('  483920  '), '483920');
    });

    test('심사와 무관한 QR 은 무시한다', () {
      expect(ScanScreen.extractCode('https://example.com/'), isNull);
      expect(ScanScreen.extractCode('WIFI:S:cafe;'), isNull);
      expect(ScanScreen.extractCode(null), isNull);
    });
  });
}
