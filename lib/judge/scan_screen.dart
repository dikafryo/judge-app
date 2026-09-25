import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../core/design.dart';

/// QR 스캔 화면. 찍은 코드를 문자열로 돌려주고 닫힌다.
class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  /// 인쇄된 심사위원 카드의 QR 은 접속 **주소**(.../judge/483920)를 담고 있다.
  /// 카드를 다시 찍어 만들 수 없으므로, 앱이 주소에서 코드를 뽑아내야 한다.
  /// 숫자만 든 QR 도 함께 받아 준다.
  static String? extractCode(String? raw) {
    if (raw == null) return null;

    final value = raw.trim();

    if (RegExp(r'^\d{4,8}$').hasMatch(value)) return value;

    final match = RegExp(r'/judge/(\d{4,8})').firstMatch(value);

    return match?.group(1);
  }

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  /// 스캔 창 한 변. 카드 QR 을 팔 길이에서 비추면 이 정도가 맞는다.
  static const _window = 260.0;

  final _controller = MobileScannerController();
  bool _handled = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;

    for (final barcode in capture.barcodes) {
      final code = ScanScreen.extractCode(barcode.rawValue);

      if (code == null) continue;

      _handled = true;
      Navigator.of(context).pop(code);

      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('QR 코드 스캔'),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: kDarkSystemBars,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final window = Rect.fromCenter(
            center: constraints.biggest.center(Offset.zero),
            width: _window,
            height: _window,
          );

          return Stack(
            children: [
              MobileScanner(
                controller: _controller,
                scanWindow: window,
                onDetect: _onDetect,
              ),
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(painter: _ScanOverlayPainter(window)),
                ),
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                    child: _BottomControls(controller: _controller),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _BottomControls extends StatelessWidget {
  const _BottomControls({required this.controller});

  final MobileScannerController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          child: const Text(
            '심사위원 카드의 QR 코드를 네모 안에 맞춰 주세요.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 18),
        // 행사장 조명이 어두우면 카드 QR 이 안 읽힌다 — 손전등을 바로 켤 수 있게
        ValueListenableBuilder<MobileScannerState>(
          valueListenable: controller,
          builder: (context, state, _) {
            final on = state.torchState == TorchState.on;

            return SizedBox(
              width: 56,
              height: 56,
              child: IconButton.filledTonal(
                tooltip: on ? '손전등 끄기' : '손전등 켜기',
                onPressed: state.torchState == TorchState.unavailable
                    ? null
                    : controller.toggleTorch,
                icon: Icon(
                  on
                      ? Icons.flashlight_on_rounded
                      : Icons.flashlight_off_rounded,
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 6),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          style: TextButton.styleFrom(foregroundColor: Colors.white),
          child: const Text(
            '코드 직접 입력',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}

/// 스캔 창 밖을 어둡게 덮고, 창 모서리에 흰 꺾쇠를 그린다.
class _ScanOverlayPainter extends CustomPainter {
  _ScanOverlayPainter(this.window);

  final Rect window;

  static const _radius = 24.0;
  static const _corner = 34.0;

  @override
  void paint(Canvas canvas, Size size) {
    final hole = RRect.fromRectAndRadius(
      window,
      const Radius.circular(_radius),
    );

    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(Offset.zero & size),
        Path()..addRRect(hole),
      ),
      Paint()..color = Colors.black.withValues(alpha: 0.55),
    );

    final stroke = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    const r = _radius;
    const c = _corner;
    final l = window.left;
    final t = window.top;
    final rt = window.right;
    final b = window.bottom;

    canvas
      ..drawPath(
        Path()
          ..moveTo(l, t + c)
          ..lineTo(l, t + r)
          ..arcToPoint(Offset(l + r, t), radius: const Radius.circular(r))
          ..lineTo(l + c, t),
        stroke,
      )
      ..drawPath(
        Path()
          ..moveTo(rt - c, t)
          ..lineTo(rt - r, t)
          ..arcToPoint(Offset(rt, t + r), radius: const Radius.circular(r))
          ..lineTo(rt, t + c),
        stroke,
      )
      ..drawPath(
        Path()
          ..moveTo(rt, b - c)
          ..lineTo(rt, b - r)
          ..arcToPoint(Offset(rt - r, b), radius: const Radius.circular(r))
          ..lineTo(rt - c, b),
        stroke,
      )
      ..drawPath(
        Path()
          ..moveTo(l + c, b)
          ..lineTo(l + r, b)
          ..arcToPoint(Offset(l, b - r), radius: const Radius.circular(r))
          ..lineTo(l, b - c),
        stroke,
      );
  }

  @override
  bool shouldRepaint(_ScanOverlayPainter old) => old.window != window;
}
