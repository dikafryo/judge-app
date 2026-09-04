import 'dart:async';

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../core/brand.dart';
import '../core/config.dart';

/// 관리자 화면 — **아직 웹이다.**
///
/// 심사위원 화면은 네이티브로 옮겼지만 관리자 화면(설정·집계·인쇄)은 다음 단계에서 옮긴다.
/// 인쇄물은 결재란이 있는 공식 문서라 웹의 A4 레이아웃을 그대로 쓰는 편이 안전하다.
class AdminWebView extends StatefulWidget {
  const AdminWebView({super.key});

  @override
  State<AdminWebView> createState() => _AdminWebViewState();
}

class _AdminWebViewState extends State<AdminWebView> {
  WebViewController? _controller;

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

    // 서버가 앱 안임을 알아보는 표식. 웹 화면에서 "앱 설치" 안내를 감추는 데 쓰인다.
    final ua = await controller.getUserAgent();
    await controller.setUserAgent('${ua ?? ''} JudgeApp/${info.version}'.trim());

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

          // 심사 사이트 밖은 앱에 가두지 않고 브라우저로 넘긴다.
          unawaited(launchUrl(uri, mode: LaunchMode.externalApplication));

          return NavigationDecision.prevent;
        },
      ),
    );

    await controller.loadRequest(Uri.parse('$kSiteUrl/events'));

    if (!mounted) return;

    setState(() => _controller = controller);
  }

  Future<void> _back() async {
    final controller = _controller;

    if (controller != null && await controller.canGoBack()) {
      await controller.goBack();

      return;
    }

    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_back());
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF1F5F9),
        appBar: AppBar(
          title: const Text('행사 관리'),
          leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: _back),
        ),
        body: SafeArea(
          child: switch ((controller, _error)) {
            (_, final String message) => ErrorView(
                message: message,
                onRetry: () => controller?.reload(),
              ),
            (null, _) => const Center(child: CircularProgressIndicator()),
            (final WebViewController ready, _) => Stack(
                children: [
                  WebViewWidget(controller: ready),
                  if (_loading) const LinearProgressIndicator(minHeight: 2),
                ],
              ),
          },
        ),
      ),
    );
  }
}
