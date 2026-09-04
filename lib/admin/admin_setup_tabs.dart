import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/admin.dart';
import 'setup_scope.dart';

/// 평가 항목. 2단계 구조이고 1레벨 배점 합계는 100점을 넘을 수 없다 —
/// 그 규칙은 서버(EventSetup)가 강제하고, 여기서는 남은 점수를 미리 보여만 준다.
class AdminCriteriaTab extends StatelessWidget {
  const AdminCriteriaTab({super.key});

  @override
  Widget build(BuildContext context) {
    return SetupScope(
      builder: (context, data, mutate) {
        final top = data.topLevel;
        final remaining = 100 - data.totalMax;

        return Scaffold(
          backgroundColor: Colors.transparent,
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _add(context, data, mutate, null),
            icon: const Icon(Icons.add),
            label: const Text('1레벨 항목'),
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            children: [
              _Summary(
                text: '1레벨 배점 합계 ${data.totalMax} / 100점',
                detail: remaining > 0 ? '$remaining점 더 배정할 수 있습니다.' : '배점이 모두 배정되었습니다.',
                warn: remaining > 0,
              ),
              const SizedBox(height: 12),
              if (top.isEmpty)
                const _Empty(text: '평가 항목이 없습니다. 1레벨 항목부터 만들어 주세요.'),
              for (final parent in top)
                _CriterionCard(
                  parent: parent,
                  children: data.childrenOf(parent.id),
                  onAddChild: () => _add(context, data, mutate, parent),
                  onDelete: (criterion) async {
                    if (await confirmDelete(context, criterion.name)) {
                      await mutate((admin) => admin.removeCriterion(criterion.id));
                    }
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _add(
    BuildContext context,
    SetupData data,
    Future<void> Function(SetupMutation) mutate,
    SetupCriterion? parent,
  ) async {
    final used = parent == null
        ? data.totalMax
        : data.childrenOf(parent.id).fold(0, (sum, c) => sum + c.maxScore);
    final limit = (parent?.maxScore ?? 100) - used;

    if (parent != null && parent.hasScores) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('이미 점수가 입력된 항목에는 2레벨을 추가할 수 없습니다.')),
      );

      return;
    }

    final result = await _askCriterion(context, parent: parent, limit: limit);

    if (result == null) return;

    await mutate((admin) => admin.addCriterion(
          name: result.$1,
          maxScore: result.$2,
          parentId: parent?.id,
        ));
  }

  Future<(String, int)?> _askCriterion(
    BuildContext context, {
    SetupCriterion? parent,
    required int limit,
  }) {
    final name = TextEditingController();
    final score = TextEditingController();

    return showDialog<(String, int)>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(parent == null ? '1레벨 항목 추가' : "'${parent.name}' 안에 항목 추가"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              autofocus: true,
              decoration: const InputDecoration(labelText: '항목명'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: score,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: '배점',
                helperText: limit > 0 ? '남은 배점 $limit점' : '남은 배점이 없습니다',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
          TextButton(
            onPressed: () {
              final value = int.tryParse(score.text) ?? 0;

              if (name.text.trim().isEmpty || value < 1) return;

              Navigator.pop(context, (name.text.trim(), value));
            },
            child: const Text('추가'),
          ),
        ],
      ),
    );
  }
}

class _CriterionCard extends StatelessWidget {
  const _CriterionCard({
    required this.parent,
    required this.children,
    required this.onAddChild,
    required this.onDelete,
  });

  final SetupCriterion parent;
  final List<SetupCriterion> children;
  final VoidCallback onAddChild;
  final Future<void> Function(SetupCriterion) onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${parent.name}  ${parent.maxScore}점',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ),
              IconButton(
                tooltip: '2레벨 추가',
                icon: const Icon(Icons.add, size: 20),
                onPressed: onAddChild,
              ),
              IconButton(
                tooltip: '삭제',
                icon: const Icon(Icons.delete_outline, size: 20, color: Color(0xFF94A3B8)),
                onPressed: () => onDelete(parent),
              ),
            ],
          ),
          if (parent.hasScores)
            const Padding(
              padding: EdgeInsets.only(right: 8, bottom: 4),
              child: Text(
                '이미 점수가 입력된 항목입니다 — 2레벨을 추가할 수 없습니다.',
                style: TextStyle(fontSize: 12, color: Color(0xFFB45309)),
              ),
            ),
          for (final child in children)
            Padding(
              padding: const EdgeInsets.only(left: 12, right: 8),
              child: Row(
                children: [
                  const Text('└ ', style: TextStyle(color: Color(0xFFCBD5E1))),
                  Expanded(child: Text('${child.name}  ${child.maxScore}점')),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 18, color: Color(0xFFCBD5E1)),
                    onPressed: () => onDelete(child),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// 평가 대상. 등록 형식은 웹과 같다 — 한 줄에 하나, "이름, 소속".
class AdminCandidatesTab extends StatelessWidget {
  const AdminCandidatesTab({super.key});

  @override
  Widget build(BuildContext context) {
    return SetupScope(
      builder: (context, data, mutate) => Scaffold(
        backgroundColor: Colors.transparent,
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () async {
            final bulk = await askBulk(
              context,
              title: '평가 대상 일괄 등록',
              hint: '가나다, 가람학교\n라마바, 나람학교',
              helper: '한 줄에 한 명. 이름 뒤에 쉼표를 찍고 소속을 적습니다. 소속은 없어도 됩니다.',
            );

            if (bulk == null || bulk.trim().isEmpty) return;

            await mutate((admin) => admin.addCandidates(bulk));
          },
          icon: const Icon(Icons.add),
          label: const Text('일괄 등록'),
        ),
        body: data.candidates.isEmpty
            ? const _Empty(text: '평가 대상이 없습니다.')
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                itemCount: data.candidates.length,
                separatorBuilder: (_, _) => const SizedBox(height: 6),
                itemBuilder: (context, index) {
                  final candidate = data.candidates[index];

                  return _Row(
                    leading: '${index + 1}',
                    title: candidate.name,
                    subtitle: candidate.affiliation,
                    onDelete: () async {
                      if (await confirmDelete(context, candidate.name)) {
                        await mutate((admin) => admin.removeCandidate(candidate.id));
                      }
                    },
                  );
                },
              ),
      ),
    );
  }
}

/// 심사위원. 접속 코드를 화면에서 바로 보여줘, 인쇄하지 않고도 그 자리에서 전달할 수 있다.
class AdminJudgesTab extends StatelessWidget {
  const AdminJudgesTab({super.key});

  @override
  Widget build(BuildContext context) {
    return SetupScope(
      builder: (context, data, mutate) => Scaffold(
        backgroundColor: Colors.transparent,
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () async {
            final bulk = await askBulk(
              context,
              title: '심사위원 일괄 등록',
              hint: '김심사\n이심사',
              helper: '한 줄에 한 명. 등록하면 접속 코드가 자동으로 발급됩니다.',
            );

            if (bulk == null || bulk.trim().isEmpty) return;

            await mutate((admin) => admin.addJudges(bulk));
          },
          icon: const Icon(Icons.add),
          label: const Text('일괄 등록'),
        ),
        body: data.judges.isEmpty
            ? const _Empty(text: '심사위원이 없습니다.')
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                itemCount: data.judges.length,
                separatorBuilder: (_, _) => const SizedBox(height: 6),
                itemBuilder: (context, index) {
                  final judge = data.judges[index];

                  return _Row(
                    leading: judge.code ?? '–',
                    leadingWide: true,
                    title: judge.name,
                    subtitle: judge.code == null
                        ? '마감되어 코드가 회수되었습니다'
                        : judge.signedAt != null
                            ? '서명 완료'
                            : null,
                    onCopy: judge.code == null
                        ? null
                        : () {
                            Clipboard.setData(ClipboardData(text: judge.code!));
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('${judge.name} 접속 코드를 복사했습니다.')),
                            );
                          },
                    onDelete: () async {
                      if (await confirmDelete(context, judge.name)) {
                        await mutate((admin) => admin.removeJudge(judge.id));
                      }
                    },
                  );
                },
              ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.leading,
    required this.title,
    required this.onDelete,
    this.subtitle,
    this.onCopy,
    this.leadingWide = false,
  });

  final String leading;
  final String title;
  final String? subtitle;
  final VoidCallback onDelete;
  final VoidCallback? onCopy;
  final bool leadingWide;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          SizedBox(
            width: leadingWide ? 72 : 30,
            child: Text(
              leading,
              style: TextStyle(
                fontSize: leadingWide ? 15 : 13,
                fontWeight: FontWeight.bold,
                letterSpacing: leadingWide ? 1 : 0,
                color: const Color(0xFF64748B),
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 15)),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                  ),
              ],
            ),
          ),
          if (onCopy != null)
            IconButton(
              tooltip: '코드 복사',
              icon: const Icon(Icons.copy, size: 18, color: Color(0xFF94A3B8)),
              onPressed: onCopy,
            ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 20, color: Color(0xFFCBD5E1)),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.text, required this.detail, required this.warn});

  final String text;
  final String detail;
  final bool warn;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: warn ? const Color(0xFFFEF3C7) : const Color(0xFFDCFCE7),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(text, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF334155))),
          const SizedBox(height: 2),
          Text(detail, style: const TextStyle(fontSize: 12.5, color: Color(0xFF475569))),
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Center(
        child: Text(text, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF94A3B8))),
      ),
    );
  }
}
