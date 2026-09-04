import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/payload.dart';
import '../store/judge_session.dart';

/// 채점 화면.
///
/// 웹에서 가장 불편했던 것이 "점수 칸에 닿기까지 한참 스크롤" 이었다. 여기서는 대상 하나가
/// 화면 하나를 온전히 쓰고, 다음 대상으로는 아래 [저장하고 다음] 버튼으로 넘어간다.
/// 목록으로 돌아갔다 다시 들어오는 왕복이 사라지는 것이 요점이다.
class ScoringScreen extends ConsumerStatefulWidget {
  const ScoringScreen({super.key, required this.candidateId});

  final int candidateId;

  @override
  ConsumerState<ScoringScreen> createState() => _ScoringScreenState();
}

class _ScoringScreenState extends ConsumerState<ScoringScreen> {
  final _scroll = ScrollController();

  late int _index;

  /// 화면에서 편집 중인 값. 저장하기 전까지는 세션 상태를 건드리지 않는다.
  Map<int, double?> _draft = {};

  Timer? _hold;
  bool _dirty = false;

  @override
  void initState() {
    super.initState();

    final payload = ref.read(judgeSessionProvider).payload!;

    _index = payload.candidates.indexWhere((c) => c.id == widget.candidateId);
    if (_index < 0) _index = 0;

    _loadDraft(payload);
  }

  @override
  void dispose() {
    _hold?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  void _loadDraft(JudgePayload payload) {
    final saved = payload.scoresOf(payload.candidates[_index].id);

    _draft = {for (final item in payload.leafItems) item.id: saved[item.id]};
    _dirty = false;
  }

  double get _total => _draft.values.fold(0, (sum, value) => sum + (value ?? 0));

  void _set(CriterionItem item, double? value) {
    setState(() {
      _draft[item.id] = value?.clamp(0, item.maxScore.toDouble());
      _dirty = true;
    });
  }

  void _bump(CriterionItem item, double delta) {
    final current = _draft[item.id] ?? 0;
    final next = (current + delta).clamp(0, item.maxScore.toDouble());

    if (next == current && _draft[item.id] != null) return;

    HapticFeedback.selectionClick();
    _set(item, next.toDouble());
  }

  /// 길게 누르면 가속. 배점이 100점인 항목을 한 칸씩 누르게 두면 못 쓴다.
  void _holdStart(CriterionItem item, double delta) {
    _bump(item, delta);
    _hold?.cancel();
    _hold = Timer.periodic(const Duration(milliseconds: 90), (_) => _bump(item, delta));
  }

  void _holdStop() {
    _hold?.cancel();
    _hold = null;
  }

  Future<void> _promptValue(CriterionItem item) async {
    final current = _draft[item.id];
    final controller = TextEditingController(text: current == null ? '' : formatScore(current));

    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(item.name),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: '점수 (0 ~ ${item.maxScore})',
            helperText: '0.5점 단위로 넣을 수 있습니다. 비우면 미입력이 됩니다.',
          ),
          onSubmitted: (text) => Navigator.pop(context, text),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('확인'),
          ),
        ],
      ),
    );

    if (value == null) return;

    final trimmed = value.trim();

    _set(item, trimmed.isEmpty ? null : double.tryParse(trimmed) ?? _draft[item.id]);
  }

  Future<void> _save(JudgePayload payload) async {
    await ref.read(judgeSessionProvider.notifier).saveScores(payload.candidates[_index].id, _draft);

    if (mounted) setState(() => _dirty = false);
  }

  Future<void> _saveAndNext(JudgePayload payload) async {
    await _save(payload);

    if (!mounted) return;

    if (_index >= payload.candidates.length - 1) {
      Navigator.of(context).pop();

      return;
    }

    setState(() {
      _index += 1;
      _loadDraft(ref.read(judgeSessionProvider).payload!);
    });

    _scroll.jumpTo(0);
  }

  void _goPrev(JudgePayload payload) {
    if (_index == 0) return;

    setState(() {
      _index -= 1;
      _loadDraft(payload);
    });

    _scroll.jumpTo(0);
  }

  @override
  Widget build(BuildContext context) {
    final payload = ref.watch(judgeSessionProvider).payload;

    if (payload == null || payload.candidates.isEmpty) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final candidate = payload.candidates[_index];
    final locked = !payload.event.isOpen;
    final last = _index >= payload.candidates.length - 1;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(candidate.label, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            Text(
              '${_index + 1} / ${payload.candidates.length}'
              '${candidate.affiliation?.isNotEmpty == true ? ' · ${candidate.affiliation}' : ''}',
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                '${formatScore(_total)} / ${payload.totalMax}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF4F46E5)),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          if (locked)
            Container(
              width: double.infinity,
              color: const Color(0xFFFEF3C7),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: const Text(
                '심사가 마감되어 점수를 수정할 수 없습니다.',
                style: TextStyle(fontSize: 13, color: Color(0xFF92400E)),
              ),
            ),
          Expanded(
            child: ListView(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                for (final group in payload.groups) ...[
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8, top: 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            group.name,
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                          ),
                        ),
                        Text(
                          '${group.maxScore}점',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                        ),
                      ],
                    ),
                  ),
                  for (final item in group.items)
                    _ScoreRow(
                      item: item,
                      value: _draft[item.id],
                      enabled: !locked,
                      showName: group.hasChildren,
                      onDecrease: () => _holdStart(item, -1),
                      onIncrease: () => _holdStart(item, 1),
                      onRelease: _holdStop,
                      onTapValue: () => _promptValue(item),
                    ),
                  const SizedBox(height: 12),
                ],
              ],
            ),
          ),
          _BottomBar(
            canPrev: _index > 0,
            enabled: !locked,
            dirty: _dirty,
            lastLabel: last ? '저장하고 마치기' : '저장하고 다음 →',
            onPrev: () => _goPrev(payload),
            onNext: () => _saveAndNext(payload),
          ),
        ],
      ),
    );
  }
}

class _ScoreRow extends StatelessWidget {
  const _ScoreRow({
    required this.item,
    required this.value,
    required this.enabled,
    required this.showName,
    required this.onDecrease,
    required this.onIncrease,
    required this.onRelease,
    required this.onTapValue,
  });

  final CriterionItem item;
  final double? value;
  final bool enabled;
  final bool showName;
  final VoidCallback onDecrease;
  final VoidCallback onIncrease;
  final VoidCallback onRelease;
  final VoidCallback onTapValue;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (showName)
                  Text(item.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                Text(
                  '배점 ${item.maxScore}점',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                ),
                if (item.description?.isNotEmpty == true)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      item.description!,
                      style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _StepButton(icon: Icons.remove, enabled: enabled, onPress: onDecrease, onRelease: onRelease),
          GestureDetector(
            onTap: enabled ? onTapValue : null,
            child: Container(
              width: 62,
              height: 48,
              alignment: Alignment.center,
              child: Text(
                value == null ? '–' : formatScore(value!),
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: value == null ? const Color(0xFFCBD5E1) : const Color(0xFF0F172A),
                ),
              ),
            ),
          ),
          _StepButton(icon: Icons.add, enabled: enabled, onPress: onIncrease, onRelease: onRelease),
        ],
      ),
    );
  }
}

/// 손가락으로 정확히 누를 수 있어야 해서 48×48 을 유지한다(터치 목표 최소 크기).
class _StepButton extends StatelessWidget {
  const _StepButton({
    required this.icon,
    required this.enabled,
    required this.onPress,
    required this.onRelease,
  });

  final IconData icon;
  final bool enabled;
  final VoidCallback onPress;
  final VoidCallback onRelease;

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: enabled ? (_) => onPress() : null,
      onPointerUp: enabled ? (_) => onRelease() : null,
      onPointerCancel: enabled ? (_) => onRelease() : null,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: enabled ? const Color(0xFFF1F5F9) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
        ),
        child: Icon(icon, color: enabled ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.canPrev,
    required this.enabled,
    required this.dirty,
    required this.lastLabel,
    required this.onPrev,
    required this.onNext,
  });

  final bool canPrev;
  final bool enabled;
  final bool dirty;
  final String lastLabel;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(16, 10, 16, 10 + MediaQuery.of(context).padding.bottom),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        children: [
          SizedBox(
            height: 54,
            child: OutlinedButton(
              onPressed: canPrev ? onPrev : null,
              child: const Text('← 이전'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: SizedBox(
              height: 54,
              child: FilledButton(
                onPressed: enabled ? onNext : null,
                child: Text(
                  dirty ? lastLabel : lastLabel.replaceFirst('저장하고 ', ''),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
