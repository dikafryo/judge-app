import 'package:flutter/material.dart';

/// 앱 아이콘과 같은 마크. 런처 아이콘 · 네이티브 스플래시 · 이 위젯이 모두 같은 그림이어야
/// 앱을 켜는 동안 아이콘이 끊겨 보이지 않는다. 비율은 아이콘 생성기(make-icons.php)와 같다.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, required this.size});

  final double size;

  static const background = Color(0xFF1F2933);
  static const cellLight = Color(0xFFF5F3EF);
  static const cellAccent = Color(0xFF4F46E5);

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
        color: background,
        borderRadius: BorderRadius.circular(size * (0.18 / 1.72)),
      ),
      child: Column(
        children: [
          Row(children: [square(cellLight), SizedBox(width: gap), square(cellLight)]),
          SizedBox(height: gap),
          Row(children: [square(cellLight), SizedBox(width: gap), square(cellAccent)]),
        ],
      ),
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
