import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/design.dart';
import '../store/judge_session.dart';

/// 전자서명. 웹과 같은 형식(PNG dataURL)으로 보내야 최종집계표에 그대로 실린다.
///
/// 패키지를 쓰지 않고 직접 그린다 — 필요한 것이 "선을 모아 PNG 로 굽는다" 뿐이라
/// 의존성을 늘릴 이유가 없다.

/// 화면 미리보기와 저장용 PNG 가 **같은 함수**로 그려져야 서명이 보이는 대로 저장된다.
void paintStrokes(Canvas canvas, List<List<Offset>> strokes) {
  final paint = Paint()
    ..color = AppColor.ink
    ..strokeWidth = 2.6
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..style = PaintingStyle.stroke;

  for (final stroke in strokes) {
    if (stroke.length < 2) continue;

    final path = Path()..moveTo(stroke.first.dx, stroke.first.dy);

    for (final point in stroke.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }

    canvas.drawPath(path, paint);
  }
}

class SignatureScreen extends ConsumerStatefulWidget {
  const SignatureScreen({super.key});

  @override
  ConsumerState<SignatureScreen> createState() => _SignatureScreenState();
}

class _SignatureScreenState extends ConsumerState<SignatureScreen> {
  /// 획 목록. 획 하나가 점의 나열이고, 획이 나뉘어야 손을 뗀 자리가 이어지지 않는다.
  final List<List<Offset>> _strokes = [];

  Size _canvas = Size.zero;
  bool _saving = false;

  bool get _isEmpty => _strokes.every((stroke) => stroke.length < 2);

  Future<String> _toDataUrl() async {
    // 실제 크기의 2배로 구워 인쇄물에서 계단현상이 보이지 않게 한다.
    const scale = 2.0;
    final width = (_canvas.width * scale).round();
    final height = (_canvas.height * scale).round();

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    canvas.scale(scale);
    // 배경은 흰색으로 채운다. 투명하게 두면 인쇄 시 배경에 묻혀 안 보이는 경우가 있다.
    canvas.drawRect(Offset.zero & _canvas, Paint()..color = Colors.white);
    paintStrokes(canvas, _strokes);

    final image = await recorder.endRecording().toImage(width, height);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);

    return 'data:image/png;base64,${base64Encode(bytes!.buffer.asUint8List())}';
  }

  Future<void> _save() async {
    setState(() => _saving = true);

    final dataUrl = await _toDataUrl();

    await ref.read(judgeSessionProvider.notifier).saveSignature(dataUrl);

    if (!mounted) return;

    Navigator.of(context).pop();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('서명이 저장되었습니다.')));
  }

  @override
  Widget build(BuildContext context) {
    final payload = ref.watch(judgeSessionProvider).payload;

    final signed = payload?.hasSignature == true;

    return Scaffold(
      appBar: AppBar(title: const Text('전자서명')),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          child: Column(
            children: [
              NoticeBox(
                tone: signed ? NoticeTone.good : NoticeTone.info,
                text: signed ? '이미 서명하셨습니다' : '아래 칸에 서명해 주세요',
                detail: signed
                    ? '새로 서명하면 이전 서명을 대체합니다.'
                    : '서명은 최종집계표에 그대로 실립니다. 손가락이나 펜으로 그으면 됩니다.',
              ),
              const SizedBox(height: 14),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    _canvas = Size(constraints.maxWidth, constraints.maxHeight);

                    return Container(
                      decoration: BoxDecoration(
                        color: AppColor.surface,
                        borderRadius: BorderRadius.circular(AppRadius.card),
                        boxShadow: AppShadow.card,
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: GestureDetector(
                        onPanStart: (details) => setState(
                          () => _strokes.add([details.localPosition]),
                        ),
                        onPanUpdate: (details) => setState(
                          () => _strokes.last.add(details.localPosition),
                        ),
                        child: CustomPaint(
                          painter: _SignaturePainter(_strokes),
                          size: Size.infinite,
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  SizedBox(
                    height: 54,
                    child: OutlinedButton.icon(
                      onPressed: _saving || _isEmpty
                          ? null
                          : () => setState(_strokes.clear),
                      icon: const Icon(Icons.backspace_outlined, size: 18),
                      label: const Text('지우기'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: SizedBox(
                      height: 54,
                      child: FilledButton.icon(
                        onPressed: _saving || _isEmpty ? null : _save,
                        icon: const Icon(Icons.check, size: 20),
                        label: const Text(
                          '서명 저장',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SignaturePainter extends CustomPainter {
  const _SignaturePainter(this.strokes);

  final List<List<Offset>> strokes;

  @override
  void paint(Canvas canvas, Size size) => paintStrokes(canvas, strokes);

  @override
  bool shouldRepaint(covariant _SignaturePainter oldDelegate) => true;
}
