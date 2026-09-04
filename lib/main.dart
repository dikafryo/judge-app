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

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'admin/admin_events_screen.dart';
import 'core/brand.dart';
import 'core/config.dart';
import 'judge/candidates_screen.dart';
import 'judge/entry_screen.dart';
import 'store/judge_session.dart';
import 'store/local_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

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
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: BrandMark.cellAccent),
        scaffoldBackgroundColor: const Color(0xFFF1F5F9),
        appBarTheme: const AppBarTheme(backgroundColor: Colors.white, surfaceTintColor: Colors.white),
        useMaterial3: true,
      ),
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

  /// 새 버전 알림. 실패는 전부 무시한다 — 업데이트 확인 때문에 앱이 멈추면 안 된다.
  Future<void> _checkForUpdate() async {
    final info = await PackageInfo.fromPlatform();
    final release = await HttpJson.get(Uri.parse(kReleaseUrl), timeout: const Duration(seconds: 4));

    if (release == null || !mounted) return;

    final latest = release['build'];
    final current = int.tryParse(info.buildNumber) ?? 0;

    if (latest is! int || latest <= current) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('새 버전 ${release['version']} 이(가) 있습니다.'),
        duration: const Duration(seconds: 8),
        action: SnackBarAction(
          label: '받기',
          onPressed: () => unawaited(
            launchUrl(Uri.parse(kDownloadUrl), mode: LaunchMode.externalApplication),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 마감·코드 만료 같은 안내는 화면이 바뀌어도 한 번은 보여야 한다.
    ref.listen(judgeSessionProvider, (previous, next) {
      final notice = next.notice;

      if (notice == null || notice == previous?.notice) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(notice), duration: const Duration(seconds: 6)),
      );

      ref.read(judgeSessionProvider.notifier).clearNotice();
    });

    final status = ref.watch(judgeSessionProvider.select((state) => state.status));

    return switch (status) {
      SessionStatus.loading => const _Splash(),
      SessionStatus.signedOut => EntryScreen(
          onAdmin: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const AdminEventsScreen()),
          ),
        ),
      SessionStatus.ready => const CandidatesScreen(),
    };
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
            SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
          ],
        ),
      ),
    );
  }
}

/// 업데이트 확인 한 곳에서만 쓰는 최소 JSON GET.
/// API 클라이언트(core/api.dart)는 토큰 인증 전용이라 여기 쓰지 않는다.
class HttpJson {
  static Future<Map<String, dynamic>?> get(Uri uri, {required Duration timeout}) async {
    final client = HttpClient()..connectionTimeout = timeout;

    try {
      final request = await client.getUrl(uri);
      final response = await request.close().timeout(timeout);

      if (response.statusCode != 200) return null;

      final body = await response.transform(utf8.decoder).join().timeout(timeout);
      final decoded = jsonDecode(body);

      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    } finally {
      client.close(force: true);
    }
  }
}
