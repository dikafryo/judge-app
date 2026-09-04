// 이 앱은 화면 대부분이 WebView(서버의 웹 화면)라 위젯 테스트로 덮을 표면이 거의 없다.
// 자체 UI인 오류 화면과, 잘못 건드리면 앱이 엉뚱한 곳을 보게 되는 상수만 지킨다.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:judge_app/main.dart';

void main() {
  test('앱이 바라보는 주소가 심사 사이트로 고정되어 있다', () {
    expect(kSiteHost, 'judge.sw4u.kr');
    expect(Uri.parse(kHomeUrl).host, kSiteHost);
    expect(Uri.parse(kReleaseUrl).host, kSiteHost);
    expect(Uri.parse(kDownloadUrl).host, kSiteHost);

    // 앱 안에서 평문 HTTP 로 나가면 안 된다 (매니페스트에 cleartext 허용을 두지 않았다)
    for (final url in [kHomeUrl, kReleaseUrl, kDownloadUrl]) {
      expect(Uri.parse(url).scheme, 'https', reason: url);
    }
  });

  testWidgets('오류 화면은 사유를 보여주고 다시 시도를 누르면 재시도한다', (tester) async {
    var retried = 0;

    await tester.pumpWidget(MaterialApp(
      home: ErrorView(message: '페이지를 열지 못했습니다.', onRetry: () => retried++),
    ));

    expect(find.text('페이지를 열지 못했습니다.'), findsOneWidget);

    await tester.tap(find.text('다시 시도'));
    await tester.pump();

    expect(retried, 1);
  });
}
