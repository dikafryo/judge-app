// 온라인 심사 시스템 — 안드로이드 앱
//
// 심사위원 화면은 **네이티브**다. 입장할 때 받은 payload 를 기기에 저장해 두므로
// 연결이 끊겨도 목록·항목·이미 넣은 점수가 그대로 보이고, 새로 넣은 점수는 대기열에 쌓였다가
// 연결이 돌아오면 자동으로 전송된다.
//
// 관리자 화면도 네이티브다. 집계는 오프라인을 지원하지 않는다 — 오래된 순위를 최신인 줄 알고
// 발표하는 사고가 연결 오류보다 훨씬 무섭기 때문이다.
// 인쇄물(최종집계표·CSV·심사위원 카드)만 서버의 A4 출력을 시스템 브라우저로 넘긴다.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'admin/admin_events_screen.dart';
import 'core/brand.dart';
import 'core/config.dart';
import 'core/design.dart';
import 'judge/candidates_screen.dart';
import 'judge/entry_screen.dart';
import 'store/judge_session.dart';
import 'store/local_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Android 15 부터는 앱이 시스템 바 뒤까지 그린다(edge-to-edge). 그 아래 버전에서도
  // 같은 모양이 나오게 명시하고, 바를 투명하게 둔다. 각 화면은 SafeArea·앱바·하단 바로
  // 인셋을 비켜 그린다.
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(kLightSystemBars);

  final store = await LocalStore.open();

  runApp(
    ProviderScope(
      overrides: [localStoreProvider.overrideWithValue(store)],
      child: const JudgeApp(),
    ),
  );
}

class JudgeApp extends StatelessWidget {
  const JudgeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '온라인 심사',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: const _Root(),
    );
  }
}

class _Root extends ConsumerStatefulWidget {
  const _Root();

  @override
  ConsumerState<_Root> createState() => _RootState();
}

class _RootState extends ConsumerState<_Root> with WidgetsBindingObserver {
  /// 받을 수 있는 새 버전. null 이면 최신이거나 아직 확인 전이다.
  _Update? _update;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    // 첫 프레임 뒤에 시작한다 — build 도중 상태를 바꾸면 안 된다.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(ref.read(judgeSessionProvider.notifier).restore());
      unawaited(_checkForUpdate());
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// 앱으로 돌아올 때마다 못 보낸 것을 다시 보낸다.
  /// 연결 복구를 감지할 별도 수단 없이도 대부분의 경우가 여기서 해결된다.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(ref.read(judgeSessionProvider.notifier).sync());
    }
  }

  /// 새 버전 확인. 실패는 전부 무시한다 — 업데이트 확인 때문에 앱이 멈추면 안 된다.
  ///
  /// 받을 곳은 **어디서 깔렸는지**에 따라 다르다. 플레이로 깔린 앱은 서명이 플레이 것이라
  /// 우리가 직접 배포한 APK 를 덮어씌울 수 없다 — 눌러도 "설치되지 않았습니다" 로 끝난다.
  ///
  /// 서버 /meta 도 함께 본다. API 가 바뀌었거나 최소 빌드보다 낮으면 옛 앱이 조용히
  /// 오작동하는 대신 "지원 종료" 로 강하게 안내한다(닫기 단추 없음).
  Future<void> _checkForUpdate() async {
    const timeout = Duration(seconds: 4);

    final info = await PackageInfo.fromPlatform();
    final (release, meta) = await (
      HttpJson.get(Uri.parse(kReleaseUrl), timeout: timeout),
      HttpJson.get(Uri.parse(kMetaUrl), timeout: timeout),
    ).wait;

    if (!mounted) return;

    final current = int.tryParse(info.buildNumber) ?? 0;
    final unsupported = isUnsupportedBuild(meta, current);
    final latest = release?['build'];
    final newer = latest is int && latest > current;

    if (!unsupported && !newer) return;

    final url = updateTargetUrl(info.installerStore);

    // 받을 곳이 없으면 안내하지 않는다 — 아이폰은 앱스토어에 올라가기 전까지 받을 곳이 없다.
    if (url == null) return;

    final version = release?['version'];

    setState(() {
      _update = _Update(
        version: version is String ? version : '',
        url: url,
        fromPlay: info.installerStore == kPlayInstaller,
        unsupported: unsupported,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    // 마감·코드 만료 같은 안내는 화면이 바뀌어도 한 번은 보여야 한다.
    ref.listen(judgeSessionProvider, (previous, next) {
      final notice = next.notice;

      if (notice == null || notice == previous?.notice) return;

      // 못 보낸 점수를 남긴 채 쫓겨난 경우는 6초 만에 사라지면 안 된다 — 직접 닫을 때까지 둔다.
      final lostScores =
          next.status == SessionStatus.signedOut && next.queue.isNotEmpty;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(notice),
          duration: lostScores
              ? const Duration(days: 1)
              : const Duration(seconds: 6),
          showCloseIcon: lostScores,
        ),
      );

      ref.read(judgeSessionProvider.notifier).clearNotice();
    });

    final status = ref.watch(
      judgeSessionProvider.select((state) => state.status),
    );

    final screen = switch (status) {
      SessionStatus.loading => const _Splash(),
      SessionStatus.signedOut => EntryScreen(
        onAdmin: () => Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const AdminEventsScreen())),
      ),
      SessionStatus.ready => const CandidatesScreen(),
    };

    final update = _update;

    // 스낵바로 알리던 것을 화면 아래 띠로 바꿨다. 스낵바는 8초 뒤 사라져서,
    // 채점 중에 뜨면 못 보고 넘기기 일쑤였다.
    if (update == null) return screen;

    // 띠가 내비게이션바 자리를 차지하므로, 위 화면은 그 인셋을 다시 비워 두지 않는다.
    return Column(
      children: [
        Expanded(
          child: MediaQuery.removePadding(
            context: context,
            removeBottom: true,
            child: screen,
          ),
        ),
        _UpdateBanner(
          update: update,
          onDismiss: update.unsupported
              ? null
              : () => setState(() => _update = null),
        ),
      ],
    );
  }
}

/// 받을 수 있는 새 버전과, 그것을 받을 곳.
class _Update {
  const _Update({
    required this.version,
    required this.url,
    required this.fromPlay,
    this.unsupported = false,
  });

  final String version;
  final String url;

  /// 서버가 이 빌드를 더 이상 받지 않는다(/meta). 닫지 못하게 한다.
  final bool unsupported;

  /// 플레이로 깔린 앱인가. 버튼 글씨를 어디로 보내는지 밝히는 데 쓴다.
  final bool fromPlay;
}

class _UpdateBanner extends StatelessWidget {
  const _UpdateBanner({required this.update, required this.onDismiss});

  final _Update update;

  /// null 이면 닫기 단추를 두지 않는다(지원 종료).
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColor.ink,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
          child: Row(
            children: [
              const Icon(
                Icons.system_update_alt,
                size: 20,
                color: Colors.white,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      update.unsupported
                          ? '이 버전은 더 이상 지원되지 않습니다. 업데이트해 주세요.'
                          : update.version.isEmpty
                          ? '새 버전이 있습니다'
                          : '새 버전 v${update.version}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      update.fromPlay
                          ? '플레이스토어에서 업데이트합니다'
                          : Platform.isIOS
                          ? '앱스토어에서 업데이트합니다'
                          : '받는 곳으로 이동합니다',
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: AppColor.faint,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 40),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  backgroundColor: AppColor.accent,
                ),
                onPressed: () => unawaited(
                  launchUrl(
                    Uri.parse(update.url),
                    mode: LaunchMode.externalApplication,
                  ),
                ),
                child: const Text('업데이트'),
              ),
              if (onDismiss != null)
                IconButton(
                  tooltip: '나중에',
                  icon: const Icon(
                    Icons.close,
                    size: 18,
                    color: AppColor.faint,
                  ),
                  onPressed: onDismiss,
                )
              else
                const SizedBox(width: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            BrandMark(size: 96),
            SizedBox(height: 24),
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ],
        ),
      ),
    );
  }
}

/// 업데이트 확인 한 곳에서만 쓰는 최소 JSON GET.
/// API 클라이언트(core/api.dart)는 토큰 인증 전용이라 여기 쓰지 않는다.
class HttpJson {
  static Future<Map<String, dynamic>?> get(
    Uri uri, {
    required Duration timeout,
  }) async {
    final client = HttpClient()..connectionTimeout = timeout;

    try {
      final request = await client.getUrl(uri);
      final response = await request.close().timeout(timeout);

      if (response.statusCode != 200) return null;

      final body = await response
          .transform(utf8.decoder)
          .join()
          .timeout(timeout);
      final decoded = jsonDecode(body);

      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    } finally {
      client.close(force: true);
    }
  }
}
