import 'dart:io' show Platform;

/// 접속 서버는 고정이다. 사용자가 서버 주소를 고를 일이 없고,
/// 임의 주소를 허용하면 접속 코드를 엉뚱한 곳에 보내는 사고가 생긴다.
const String kSiteHost = 'judge.sw4u.kr';
const String kSiteUrl = 'https://$kSiteHost';
const String kApiBase = '$kSiteUrl/api/v1';
const String kReleaseUrl = '$kSiteUrl/app-release.json';
const String kDownloadUrl = '$kSiteUrl/app';

/// 안드로이드 패키지명. 플레이스토어 주소를 만드는 데 쓴다.
const String kPackageName = 'kr.sw4u.judge_app';
const String kPlayStoreUrl =
    'https://play.google.com/store/apps/details?id=$kPackageName';

/// 아이폰 앱스토어 주소. 아직 출시 전이라 비어 있다.
///
/// 비어 있는 동안은 아이폰에서 업데이트 안내를 띄우지 않는다 — 안드로이드 APK 를 받는
/// 페이지로 보내 봐야 아이폰에서는 할 수 있는 일이 없기 때문이다. 출시 후 이 값을 채우면
/// 아이폰도 안드로이드와 같이 새 버전 안내를 받는다.
const String kAppStoreUrl = '';

/// 플레이스토어가 설치한 앱의 installerStore 값.
///
/// 플레이는 앱 서명 키를 자기 것으로 바꿔서 배포한다(Play App Signing). 그래서
/// 플레이로 깔린 앱 위에 우리가 직접 배포한 APK 를 덮어씌우면 서명이 달라
/// **설치가 거부된다.** 어디서 깔렸는지에 따라 업데이트를 받을 곳도 달라야 한다.
const String kPlayInstaller = 'com.android.vending';

/// 새 버전을 받을 곳. 안드로이드는 어디서 깔렸는지에 따라 플레이/배포 페이지로 보낸다.
/// 아이폰은 앱스토어 하나뿐이라 설치 경로를 따질 필요가 없다.
/// 받을 곳이 아직 없으면(=null) 안내를 띄우지 않는다.
String? updateTargetUrl(String? installerStore) {
  if (Platform.isIOS) {
    return kAppStoreUrl.isEmpty ? null : kAppStoreUrl;
  }

  return installerStore == kPlayInstaller ? kPlayStoreUrl : kDownloadUrl;
}

/// 서버가 기대하는 API 버전. 서버 /api/v1/meta 의 api_version 과 다르면 앱을 갱신해야 한다.
const String kApiVersion = 'v1';
