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

/// 저장 이미지의 기준 크기(배율 1). 출력물 서명란(가로 4 : 세로 1 안팎)에 가깝게 3:1 로 둔다.
const kSignatureOutput = Size(720, 240);

/// 저장 이미지에서의 선 굵기(배율 1). 이미지 높이의 3.75% — 출력물 서명란(높이 48px)에서
/// 약 1.8px 로 찍혀 또렷하다. **기기·칸 크기와 무관하게 늘 이 값이다.**
const kSignatureStroke = 9.0;

/// 서명 둘레에 남길 여백(배율 1).
const kSignatureMargin = 14.0;

/// 화면 칸의 선 굵기. 칸이 크면 굵게, 작으면 가늘게 — 칸 폭에 비례시켜서 폰과 태블릿에서
/// 서명이 칸에 대해 같은 굵기로 보이게 한다.
double onScreenStroke(double padWidth) =>
    (padWidth * kSignatureStroke / kSignatureOutput.width).clamp(3.0, 10.0);

/// 화면 미리보기와 저장용 PNG 가 같은 함수로 그린다. 굵기만 다르게 준다.
void paintStrokes(
  Canvas canvas,
  List<List<Offset>> strokes, {
  double strokeWidth = 2.6,
}) {
  final paint = Paint()
    ..color = AppColor.ink
    ..strokeWidth = strokeWidth
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..style = PaintingStyle.stroke;
  final dot = Paint()..color = AppColor.ink;

  for (final stroke in strokes) {
    if (stroke.isEmpty) continue;

    // 톡 찍은 점(마침표·받침 점)도 서명의 일부다.
    if (stroke.length == 1) {
      canvas.drawCircle(stroke.first, strokeWidth / 2, dot);
      continue;
    }

    final path = Path()..moveTo(stroke.first.dx, stroke.first.dy);

    for (final point in stroke.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }

    canvas.drawPath(path, paint);
  }
}

/// 서명한 부분만 잘라 [box] 안에 **꽉 차게** 옮긴다(가로세로 비율 유지, 가운데 정렬).
///
/// 예전에는 칸 전체를 그대로 저장했다. 태블릿처럼 칸이 크면 이미지가 커지고, 출력물의
/// 같은 서명란에 줄여 넣는 만큼 선이 가늘어졌다. 칸 크기·서명 크기와 무관하게 서명이
/// 이미지를 채우고, 선은 [kSignatureStroke] 로 다시 그리므로 굵기가 늘 같다.
List<List<Offset>> fitStrokes(
  List<List<Offset>> strokes,
  Size box, {
  double margin = kSignatureMargin,
}) {
  final points = [for (final s in strokes) ...s];

  if (points.isEmpty) return const [];

  var left = points.first.dx, right = left;
  var top = points.first.dy, bottom = top;

  for (final p in points) {
    if (p.dx < left) left = p.dx;
    if (p.dx > right) right = p.dx;
    if (p.dy < top) top = p.dy;
    if (p.dy > bottom) bottom = p.dy;
  }

  // 점 하나·가로줄 하나처럼 한쪽 길이가 0 이면 나눌 수 없으므로 1 로 둔다.
  final width = (right - left).clamp(1.0, double.infinity);
  final height = (bottom - top).clamp(1.0, double.infinity);
  final availW = box.width - margin * 2;
  final availH = box.height - margin * 2;
  // 아주 작은 낙서가 수십 배로 부풀지 않게 상한을 둔다.
  final scale = [
    availW / width,
    availH / height,
    12.0,
  ].reduce((a, b) => a < b ? a : b);
  // 서명의 중심을 이미지 중심에 맞춘다.
  final dx = box.width / 2 - (left + right) / 2 * scale;
  final dy = box.height / 2 - (top + bottom) / 2 * scale;

  return [
    for (final stroke in strokes)
      [for (final p in stroke) Offset(p.dx * scale + dx, p.dy * scale + dy)],
  ];
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

  bool _saving = false;

  bool get _isEmpty => _strokes.every((stroke) => stroke.isEmpty);

  /// 기준 크기의 2배로 구워 인쇄물에서 계단현상이 보이지 않게 한다.
  /// 서버 한도를 넘으면 [encodeWithinLimit] 가 배율을 낮춰 다시 굽는다.
  Future<String> _toDataUrl() => encodeWithinLimit(_render);

  /// 저장용 PNG 에는 획만 굽는다 — 화면의 안내 문구·기준선은 들어가면 안 된다.
  /// 칸 크기와 무관하게 [kSignatureOutput] 크기에 서명을 꽉 채우고 같은 굵기로 그린다.
  Future<String> _render(double scale) async {
    final size = kSignatureOutput * scale;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // 배경은 흰색으로 채운다. 투명하게 두면 인쇄 시 배경에 묻혀 안 보이는 경우가 있다.
    canvas.drawRect(Offset.zero & size, Paint()..color = Colors.white);
    paintStrokes(
      canvas,
      fitStrokes(_strokes, size, margin: kSignatureMargin * scale),
      strokeWidth: kSignatureStroke * scale,
    );

    final image = await recorder.endRecording().toImage(
      size.width.round(),
      size.height.round(),
    );
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
                text: signed ? '이미 서명하셨습니다' : '칸을 가득 채워 크게 서명해 주세요',
                detail: signed
                    ? '새로 서명하면 이전 서명을 대체합니다. 칸을 가득 채워 크게 써 주세요.'
                    : '작게 쓰면 흐리게 보일 수 있어요. 서명은 최종집계표에 같은 굵기로 실립니다.',
              ),
              const SizedBox(height: 14),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    // 칸은 가로형 2:1 로 고정한다. 기기마다 칸 모양이 제각각이면 서명 모양도
                    // 제각각이 된다. 태블릿에서도 720 을 넘지 않게 해 손이 닿는 크기로 둔다.
                    var width = constraints.maxWidth.clamp(0.0, 720.0);
                    var height = width / 2;

                    if (height > constraints.maxHeight) {
                      height = constraints.maxHeight;
                      width = height * 2;
                    }

                    final stroke = onScreenStroke(width);

                    return Center(
                      child: SizedBox(
                        width: width,
                        height: height,
                        child: Container(
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
                                // 기준선·안내는 화면에만 있는 겹. PNG 는 획만 굽는다.
                                Positioned(
                                  left: 24,
                                  right: 24,
                                  top: height * 0.8,
                                  child: Container(
                                    height: 1,
                                    color: AppColor.line,
                                  ),
                                ),
                                if (_isEmpty) const _EmptyHint(),
                                Positioned.fill(
                                  child: CustomPaint(
                                    painter: _SignaturePainter(
                                      _strokes,
                                      stroke,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
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
  const _SignaturePainter(this.strokes, this.strokeWidth);

  final List<List<Offset>> strokes;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) =>
      paintStrokes(canvas, strokes, strokeWidth: strokeWidth);

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
              '칸을 가득 채워 크게 서명하세요',
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
