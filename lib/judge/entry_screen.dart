import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api.dart';
import '../core/brand.dart';
import '../core/design.dart';
import '../store/judge_session.dart';
import 'scan_screen.dart';

/// 입장 화면. 접속 코드를 직접 넣거나 심사위원 카드의 QR 을 찍는다.
///
/// 위쪽은 그라데이션 판에 마크와 제목, 아래는 흰 카드에 코드 칸 — 행사 당일 처음
/// 켠 심사위원이 "여기에 숫자를 넣으면 된다" 를 설명 없이 알아보게 하는 것이 요점이다.
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
    final topInset = MediaQuery.paddingOf(context).top;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: kDarkSystemBars,
      child: Scaffold(
        body: SingleChildScrollView(
          child: Column(
            children: [
              // 머리 판은 상태바 뒤까지 칠한다. 그래서 SafeArea 대신 인셋만큼 안쪽 여백을 준다.
              HeroPanel(
                radius: const BorderRadius.vertical(
                  bottom: Radius.circular(32),
                ),
                padding: EdgeInsets.fromLTRB(28, topInset + 36, 28, 40),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(26),
                      ),
                      child: const BrandMark(size: 76),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      '온라인 심사 시스템',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '종이 심사표 없이, 끊겨도 멈추지 않는 채점',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13.5,
                        color: Colors.white.withValues(alpha: 0.82),
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              SafeArea(
                top: false,
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 22, 20, 24),
                      child: Column(
                        children: [
                          CardBox(
                            padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Row(
                                  children: [
                                    IconBadge(
                                      icon: Icons.pin_outlined,
                                      size: 36,
                                    ),
                                    SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        '접속 코드로 입장',
                                        style: TextStyle(
                                          fontSize: 16.5,
                                          fontWeight: FontWeight.w800,
                                          color: AppColor.ink,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                const Text(
                                  '전달받은 6자리 코드를 넣거나 심사위원 카드의 QR 을 찍어 주세요.',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: AppColor.muted,
                                    height: 1.5,
                                  ),
                                ),
                                const SizedBox(height: 18),
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
                                    fontSize: 28,
                                    letterSpacing: 8,
                                    fontWeight: FontWeight.w800,
                                    color: AppColor.ink,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: '483920',
                                    hintStyle: const TextStyle(
                                      fontSize: 28,
                                      letterSpacing: 8,
                                      fontWeight: FontWeight.w800,
                                      color: AppColor.faint,
                                    ),
                                    fillColor: AppColor.accentSoft,
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(
                                        AppRadius.field,
                                      ),
                                      borderSide: const BorderSide(
                                        color: Colors.transparent,
                                      ),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      vertical: 18,
                                    ),
                                    errorText: _error,
                                    // 오류 글씨가 칸 아래에서 화면을 밀지 않도록 자리를 잡아 둔다.
                                    errorMaxLines: 2,
                                  ),
                                  onSubmitted: _busy ? null : _enter,
                                ),
                                const SizedBox(height: 14),
                                SizedBox(
                                  width: double.infinity,
                                  height: 56,
                                  child: FilledButton(
                                    onPressed: _busy
                                        ? null
                                        : () => _enter(_code.text),
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
                                  height: 54,
                                  child: OutlinedButton.icon(
                                    onPressed: _busy ? null : _scan,
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: AppColor.accent,
                                      side: const BorderSide(
                                        color: AppColor.accentSoft,
                                        width: 2,
                                      ),
                                    ),
                                    icon: const Icon(
                                      Icons.qr_code_scanner,
                                      size: 20,
                                    ),
                                    label: const Text(
                                      'QR 코드 스캔',
                                      style: TextStyle(fontSize: 15.5),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                          const Row(
                            children: [
                              Expanded(
                                child: _Feature(
                                  icon: Icons.cloud_off_outlined,
                                  tone: AppTone.amber,
                                  text: '끊겨도\n채점 계속',
                                ),
                              ),
                              SizedBox(width: 10),
                              Expanded(
                                child: _Feature(
                                  icon: Icons.sync_outlined,
                                  tone: AppTone.teal,
                                  text: '연결되면\n자동 전송',
                                ),
                              ),
                              SizedBox(width: 10),
                              Expanded(
                                child: _Feature(
                                  icon: Icons.draw_outlined,
                                  tone: AppTone.violet,
                                  text: '전자서명\n집계표 반영',
                                ),
                              ),
                            ],
                          ),
                          if (widget.onAdmin != null) ...[
                            const SizedBox(height: 18),
                            TextButton.icon(
                              onPressed: widget.onAdmin,
                              style: TextButton.styleFrom(
                                foregroundColor: AppColor.muted,
                              ),
                              icon: const Icon(
                                Icons.admin_panel_settings_outlined,
                                size: 18,
                              ),
                              label: const Text('행사 관리자로 접속'),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 앱이 해 주는 일 세 가지. 처음 켠 사람에게 "이 앱은 이런 것" 을 한눈에 보인다.
class _Feature extends StatelessWidget {
  const _Feature({required this.icon, required this.tone, required this.text});

  final IconData icon;
  final AppTone tone;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 10, 12),
      decoration: BoxDecoration(
        color: tone.soft,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: tone.strong),
          const SizedBox(height: 8),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              height: 1.35,
              fontWeight: FontWeight.w700,
              color: tone.ink,
            ),
          ),
        ],
      ),
    );
  }
}
