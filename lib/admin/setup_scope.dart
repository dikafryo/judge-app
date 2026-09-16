import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api.dart';
import '../core/brand.dart';
import '../core/design.dart';
import '../models/admin.dart';
import '../store/admin_api.dart';

/// 설정 탭들이 공유하는 로딩·변경 껍데기.
///
/// 세 탭(항목·대상·심사위원)이 같은 /admin/setup 응답을 쓰고, 변경 API 도 모두
/// 갱신된 SetupData 를 돌려준다. 그래서 각 탭이 따로 불러오지 않고 여기서 한 번만 맡는다.
typedef SetupMutation = Future<SetupData> Function(AdminApi admin);

class SetupScope extends ConsumerStatefulWidget {
  const SetupScope({super.key, required this.builder});

  final Widget Function(
    BuildContext context,
    SetupData data,
    Future<void> Function(SetupMutation) mutate,
  )
  builder;

  @override
  ConsumerState<SetupScope> createState() => _SetupScopeState();
}

class _SetupScopeState extends ConsumerState<SetupScope> {
  SetupData? _data;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final admin = ref.read(adminApiProvider);

    if (admin == null) return;

    try {
      final data = await admin.setup();

      if (mounted) {
        setState(() {
          _data = data;
          _error = null;
        });
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  /// 변경 API 는 갱신된 SetupData 를 돌려주므로 다시 읽을 필요가 없다.
  /// 마감·체험행사 차단(423)이나 배점 규칙 위반(422)은 그대로 사용자에게 보여준다.
  Future<void> _mutate(SetupMutation mutation) async {
    final admin = ref.read(adminApiProvider);

    if (admin == null || _busy) return;

    setState(() => _busy = true);

    try {
      final data = await mutation(admin);

      if (mounted) setState(() => _data = data);
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;

    if (data == null) {
      return _error == null
          ? const Center(child: CircularProgressIndicator())
          : ErrorView(message: _error!, onRetry: () => unawaited(_load()));
    }

    return Stack(
      children: [
        widget.builder(context, data, _mutate),
        if (_busy) const LinearProgressIndicator(minHeight: 2),
      ],
    );
  }
}

/// 웹과 같은 "한 줄에 하나" 일괄 등록 입력창.
///
/// 여러 줄을 받는 칸이라 [AppField] 가 아니라 직접 조립한다 — 예시를 회색으로
/// 깔아 두어야 어떤 형식으로 적어야 하는지 설명 없이도 보인다.
Future<String?> askBulk(
  BuildContext context, {
  required String title,
  required String hint,
  required String helper,
  IconData icon = Icons.playlist_add_rounded,
}) {
  final controller = TextEditingController();

  return showDialog<String>(
    context: context,
    builder: (context) => AppDialog(
      icon: icon,
      title: title,
      subtitle: helper,
      confirmLabel: '등록',
      onConfirm: () => Navigator.pop(context, controller.text),
      child: TextField(
        controller: controller,
        autofocus: true,
        maxLines: 7,
        minLines: 4,
        style: const TextStyle(fontSize: 15, height: 1.6, color: AppColor.ink),
        decoration: InputDecoration(
          hintText: hint,
          hintMaxLines: 4,
          hintStyle: const TextStyle(
            fontSize: 15,
            height: 1.6,
            color: AppColor.faint,
          ),
        ),
      ),
    ),
  );
}

/// 지우기 전 확인. 점수까지 함께 사라지는 삭제라 되돌릴 수 없다.
Future<bool> confirmDelete(BuildContext context, String what) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AppDialog(
      icon: Icons.delete_outline_rounded,
      tone: DialogTone.danger,
      title: '$what 을(를) 삭제할까요?',
      subtitle: '이미 입력된 점수도 함께 사라지며 되돌릴 수 없습니다.',
      confirmLabel: '삭제',
      onConfirm: () => Navigator.pop(context, true),
    ),
  );

  return ok ?? false;
}
