import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api.dart';
import '../store/admin_api.dart';
import 'admin_settings_dialogs.dart';

/// 기본설정 — 집계 방식 · 최종집계표 · 마감/재개 · 행사 삭제.
class AdminSettingsTab extends ConsumerStatefulWidget {
  const AdminSettingsTab({super.key});

  @override
  ConsumerState<AdminSettingsTab> createState() => _AdminSettingsTabState();
}

class _AdminSettingsTabState extends ConsumerState<AdminSettingsTab> {
  bool _busy = false;

  Future<void> _apply(Future<void> Function(AdminApi admin) action) async {
    final admin = ref.read(adminApiProvider);

    if (admin == null || _busy) return;

    setState(() => _busy = true);

    try {
      await action(admin);

      // 행사 정보를 다시 읽어야 화면 제목의 마감 표시가 어긋나지 않는다.
      ref.read(adminApiProvider.notifier).state = await admin.refreshed();
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

  Future<void> _toggleOpen(AdminApi admin) async {
    final closing = admin.event.isOpen;

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(closing ? '심사를 마감할까요?' : '심사를 재개할까요?'),
        content: Text(
          closing
              ? '심사위원 접속 코드가 모두 회수되어 더 이상 접속할 수 없습니다.\n'
                    '앱에 로그인해 있던 심사위원도 즉시 로그아웃됩니다.'
              : '접속 코드가 새로 발급됩니다. 심사위원에게 코드를 다시 전달해야 합니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(closing ? '마감' : '재개'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    await _apply((admin) async {
      final message = await admin.toggleOpen();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            duration: const Duration(seconds: 6),
          ),
        );
      }
    });
  }

  Future<void> _askPassCount(AdminApi admin) async {
    final controller = TextEditingController(
      text: admin.event.passCount?.toString() ?? '',
    );

    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('선정자 수'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(
            labelText: '선정할 인원(기관) 수',
            helperText: '비우면 지정하지 않습니다. 집계 화면에 상위 몇 곳이 선정으로 표시됩니다.',
            helperMaxLines: 2,
          ),
          onSubmitted: (text) => Navigator.pop(context, text),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('저장'),
          ),
        ],
      ),
    );

    if (value == null) return;

    await _apply(
      (admin) => admin.updateScoringMethod(
        method: admin.event.scoringMethod,
        isBlind: admin.event.isBlind,
        passCount: int.tryParse(value.trim()),
        defaultScorePercent: admin.event.defaultScorePercent,
      ),
    );
  }

  Future<void> _askDefaultScore(AdminApi admin) async {
    final controller = TextEditingController(
      text: admin.event.defaultScorePercent?.toString() ?? '',
    );

    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('심사 기본점수'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(
            labelText: '평가 항목 만점 대비 %',
            helperText:
                '심사위원이 화면을 열면 각 평가 항목 만점의 이 비율만큼 점수가 미리 입력되어 있고, '
                '위아래로 조정해 심사를 보다 쉽게 할 수 있게 합니다. '
                '예를 들어 90이면 20점짜리 항목에 18점이 채워집니다. 비우면 채우지 않습니다.',
            helperMaxLines: 5,
            suffixText: '%',
          ),
          onSubmitted: (text) => Navigator.pop(context, text),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('저장'),
          ),
        ],
      ),
    );

    if (value == null) return;

    // 100 을 넘겨 보내면 서버가 거절한다. 여기서 범위 안으로 맞춘다.
    final parsed = int.tryParse(value.trim());

    await _apply(
      (admin) => admin.updateScoringMethod(
        method: admin.event.scoringMethod,
        isBlind: admin.event.isBlind,
        passCount: admin.event.passCount,
        defaultScorePercent: parsed?.clamp(0, 100),
      ),
    );
  }

  Future<void> _editReportSettings(AdminApi admin) async {
    final result = await showReportSettingsDialog(context, admin.event);
    if (result == null) return;

    await _apply(
      (admin) => admin.updateReportSigners(
        showJudgeSigns: result.$1,
        signers: result.$2,
      ),
    );
  }

  Future<void> _deleteEvent(AdminApi admin) async {
    final confirmedName = await showEventDeletionDialog(context, admin.event);
    if (confirmedName == null) return;

    setState(() => _busy = true);
    try {
      final message = await admin.deleteEvent(confirmedName);
      if (!mounted) return;

      final messenger = ScaffoldMessenger.of(context);
      ref.read(adminApiProvider.notifier).state = null;
      Navigator.of(context).pop();
      messenger.showSnackBar(SnackBar(content: Text(message)));
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
    final admin = ref.watch(adminApiProvider);

    if (admin == null) return const SizedBox.shrink();

    final event = admin.event;

    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            const SettingsSectionTitle('집계 방식'),
            RadioGroup<String>(
              groupValue: event.scoringMethod,
              onChanged: (value) {
                if (!_busy && value != null) _setMethod(value);
              },
              child: const Column(
                children: [
                  RadioListTile<String>(
                    value: 'all',
                    title: Text('전체 합계·평균'),
                    subtitle: Text('모든 심사위원의 점수를 그대로 반영합니다.'),
                  ),
                  RadioListTile<String>(
                    value: 'trimmed',
                    title: Text('최고·최저 심사위원 제외'),
                    subtitle: Text('평가대상별로 총점이 가장 높은·낮은 심사위원을 빼고 집계합니다.'),
                  ),
                ],
              ),
            ),
            const Divider(height: 32),
            const SettingsSectionTitle('심사위원 화면'),
            SwitchListTile(
              value: event.isBlind,
              title: const Text('블라인드 심사'),
              subtitle: const Text('켜면 심사위원에게 이름·소속을 아예 보내지 않고 심사번호만 보여 줍니다.'),
              onChanged: _busy
                  ? null
                  : (value) => _apply(
                      (admin) => admin.updateScoringMethod(
                        method: admin.event.scoringMethod,
                        isBlind: value,
                        passCount: admin.event.passCount,
                        defaultScorePercent: admin.event.defaultScorePercent,
                      ),
                    ),
            ),
            ListTile(
              title: const Text('심사 기본점수'),
              subtitle: Text(
                event.defaultScorePercent == null
                    ? '채우지 않음'
                    : '각 항목 만점의 ${event.defaultScorePercent}%를 미리 입력',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: _busy ? null : () => _askDefaultScore(admin),
            ),
            ListTile(
              title: const Text('선정자 수'),
              subtitle: Text(
                event.passCount == null ? '지정하지 않음' : '상위 ${event.passCount}곳',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: _busy ? null : () => _askPassCount(admin),
            ),
            const Divider(height: 32),
            const SettingsSectionTitle('최종집계표'),
            ListTile(
              leading: const Icon(Icons.draw_outlined),
              title: Text(event.showJudgeSigns ? '심사위원 서명란 포함' : '심사위원 서명란 생략'),
              subtitle: Text(
                event.reportSigners.isEmpty
                    ? '결재란 없음'
                    : '결재란: ${event.reportSigners.map((signer) => '${signer.role} ${signer.name}').join(', ')}',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: _busy ? null : () => _editReportSettings(admin),
            ),
            const Divider(height: 32),
            const SettingsSectionTitle('심사 진행'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: event.isOpen
                    ? OutlinedButton.icon(
                        onPressed: _busy ? null : () => _toggleOpen(admin),
                        icon: const Icon(Icons.lock_outline),
                        label: const Text('심사 마감하기'),
                      )
                    : FilledButton.icon(
                        onPressed: _busy ? null : () => _toggleOpen(admin),
                        icon: const Icon(Icons.lock_open_outlined),
                        label: const Text('심사 재개하기'),
                      ),
              ),
            ),
            const SizedBox(height: 24),
            const Divider(height: 32),
            const SettingsSectionTitle('위험 구역'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                onPressed: _busy ? null : () => _deleteEvent(admin),
                icon: const Icon(Icons.delete_forever_outlined),
                label: const Text('행사 영구 삭제'),
              ),
            ),
          ],
        ),
        if (_busy) const LinearProgressIndicator(minHeight: 2),
      ],
    );
  }

  Future<void> _setMethod(String method) => _apply(
    (admin) => admin.updateScoringMethod(
      method: method,
      isBlind: admin.event.isBlind,
      passCount: admin.event.passCount,
      defaultScorePercent: admin.event.defaultScorePercent,
    ),
  );
}
