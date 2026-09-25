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

/// 서버는 서명 dataURL 을 20만 자(`max:200000`)까지 받는다. 여유를 두고 19만 자.
const kSignatureMaxChars = 190000;

/// 크게 구울수록 인쇄가 선명하지만 길어진다. 앞에서부터 시도해 한도 안에 드는 첫 배율을 쓴다.
const kSignatureScales = [2.0, 1.5, 1.0];

/// [render] 로 배율마다 구워 보고, 한도 안에 드는 첫 결과를 돌려준다.
/// 가장 작은 배율로도 넘치면 그 결과를 그대로 돌려준다(서버가 거절하면 알림으로 드러난다).
Future<String> encodeWithinLimit(
  Future<String> Function(double scale) render, {
  List<double> scales = kSignatureScales,
  int maxChars = kSignatureMaxChars,
}) async {
  var result = '';

  for (final scale in scales) {
    result = await render(scale);

    if (result.length <= maxChars) return result;
  }

  return result;
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

  /// 기본은 실제 크기의 2배로 구워 인쇄물에서 계단현상이 보이지 않게 한다.
  /// 서버 한도를 넘으면 [encodeWithinLimit] 가 배율을 낮춰 다시 굽는다.
  Future<String> _toDataUrl() => encodeWithinLimit(_render);

  /// 저장용 PNG 에는 획만 굽는다 — 화면의 안내 문구·기준선은 들어가면 안 된다.
  Future<String> _render(double scale) async {
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
    image.dispose();

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
                        child: Stack(
                          children: [
                            // 기준선·안내는 화면에만 있는 겹. PNG 는 paintStrokes 만 굽는다.
                            Positioned(
                              left: 24,
                              right: 24,
                              top: constraints.maxHeight * 0.8,
                              child: Container(height: 1, color: AppColor.line),
                            ),
                            if (_isEmpty) const _EmptyHint(),
                            Positioned.fill(
                              child: CustomPaint(
                                painter: _SignaturePainter(_strokes),
                              ),
                            ),
                          ],
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

/// 빈 서명 칸 안내. 어디에 그어야 하는지 모르는 칸은 비어 보이기만 한다.
class _EmptyHint extends StatelessWidget {
  const _EmptyHint();

  @override
  Widget build(BuildContext context) {
    return const Positioned.fill(
      child: IgnorePointer(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.draw_outlined, size: 28, color: AppColor.muted),
            SizedBox(height: 8),
            Text(
              '여기에 서명하세요',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColor.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
