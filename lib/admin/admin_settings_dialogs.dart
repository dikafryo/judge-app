import 'package:flutter/material.dart';

import '../core/design.dart';
import '../models/admin.dart';

Future<(bool, List<ReportSigner>)?> showReportSettingsDialog(
  BuildContext context,
  AdminEvent event,
) => showDialog<(bool, List<ReportSigner>)>(
  context: context,
  builder: (context) => _ReportSettingsDialog(event: event),
);

class _ReportSettingsDialog extends StatefulWidget {
  const _ReportSettingsDialog({required this.event});

  final AdminEvent event;

  @override
  State<_ReportSettingsDialog> createState() => _ReportSettingsDialogState();
}

class _ReportSettingsDialogState extends State<_ReportSettingsDialog> {
  late final Map<
    String,
    ({
      TextEditingController dept,
      TextEditingController position,
      TextEditingController name,
    })
  >
  _controllers;
  late bool _showJudgeSigns;
  String? _error;

  @override
  void initState() {
    super.initState();
    final current = {
      for (final signer in widget.event.reportSigners) signer.role: signer,
    };
    _controllers = {
      for (final role in ['기록자', '검토자', '확인자'])
        role: (
          dept: TextEditingController(text: current[role]?.dept ?? ''),
          position: TextEditingController(text: current[role]?.position ?? ''),
          name: TextEditingController(text: current[role]?.name ?? ''),
        ),
    };
    _showJudgeSigns = widget.event.showJudgeSigns;
  }

  @override
  void dispose() {
    for (final row in _controllers.values) {
      row.dept.dispose();
      row.position.dispose();
      row.name.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppDialog(
      icon: Icons.assignment_outlined,
      title: '최종집계표 설정',
      subtitle: '이름을 입력한 사람만 출력물 맨 아래 결재란에 표시됩니다.',
      confirmLabel: '저장',
      onConfirm: _save,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Material(
            color: AppColor.field,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.field),
              side: const BorderSide(color: AppColor.line),
            ),
            clipBehavior: Clip.antiAlias,
            child: SwitchListTile(
              contentPadding: const EdgeInsets.fromLTRB(14, 2, 6, 2),
              value: _showJudgeSigns,
              title: const Text('심사위원 서명란 포함'),
              subtitle: const Text('끄면 아래 기록자 이름이 필수입니다.'),
              onChanged: (value) => setState(() {
                _showJudgeSigns = value;
                _error = null;
              }),
            ),
          ),
          const SizedBox(height: 20),
          for (final role in _controllers.keys) _signerFields(role),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: NoticeBox(tone: NoticeTone.warn, text: _error!),
            ),
        ],
      ),
    );
  }

  Widget _signerFields(String role) {
    final row = _controllers[role]!;

    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColor.accentSoft,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Text(
                  role,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AppColor.accent,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  role == '기록자' && !_showJudgeSigns ? '필수' : '비워 두면 표시하지 않습니다',
                  style: const TextStyle(fontSize: 11.5, color: AppColor.faint),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: AppField(label: '부서', controller: row.dept),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: AppField(label: '직급', controller: row.position),
              ),
            ],
          ),
          const SizedBox(height: 10),
          AppField(label: '이름', controller: row.name),
        ],
      ),
    );
  }

  void _save() {
    if (!_showJudgeSigns && _controllers['기록자']!.name.text.trim().isEmpty) {
      setState(() => _error = '서명란을 생략하려면 기록자 이름을 입력하세요.');
      return;
    }

    final signers = _controllers.entries
        .where((entry) => entry.value.name.text.trim().isNotEmpty)
        .map(
          (entry) => ReportSigner(
            role: entry.key,
            dept: entry.value.dept.text.trim(),
            position: entry.value.position.text.trim(),
            name: entry.value.name.text.trim(),
          ),
        )
        .toList();
    Navigator.pop(context, (_showJudgeSigns, signers));
  }
}

Future<String?> showEventDeletionDialog(
  BuildContext context,
  AdminEvent event,
) => showDialog<String>(
  context: context,
  builder: (context) => _EventDeletionDialog(event: event),
);

class _EventDeletionDialog extends StatefulWidget {
  const _EventDeletionDialog({required this.event});

  final AdminEvent event;

  @override
  State<_EventDeletionDialog> createState() => _EventDeletionDialogState();
}

class _EventDeletionDialogState extends State<_EventDeletionDialog> {
  final _controller = TextEditingController();
  bool _matches = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppDialog(
      icon: Icons.delete_forever_outlined,
      tone: DialogTone.danger,
      title: '행사 영구 삭제',
      subtitle: '평가 대상·항목·심사위원·모든 점수가 함께 삭제되며 되돌릴 수 없습니다.',
      confirmLabel: '영구 삭제',
      onConfirm: _matches
          ? () => Navigator.pop(context, _controller.text.trim())
          : null,
      child: AppField(
        label: '확인을 위해 행사명을 그대로 입력하세요',
        controller: _controller,
        autofocus: true,
        hint: widget.event.name,
        onChanged: (value) =>
            setState(() => _matches = value.trim() == widget.event.name),
      ),
    );
  }
}
