import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api.dart';
import '../core/brand.dart';
import '../core/design.dart';
import '../store/judge_session.dart';
import 'scan_screen.dart';

/// 입장 화면. 접속 코드를 직접 넣거나 심사위원 카드의 QR 을 찍는다.
class EntryScreen extends ConsumerStatefulWidget {
  const EntryScreen({super.key, this.onAdmin});

  final VoidCallback? onAdmin;

  @override
  ConsumerState<EntryScreen> createState() => _EntryScreenState();
}

class _EntryScreenState extends ConsumerState<EntryScreen> {
  final _code = TextEditingController();

  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _enter(String code) async {
    final trimmed = code.trim();

    if (trimmed.isEmpty) {
      setState(() => _error = '접속 코드를 입력해 주세요.');

      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await ref.read(judgeSessionProvider.notifier).signIn(trimmed);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _scan() async {
    final code = await Navigator.of(
      context,
    ).push<String>(MaterialPageRoute(builder: (_) => const ScanScreen()));

    if (code == null || !mounted) return;

    _code.text = code;
    await _enter(code);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const BrandMark(size: 80),
                  const SizedBox(height: 20),
                  const Text(
                    '온라인 심사 시스템',
                    style: TextStyle(
                      fontSize: 23,
                      fontWeight: FontWeight.w800,
                      color: AppColor.ink,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '전달받은 접속 코드를 넣거나 심사위원 카드의 QR 을 찍어 주세요.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13.5,
                      color: AppColor.muted,
                      height: 1.55,
                    ),
                  ),
                  const SizedBox(height: 26),
                  TextField(
                    controller: _code,
                    autofocus: true,
                    enabled: !_busy,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(8),
                    ],
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 27,
                      letterSpacing: 8,
                      fontWeight: FontWeight.w700,
                      color: AppColor.ink,
                    ),
                    decoration: InputDecoration(
                      hintText: '483920',
                      hintStyle: const TextStyle(
                        fontSize: 27,
                        letterSpacing: 8,
                        fontWeight: FontWeight.w700,
                        color: AppColor.faint,
                      ),
                      fillColor: AppColor.surface,
                      contentPadding: const EdgeInsets.symmetric(vertical: 18),
                      errorText: _error,
                      // 오류 글씨가 칸 아래에서 화면을 밀지 않도록 자리를 잡아 둔다.
                      errorMaxLines: 2,
                    ),
                    onSubmitted: _busy ? null : _enter,
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: FilledButton(
                      onPressed: _busy ? null : () => _enter(_code.text),
                      child: _busy
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              '심사 시작하기',
                              style: TextStyle(
                                fontSize: 16.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: OutlinedButton.icon(
                      onPressed: _busy ? null : _scan,
                      icon: const Icon(Icons.qr_code_scanner, size: 20),
                      label: const Text(
                        'QR 코드 스캔',
                        style: TextStyle(fontSize: 15.5),
                      ),
                    ),
                  ),
                  if (widget.onAdmin != null) ...[
                    const SizedBox(height: 18),
                    TextButton.icon(
                      onPressed: widget.onAdmin,
                      style: TextButton.styleFrom(
                        foregroundColor: AppColor.muted,
                      ),
                      icon: const Icon(Icons.admin_panel_settings_outlined,
                          size: 18),
                      label: const Text('행사 관리자로 접속'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
