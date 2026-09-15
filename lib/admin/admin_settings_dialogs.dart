import 'package:flutter/material.dart';

import '../models/admin.dart';

class SettingsSectionTitle extends StatelessWidget {
  const SettingsSectionTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: Color(0xFF64748B),
        ),
      ),
    );
  }
}

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
    return AlertDialog(
      title: const Text('최종집계표 설정'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _showJudgeSigns,
                title: const Text('심사위원 서명란 포함'),
                subtitle: const Text('끄면 아래 결재란의 기록자 이름이 필수입니다.'),
                onChanged: (value) => setState(() {
                  _showJudgeSigns = value;
                  _error = null;
                }),
              ),
              const Divider(),
              for (final role in _controllers.keys) _signerFields(role),
              if (_error != null)
                Text(
                  _error!,
                  style: const TextStyle(color: Colors.red, fontSize: 13),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('취소'),
        ),
        FilledButton(onPressed: _save, child: const Text('저장')),
      ],
    );
  }

  Widget _signerFields(String role) {
    final row = _controllers[role]!;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(role, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: row.dept,
                  decoration: const InputDecoration(labelText: '부서'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: row.position,
                  decoration: const InputDecoration(labelText: '직급'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: row.name,
            decoration: InputDecoration(labelText: '$role 이름'),
          ),
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
    return AlertDialog(
      title: const Text('행사 영구 삭제'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('평가 대상·항목·심사위원·모든 점수가 함께 삭제되며 되돌릴 수 없습니다.'),
          const SizedBox(height: 16),
          Text('확인하려면 “${widget.event.name}”을(를) 입력하세요.'),
          const SizedBox(height: 8),
          TextField(
            controller: _controller,
            autofocus: true,
            decoration: const InputDecoration(labelText: '행사명'),
            onChanged: (value) =>
                setState(() => _matches = value.trim() == widget.event.name),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('취소'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Colors.red),
          onPressed: _matches
              ? () => Navigator.pop(context, _controller.text.trim())
              : null,
          child: const Text('영구 삭제'),
        ),
      ],
    );
  }
}
