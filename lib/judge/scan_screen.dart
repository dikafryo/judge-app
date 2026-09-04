import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

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
  bool _handled = false;

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
      appBar: AppBar(title: const Text('QR 코드 스캔')),
      body: Stack(
        children: [
          MobileScanner(onDetect: _onDetect),
          const Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Text(
                '심사위원 카드의 QR 코드를 화면 안에 맞춰 주세요.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontSize: 15),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
