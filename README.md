# 온라인 심사 시스템 — 안드로이드 앱

**네이티브**(Flutter)다.
서버는 `https://judge.sw4u.kr` 와 호환되며 `/api/v1` REST API 통신

배포는 `https://judge.sw4u.kr/app` 에서 APK 직접 배포

> **웹은 아이폰, 데스크탑** 사용자를 위해 필요

## 구조

```
lib/
  core/      config(서버 주소 고정) · api(Bearer 토큰 클라이언트) · brand(아이콘 마크)
  models/    payload — /api/v1/judge/me 응답 = 오프라인 동작의 전부
  store/     local_store(기기 저장) · judge_session(상태·전송 대기열) · queued_op
  judge/     entry · scan(QR) · candidates · scoring · signature
  admin/     events(행사 선택·생성) · home(탭) · dashboard · setup_tabs · settings
```

### 심사위원과 관리자는 저장 정책이 정반대다

| | 심사위원 | 관리자 |
|---|---|---|
| 기기 저장 | payload 전체 + 전송 대기열 | **아무것도 저장하지 않는다** |
| 오프라인 | 앱 전체가 동작 | 동작하지 않음 (연결 필요를 명시) |
| 토큰 | 기기에 보관(다음에 열면 자동 입장) | 보관하지 않음(매번 비밀번호) |

관리자는 온라인만 지원하며, 그 이유는
**오래된 과거의 순위가 기기에 저장되는것을 막으며, 항상 최신버전의 데이터만 유지**

### 인쇄물은 웹으로 보여준다. 휴대폰으로 출력하는 경우는 아직도 흔하지 않음

최종집계표는 결재란이 있는 A4 출력물은 웹에서만 지원

## 개발(flutter, jdk 를 패스로 설정 후 개발진행해야 함)

```bash
export PATH="/path/to/flutter/bin:$PATH"
export JAVA_HOME=/path/to/jdk

flutter pub get --offline   # 의존성은 pub 캐시에 있는 버전으로 고정되어 있다
flutter analyze
flutter test
flutter build apk --debug   # 릴리스 키 없이 컴파일만 확인
```

### QR 인식은 ML Kit 사용으로 구글서비스에서 받아오므로, 인터넷이 연결되어있지 않으면 QR스캔 불가함.

이유는 QR코드를 찍는순간 DB에서 데이터를 가져와야 하는데, ML Kit을 로컬로 깔아봐야, 인터넷으로 데이터를 못가져오면 QR찍고 에러가 발생하니 어짜피 받아오는게 맞음
