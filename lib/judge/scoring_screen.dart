import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/design.dart';
import '../models/payload.dart';
import '../store/judge_session.dart';
import 'sync_strip.dart';

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

    // 채점한 적 없는 항목만 기본점수로 채운다 — 이미 낸 점수를 덮으면 안 된다
    _draft = {
      for (final item in payload.leafItems)
        item.id: saved[item.id] ?? payload.defaultScoreFor(item),
    };
    _dirty = false;
  }

  double get _total =>
      _draft.values.fold(0, (sum, value) => sum + (value ?? 0));

  int get _filled => _draft.values.where((value) => value != null).length;

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
    _hold = Timer.periodic(
      const Duration(milliseconds: 90),
      (_) => _bump(item, delta),
    );
  }

  void _holdStop() {
    _hold?.cancel();
    _hold = null;
  }

  Future<void> _promptValue(CriterionItem item) async {
    final current = _draft[item.id];
    final controller = TextEditingController(
      text: current == null ? '' : formatScore(current),
    );

    final value = await showDialog<String>(
      context: context,
      builder: (context) => AppDialog(
        icon: Icons.edit_outlined,
        title: item.name,
        subtitle: '0.5점 단위. 비우면 미입력입니다.',
        confirmLabel: '확인',
        onConfirm: () => Navigator.pop(context, controller.text),
        child: AppField(
          label: '점수',
          controller: controller,
          autofocus: true,
          suffix: '/ ${item.maxScore}점',
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onSubmitted: (text) => Navigator.pop(context, text),
        ),
      ),
    );

    if (value == null) return;

    final trimmed = value.trim();

    _set(
      item,
      trimmed.isEmpty ? null : double.tryParse(trimmed) ?? _draft[item.id],
    );
  }

  Future<void> _save(JudgePayload payload) async {
    await ref
        .read(judgeSessionProvider.notifier)
        .saveScores(payload.candidates[_index].id, _draft);

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

    final leaves = payload.leafItems.length;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 8,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(candidate.label, overflow: TextOverflow.ellipsis),
            Text(
              '${_index + 1} / ${payload.candidates.length}'
              '${candidate.affiliation?.isNotEmpty == true ? ' · ${candidate.affiliation}' : ''}',
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: AppColor.muted,
              ),
            ),
          ],
        ),
        actions: [
          // 합계는 채점 내내 눈이 가는 숫자다. 알약 안에 넣어 제목과 섞이지 않게 한다.
          Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColor.accentSoft,
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  formatScore(_total),
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppColor.accent,
                  ),
                ),
                Text(
                  ' / ${payload.totalMax}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColor.accent,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          if (locked)
            const StatusStrip(
              icon: Icons.lock_outline,
              text: '심사가 마감되어 점수를 수정할 수 없습니다.',
              foreground: AppColor.warn,
              background: AppColor.warnSoft,
            ),
          // 채점 중에도 연결 상태가 보여야 한다. 목록으로 돌아가야만 알 수 있으면
          // 그 사이 넣은 점수가 어디에 있는지 심사위원이 알 길이 없다.
          SyncStrip(session: ref.watch(judgeSessionProvider)),
          Expanded(
            child: ListView(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
              children: [
                SectionCard(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                  child: ProgressRow(
                    label: '입력한 항목',
                    value: _filled,
                    total: leaves,
                  ),
                ),
                for (final group in payload.groups) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 6, 4, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            group.name,
                            style: SectionCard.sectionTitleStyle,
                          ),
                        ),
                        Text(
                          '${group.maxScore}점',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColor.muted,
                          ),
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
            lastLabel: last ? '저장하고 마치기' : '저장하고 다음',
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
    final empty = value == null;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
      decoration: BoxDecoration(
        color: AppColor.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        // 아직 비어 있는 항목만 테두리를 남긴다. 다 채우고 나면 테두리가 사라지면서
        // "남은 것이 없다"는 것이 한눈에 보인다.
        border: Border.all(color: empty ? AppColor.line : AppColor.surface),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (showName)
                  Text(
                    item.name,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColor.ink,
                    ),
                  ),
                Text(
                  '배점 ${item.maxScore}점',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColor.muted,
                  ),
                ),
                if (item.description?.isNotEmpty == true)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      item.description!,
                      style: const TextStyle(
                        fontSize: 12,
                        height: 1.45,
                        color: AppColor.muted,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _StepButton(
            icon: Icons.remove,
            enabled: enabled,
            onPress: onDecrease,
            onRelease: onRelease,
          ),
          // 숫자를 누르면 직접 입력. 그냥 글씨로 두면 누를 수 있는 줄 모른다 —
          // 눌리는 자리를 잉크 효과가 있는 단추로 만든다.
          Semantics(
            label: '${item.name} 점수 직접 입력',
            button: true,
            child: InkWell(
              onTap: enabled ? onTapValue : null,
              borderRadius: BorderRadius.circular(AppRadius.button),
              child: SizedBox(
                width: 64,
                height: 48,
                child: Center(
                  child: Text(
                    empty ? '–' : formatScore(value!),
                    style: TextStyle(
                      fontSize: 23,
                      fontWeight: FontWeight.w800,
                      color: empty ? AppColor.faint : AppColor.ink,
                    ),
                  ),
                ),
              ),
            ),
          ),
          _StepButton(
            icon: Icons.add,
            enabled: enabled,
            onPress: onIncrease,
            onRelease: onRelease,
          ),
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
          color: enabled ? AppColor.canvas : AppColor.field,
          borderRadius: BorderRadius.circular(AppRadius.button),
          border: Border.all(color: AppColor.line, width: 1.5),
        ),
        child: Icon(icon, color: enabled ? AppColor.ink : AppColor.faint),
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
      padding: EdgeInsets.fromLTRB(
        16,
        10,
        16,
        10 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: const BoxDecoration(
        color: AppColor.surface,
        border: Border(top: BorderSide(color: AppColor.line)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 68,
            height: 54,
            child: OutlinedButton(
              onPressed: canPrev ? onPrev : null,
              style: OutlinedButton.styleFrom(
                padding: EdgeInsets.zero,
                foregroundColor: AppColor.muted,
              ),
              child: const Icon(Icons.arrow_back, size: 20),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: SizedBox(
              height: 54,
              child: FilledButton.icon(
                onPressed: enabled ? onNext : null,
                // 고친 것이 있을 때만 "저장하고" 를 붙인다. 아무것도 안 고쳤는데
                // 저장한다고 하면, 눌러도 되는지 한 번 더 생각하게 만든다.
                icon: Icon(
                  dirty ? Icons.save_outlined : Icons.arrow_forward,
                  size: 19,
                ),
                label: Text(
                  dirty ? lastLabel : lastLabel.replaceFirst('저장하고 ', ''),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
