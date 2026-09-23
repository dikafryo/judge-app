import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api.dart';
import '../core/design.dart';
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
      builder: (context) => AppDialog(
        icon: closing ? Icons.lock_outline : Icons.lock_open_outlined,
        tone: closing ? DialogTone.danger : DialogTone.neutral,
        title: closing ? '심사를 마감할까요?' : '심사를 재개할까요?',
        subtitle: closing
            ? '접속 코드가 모두 회수되고, 들어와 있던 심사위원도 즉시 로그아웃됩니다.'
            : '접속 코드가 새로 발급됩니다. 심사위원에게 다시 전달해야 합니다.',
        confirmLabel: closing ? '마감하기' : '재개하기',
        onConfirm: () => Navigator.pop(context, true),
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
      builder: (context) => AppDialog(
        icon: Icons.emoji_events_outlined,
        title: '선정자 수',
        subtitle: '집계 화면에 상위 몇 곳이 선정으로 표시됩니다.',
        confirmLabel: '저장',
        onConfirm: () => Navigator.pop(context, controller.text),
        child: AppField(
          label: '선정할 인원(기관) 수',
          controller: controller,
          autofocus: true,
          suffix: '곳',
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          helper: '비우면 선정 표시를 하지 않습니다.',
          onSubmitted: (text) => Navigator.pop(context, text),
        ),
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
      builder: (context) => AppDialog(
        icon: Icons.speed_outlined,
        title: '심사 기본점수',
        subtitle: '심사위원 화면에 점수를 미리 채워 두고, 위아래로 조정해 제출합니다.',
        confirmLabel: '저장',
        onConfirm: () => Navigator.pop(context, controller.text),
        child: AppField(
          label: '평가 항목 만점 대비',
          controller: controller,
          autofocus: true,
          suffix: '%',
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          helper: '예를 들어 90이면 20점짜리 항목에 18점이 채워집니다. 비우면 채우지 않습니다.',
          onSubmitted: (text) => Navigator.pop(context, text),
        ),
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
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            SectionCard(
              title: '집계 방식',
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: RadioGroup<String>(
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
            ),
            const SizedBox(height: 20),
            SectionCard(
              title: '심사위원 화면',
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                children: [
                  SwitchListTile(
                    value: event.isBlind,
                    secondary: const IconBadge(
                      icon: Icons.visibility_off_outlined,
                      tone: AppTone.rose,
                      size: 38,
                    ),
                    title: const Text('블라인드 심사'),
                    subtitle: const Text(
                      '켜면 심사위원에게 이름·소속을 아예 보내지 않고 심사번호만 보여 줍니다.',
                    ),
                    onChanged: _busy
                        ? null
                        : (value) => _apply(
                            (admin) => admin.updateScoringMethod(
                              method: admin.event.scoringMethod,
                              isBlind: value,
                              passCount: admin.event.passCount,
                              defaultScorePercent:
                                  admin.event.defaultScorePercent,
                            ),
                          ),
                  ),
                  const Divider(indent: 16, endIndent: 16),
                  _SettingRow(
                    icon: Icons.speed_outlined,
                    tone: AppTone.sky,
                    title: '심사 기본점수',
                    value: event.defaultScorePercent == null
                        ? '채우지 않음'
                        : '각 항목 만점의 ${event.defaultScorePercent}%',
                    highlight: event.defaultScorePercent != null,
                    onTap: _busy ? null : () => _askDefaultScore(admin),
                  ),
                  const Divider(indent: 16, endIndent: 16),
                  _SettingRow(
                    icon: Icons.emoji_events_outlined,
                    tone: AppTone.amber,
                    title: '선정자 수',
                    value: event.passCount == null
                        ? '지정하지 않음'
                        : '상위 ${event.passCount}곳',
                    highlight: event.passCount != null,
                    onTap: _busy ? null : () => _askPassCount(admin),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SectionCard(
              title: '최종집계표',
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: _SettingRow(
                icon: Icons.draw_outlined,
                tone: AppTone.violet,
                title: event.showJudgeSigns ? '심사위원 서명란 포함' : '심사위원 서명란 생략',
                value: event.reportSigners.isEmpty
                    ? '결재란 없음'
                    : event.reportSigners
                          .map((signer) => '${signer.role} ${signer.name}')
                          .join(' · '),
                highlight: event.reportSigners.isNotEmpty,
                onTap: _busy ? null : () => _editReportSettings(admin),
              ),
            ),
            const SizedBox(height: 20),
            SectionCard(
              title: '심사 진행',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  NoticeBox(
                    tone: event.isOpen ? NoticeTone.good : NoticeTone.warn,
                    text: event.isOpen ? '심사가 진행 중입니다.' : '심사가 마감되었습니다.',
                    detail: event.isOpen
                        ? '심사위원이 접속 코드로 들어와 채점할 수 있습니다.'
                        : '접속 코드가 회수되어 아무도 들어올 수 없습니다.',
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: event.isOpen
                        ? OutlinedButton.icon(
                            onPressed: _busy ? null : () => _toggleOpen(admin),
                            icon: const Icon(Icons.lock_outline, size: 19),
                            label: const Text('심사 마감하기'),
                          )
                        : FilledButton.icon(
                            onPressed: _busy ? null : () => _toggleOpen(admin),
                            icon: const Icon(
                              Icons.lock_open_outlined,
                              size: 19,
                            ),
                            label: const Text('심사 재개하기'),
                          ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            // 위험 구역은 시각적으로 떨어뜨려 둔다 — 스크롤하다 눈에 걸려 누르면 안 된다
            SectionCard(
              title: '위험 구역',
              color: AppColor.dangerSoft.withValues(alpha: 0.45),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '평가 대상·항목·심사위원·모든 점수가 함께 삭제되며 되돌릴 수 없습니다.',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColor.muted,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColor.dangerInk,
                        side: const BorderSide(color: AppColor.dangerSoft),
                        backgroundColor: AppColor.dangerSoft,
                      ),
                      onPressed: _busy ? null : () => _deleteEvent(admin),
                      icon: const Icon(Icons.delete_forever_outlined, size: 19),
                      label: const Text('행사 영구 삭제'),
                    ),
                  ),
                ],
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

/// 눌러서 값을 고치는 설정 한 줄. 지금 값이 무엇인지가 제목만큼 중요해서
/// 값을 오른쪽 작은 글씨가 아니라 제목 아래 굵게 둔다.
class _SettingRow extends StatelessWidget {
  const _SettingRow({
    required this.icon,
    required this.title,
    required this.value,
    required this.onTap,
    this.highlight = false,
    this.tone = AppTone.indigo,
  });

  final IconData icon;
  final String title;
  final String value;
  final VoidCallback? onTap;
  final bool highlight;
  final AppTone tone;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: IconBadge(icon: icon, tone: tone, size: 38),
      title: Text(title),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: highlight ? FontWeight.w700 : FontWeight.w400,
            color: highlight ? AppColor.accent : AppColor.muted,
          ),
        ),
      ),
      trailing: const Icon(Icons.chevron_right, color: AppColor.faint),
      onTap: onTap,
    );
  }
}
