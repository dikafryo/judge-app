import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api.dart';
import '../store/admin_api.dart';

/// 기본설정 — 집계 방식 · 블라인드 · 선정자 수 · 마감/재개.
///
/// 최종집계표 결재란(기록자·검토자·확인자)은 여기에 없다. 인쇄 직전에 웹에서 하는 작업이고,
/// 앱에서 급하게 고칠 일이 아니라 일부러 뺐다.
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
          SnackBar(content: Text(e.message), duration: const Duration(seconds: 5)),
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
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
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
          SnackBar(content: Text(message), duration: const Duration(seconds: 6)),
        );
      }
    });
  }

  Future<void> _askPassCount(AdminApi admin) async {
    final controller = TextEditingController(text: admin.event.passCount?.toString() ?? '');

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
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('저장'),
          ),
        ],
      ),
    );

    if (value == null) return;

    await _apply((admin) => admin.updateScoringMethod(
          method: admin.event.scoringMethod,
          isBlind: admin.event.isBlind,
          passCount: int.tryParse(value.trim()),
        ));
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
            const _SectionTitle('집계 방식'),
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
            const _SectionTitle('심사위원 화면'),
            SwitchListTile(
              value: event.isBlind,
              title: const Text('블라인드 심사'),
              subtitle: const Text('켜면 심사위원에게 이름·소속을 아예 보내지 않고 심사번호만 보여 줍니다.'),
              onChanged: _busy
                  ? null
                  : (value) => _apply((admin) => admin.updateScoringMethod(
                        method: admin.event.scoringMethod,
                        isBlind: value,
                        passCount: admin.event.passCount,
                      )),
            ),
            ListTile(
              title: const Text('선정자 수'),
              subtitle: Text(event.passCount == null ? '지정하지 않음' : '상위 ${event.passCount}곳'),
              trailing: const Icon(Icons.chevron_right),
              onTap: _busy ? null : () => _askPassCount(admin),
            ),
            const Divider(height: 32),
            const _SectionTitle('심사 진행'),
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
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                '행사 삭제와 최종집계표 결재란 입력은 웹(judge.sw4u.kr)에서 합니다.',
                style: TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
              ),
            ),
          ],
        ),
        if (_busy) const LinearProgressIndicator(minHeight: 2),
      ],
    );
  }

  Future<void> _setMethod(String method) => _apply((admin) => admin.updateScoringMethod(
        method: method,
        isBlind: admin.event.isBlind,
        passCount: admin.event.passCount,
      ));
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Text(
        text,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
      ),
    );
  }
}
