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

  group('서버 /meta 로 지원 종료 판정', () {
    test('버전이 같고 최소 빌드 이상이면 지원된다', () {
      expect(
        isUnsupportedBuild({'api_version': kApiVersion, 'min_app_build': 1}, 5),
        isFalse,
      );
      expect(
        isUnsupportedBuild({'api_version': kApiVersion, 'min_app_build': 5}, 5),
        isFalse,
        reason: '최소 빌드와 같으면 아직 지원 대상이다',
      );
    });

    test('최소 빌드보다 낮으면 지원 종료', () {
      expect(
        isUnsupportedBuild({'api_version': kApiVersion, 'min_app_build': 6}, 5),
        isTrue,
      );
    });

    test('API 버전이 다르면 지원 종료', () {
      expect(
        isUnsupportedBuild({'api_version': 'v2', 'min_app_build': 1}, 5),
        isTrue,
      );
    });

    test('응답을 못 받았거나 모양이 이상하면 막지 않는다', () {
      expect(isUnsupportedBuild(null, 5), isFalse);
      expect(isUnsupportedBuild({}, 5), isFalse);
      expect(isUnsupportedBuild({'min_app_build': '9'}, 5), isFalse);
    });
  });
}
