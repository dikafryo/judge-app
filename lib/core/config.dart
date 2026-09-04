/// 접속 서버는 고정이다. 사용자가 서버 주소를 고를 일이 없고,
/// 임의 주소를 허용하면 접속 코드를 엉뚱한 곳에 보내는 사고가 생긴다.
const String kSiteHost = 'judge.sw4u.kr';
const String kSiteUrl = 'https://$kSiteHost';
const String kApiBase = '$kSiteUrl/api/v1';
const String kReleaseUrl = '$kSiteUrl/app-release.json';
const String kDownloadUrl = '$kSiteUrl/app';

/// 서버가 기대하는 API 버전. 서버 /api/v1/meta 의 api_version 과 다르면 앱을 갱신해야 한다.
const String kApiVersion = 'v1';
