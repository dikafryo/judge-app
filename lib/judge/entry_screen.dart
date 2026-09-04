import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api.dart';
import '../core/brand.dart';
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
    final code = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const ScanScreen()),
    );

    if (code == null || !mounted) return;

    _code.text = code;
    await _enter(code);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
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
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '전달받은 접속 코드를 넣거나 심사위원 카드의 QR 을 찍어 주세요.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xFF64748B), height: 1.5),
                  ),
                  const SizedBox(height: 28),
                  TextField(
                    controller: _code,
                    autofocus: true,
                    enabled: !_busy,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(8)],
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 26, letterSpacing: 8, fontWeight: FontWeight.w600),
                    decoration: InputDecoration(
                      hintText: '483920',
                      hintStyle: const TextStyle(letterSpacing: 8, color: Color(0xFFCBD5E1)),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(vertical: 18),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      errorText: _error,
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
                              width: 20, height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('심사 시작하기', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: OutlinedButton.icon(
                      onPressed: _busy ? null : _scan,
                      icon: const Icon(Icons.qr_code_scanner),
                      label: const Text('QR 코드 스캔', style: TextStyle(fontSize: 16)),
                    ),
                  ),
                  if (widget.onAdmin != null) ...[
                    const SizedBox(height: 24),
                    TextButton(onPressed: widget.onAdmin, child: const Text('행사 관리자로 접속')),
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
