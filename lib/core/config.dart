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

/// 플레이스토어가 설치한 앱의 installerStore 값.
///
/// 플레이는 앱 서명 키를 자기 것으로 바꿔서 배포한다(Play App Signing). 그래서
/// 플레이로 깔린 앱 위에 우리가 직접 배포한 APK 를 덮어씌우면 서명이 달라
/// **설치가 거부된다.** 어디서 깔렸는지에 따라 업데이트를 받을 곳도 달라야 한다.
const String kPlayInstaller = 'com.android.vending';

/// 새 버전을 받을 곳. 플레이로 깔린 앱은 플레이로 보내야 한다.
/// 설치 경로를 알 수 없으면(=null) 우리 배포 페이지로 보낸다 — 직접 받아 깐 경우다.
String updateTargetUrl(String? installerStore) =>
    installerStore == kPlayInstaller ? kPlayStoreUrl : kDownloadUrl;

/// 서버가 기대하는 API 버전. 서버 /api/v1/meta 의 api_version 과 다르면 앱을 갱신해야 한다.
const String kApiVersion = 'v1';
