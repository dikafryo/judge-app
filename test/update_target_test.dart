// 플레이로 깔린 앱에 우리가 직접 배포한 APK 를 덮어씌우면 서명이 달라 설치가 거부된다.
// 눌러도 "설치되지 않았습니다" 로 끝나므로, 받을 곳을 가르는 이 판정만 고정한다.

import 'package:flutter_test/flutter_test.dart';
import 'package:judge_app/core/config.dart';

void main() {
  test('플레이로 깔렸으면 플레이스토어로 보낸다', () {
    expect(updateTargetUrl(kPlayInstaller), kPlayStoreUrl);
  });

  test('직접 받아 깔았으면 우리 배포 페이지로 보낸다', () {
    expect(updateTargetUrl(null), kDownloadUrl);
    expect(updateTargetUrl('com.android.packageinstaller'), kDownloadUrl);
  });
}
