// 온라인 심사 시스템 — 안드로이드 앱
//
// judge.sw4u.kr 을 WebView 로 감싸는 얇은 껍데기다. 심사 화면 자체는 서버의 웹 화면이며,
// 오프라인 채점(입력 보관 + 전송 대기열)은 그 웹 화면의 서비스워커와 localStorage 가 담당한다.
// 따라서 이 앱이 반드시 지켜야 할 것은 셋이다.
//   1. DOM storage 를 켠다 — 끄면 오프라인 대기열이 통째로 죽는다
//   2. User-Agent 에 JudgeApp 을 붙인다 — 서버가 앱 안에서 설치·인쇄 버튼을 감추는 신호
//   3. 외부 링크는 앱에 가두지 않고 브라우저로 넘긴다

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

const String kSiteHost = 'judge.sw4u.kr';
const String kHomeUrl = 'https://$kSiteHost/';
const String kReleaseUrl = 'https://$kSiteHost/app-release.json';
const String kDownloadUrl = 'https://$kSiteHost/app';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const JudgeApp());
}

class JudgeApp extends StatelessWidget {
  const JudgeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '온라인 심사',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF4F46E5)),
        useMaterial3: true,
      ),
      home: const JudgeWebView(),
    );
  }
}

class JudgeWebView extends StatefulWidget {
  const JudgeWebView({super.key});

  @override
  State<JudgeWebView> createState() => _JudgeWebViewState();
}

class _JudgeWebViewState extends State<JudgeWebView> {
  late final WebViewController _controller;
  final GlobalKey<ScaffoldMessengerState> _messenger = GlobalKey<ScaffoldMessengerState>();

  bool _ready = false;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_setUp());
  }

  Future<void> _setUp() async {
    final info = await PackageInfo.fromPlatform();
    final controller = WebViewController();

    await controller.setJavaScriptMode(JavaScriptMode.unrestricted);
    await controller.setBackgroundColor(const Color(0xFFF1F5F9));

    // 서버가 앱 안임을 알아보는 표식. 웹 화면에서 "앱 설치"·인쇄 버튼을 감추는 데 쓰인다.
    final ua = await controller.getUserAgent();
    await controller.setUserAgent('${ua ?? ''} JudgeApp/${info.version}'.trim());

    // 오프라인 대기열이 localStorage 를, 오프라인 화면이 서비스워커를 쓴다.
    // webview_flutter_android 는 DOM storage 를 기본으로 켜지만 공개 API 로 강제할 수단이 없으므로,
    // 실기기에서 '비행기모드 → 점수 제출 → 대기 배지' 가 실제로 되는지 반드시 확인할 것.
    final platform = controller.platform;
    if (platform is AndroidWebViewController) {
      await platform.setMediaPlaybackRequiresUserGesture(false);
    }

    await controller.setNavigationDelegate(
      NavigationDelegate(
        onPageStarted: (_) => setState(() {
          _loading = true;
          _error = null;
        }),
        onPageFinished: (_) => setState(() => _loading = false),
        onWebResourceError: (error) {
          // 하위 리소스(이미지 등) 실패까지 전체 오류 화면으로 만들지 않는다.
          if (error.isForMainFrame == false) return;
          setState(() {
            _loading = false;
            _error = '페이지를 열지 못했습니다.\n연결 상태를 확인해 주세요.';
          });
        },
        onNavigationRequest: (request) {
          final uri = Uri.tryParse(request.url);

          if (uri == null) return NavigationDecision.prevent;
          if (uri.host == kSiteHost) return NavigationDecision.navigate;

          // 심사 사이트 밖(헤더의 neis.me 로고 등)은 앱에 가두지 않고 브라우저로 넘긴다.
          unawaited(launchUrl(uri, mode: LaunchMode.externalApplication));

          return NavigationDecision.prevent;
        },
      ),
    );

    await controller.loadRequest(Uri.parse(kHomeUrl));

    if (! mounted) return;

    setState(() {
      _controller = controller;
      _ready = true;
    });

    unawaited(_checkForUpdate(info));
  }

  /// 새 버전 알림. 실패는 전부 무시한다 — 업데이트 확인 때문에 앱이 멈추면 안 된다.
  Future<void> _checkForUpdate(PackageInfo info) async {
    try {
      final response = await HttpJson.get(Uri.parse(kReleaseUrl), timeout: const Duration(seconds: 4));

      if (response == null) return;

      final latest = response['build'];
      final current = int.tryParse(info.buildNumber) ?? 0;

      if (latest is! int || latest <= current) return;
      if (! mounted) return;

      _messenger.currentState?.showSnackBar(
        SnackBar(
          content: Text('새 버전 ${response['version']} 이(가) 있습니다.'),
          duration: const Duration(seconds: 8),
          action: SnackBarAction(
            label: '받기',
            onPressed: () => unawaited(
              launchUrl(Uri.parse(kDownloadUrl), mode: LaunchMode.externalApplication),
            ),
          ),
        ),
      );
    } catch (_) {
      // 무시
    }
  }

  Future<void> _handleBack() async {
    if (await _controller.canGoBack()) {
      await _controller.goBack();

      return;
    }

    if (! mounted) return;

    final leave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('앱을 닫을까요?'),
        content: const Text('저장하지 않은 점수는 기기에 보관되어 다음에 열 때 그대로 있습니다.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('계속 심사')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('닫기')),
        ],
      ),
    );

    if (leave == true) await SystemNavigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    return ScaffoldMessenger(
      key: _messenger,
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (! didPop) unawaited(_handleBack());
        },
        child: Scaffold(
          backgroundColor: const Color(0xFFF1F5F9),
          body: SafeArea(child: _body()),
        ),
      ),
    );
  }

  Widget _body() {
    if (! _ready) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            BrandMark(size: 96),
            SizedBox(height: 24),
            SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
          ],
        ),
      );
    }

    if (_error != null) return ErrorView(message: _error!, onRetry: () => _controller.reload());

    return Stack(
      children: [
        WebViewWidget(controller: _controller),
        if (_loading) const LinearProgressIndicator(minHeight: 2),
      ],
    );
  }
}

class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const BrandMark(size: 64),
            const SizedBox(height: 20),
            const Icon(Icons.wifi_off, size: 32, color: Color(0xFF94A3B8)),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF475569))),
            const SizedBox(height: 24),
            FilledButton(onPressed: onRetry, child: const Text('다시 시도')),
          ],
        ),
      ),
    );
  }
}

/// 앱 아이콘과 같은 마크. 런처 아이콘 · 네이티브 스플래시 · 이 위젯이 모두 같은 그림이어야
/// 앱을 켜는 동안 아이콘이 끊겨 보이지 않는다. 비율은 아이콘 생성기(make-icons.php)와 같다.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, required this.size});

  final double size;

  static const _background = Color(0xFF1F2933);
  static const _cellLight = Color(0xFFF5F3EF);
  static const _cellAccent = Color(0xFF4F46E5);

  @override
  Widget build(BuildContext context) {
    final padding = size * (0.36 / 1.72);
    final gap = size * (0.18 / 1.72);
    final cell = (size - padding * 2 - gap) / 2;

    Widget square(Color color) => Container(
          width: cell,
          height: cell,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(cell * 0.12)),
        );

    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: _background,
        borderRadius: BorderRadius.circular(size * (0.18 / 1.72)),
      ),
      child: Column(
        children: [
          Row(children: [square(_cellLight), SizedBox(width: gap), square(_cellLight)]),
          SizedBox(height: gap),
          Row(children: [square(_cellLight), SizedBox(width: gap), square(_cellAccent)]),
        ],
      ),
    );
  }
}

/// 업데이트 확인 한 곳에서만 쓰는 최소 JSON GET.
/// 이것 하나 때문에 http 패키지를 더 얹지 않는다.
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
