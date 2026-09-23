import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/design.dart';
import '../models/payload.dart';
import '../store/judge_session.dart';
import 'scoring_screen.dart';
import 'sync_strip.dart';
import 'signature_screen.dart';

enum CandidateFilter { all, todo, done }

/// 첫 화면이자 허브. 웹에서는 목록이 채점 화면 위에 쌓여 100명이면 한참 스크롤해야 했는데,
/// 네이티브에서는 목록과 채점이 아예 다른 화면이라 그 문제가 생기지 않는다.
class CandidatesScreen extends ConsumerStatefulWidget {
  const CandidatesScreen({super.key});

  @override
  ConsumerState<CandidatesScreen> createState() => _CandidatesScreenState();
}

class _CandidatesScreenState extends ConsumerState<CandidatesScreen> {
  final _search = TextEditingController();

  CandidateFilter _filter = CandidateFilter.all;

  /// "3분 전 전송됨" 을 스스로 늙게 만드는 시계. 이것이 없으면 화면을 건드리기
  /// 전까지 "방금 전"이 몇 시간이고 그대로 붙어 있어 오히려 사람을 속인다.
  Timer? _clock;

  @override
  void initState() {
    super.initState();

    _clock = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    _search.dispose();
    super.dispose();
  }

  List<CandidateInfo> _visible(JudgePayload payload) {
    final keyword = _search.text.trim().toLowerCase();

    return payload.candidates.where((c) {
      final matchesFilter = switch (_filter) {
        CandidateFilter.all => true,
        CandidateFilter.todo => !payload.isComplete(c.id),
        CandidateFilter.done => payload.isComplete(c.id),
      };

      if (!matchesFilter) return false;
      if (keyword.isEmpty) return true;

      return '${c.number} ${c.name ?? ''} ${c.affiliation ?? ''}'
          .toLowerCase()
          .contains(keyword);
    }).toList();
  }

  /// 아직 채점하지 않은 첫 대상. 100명짜리 목록에서 "내가 어디까지 했더라" 를
  /// 눈으로 찾게 두지 않으려는 것이다.
  CandidateInfo? _firstTodo(JudgePayload payload) {
    for (final c in payload.candidates) {
      if (!payload.isComplete(c.id)) return c;
    }

    return null;
  }

  void _open(int candidateId) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ScoringScreen(candidateId: candidateId)),
    );
  }

  Future<void> _confirmSignOut(JudgeState session) async {
    final pending = session.pendingCount;

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AppDialog(
        icon: Icons.logout,
        title: '심사를 끝내고 나갈까요?',
        subtitle: pending > 0
            ? '아직 서버로 보내지 못한 입력이 $pending건 있습니다. 지금 나가면 그 입력은 사라집니다.'
            : '다시 심사하려면 접속 코드를 새로 입력해야 합니다.',
        tone: pending > 0 ? DialogTone.danger : DialogTone.neutral,
        cancelLabel: '계속 심사',
        confirmLabel: '나가기',
        onConfirm: () => Navigator.pop(context, true),
      ),
    );

    if (ok == true) await ref.read(judgeSessionProvider.notifier).signOut();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(judgeSessionProvider);
    final payload = session.payload;

    if (payload == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final visible = _visible(payload);
    final total = payload.candidates.length;
    final done = payload.completedCount;
    final todo = _firstTodo(payload);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(payload.event.name, overflow: TextOverflow.ellipsis),
            Text(
              '${payload.judgeName} 심사위원',
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: AppColor.muted,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: payload.hasSignature ? '서명 다시 하기' : '서명하기',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SignatureScreen()),
            ),
            icon: Icon(
              payload.hasSignature ? Icons.draw : Icons.draw_outlined,
              color: payload.hasSignature ? AppColor.accent : AppColor.muted,
            ),
          ),
          IconButton(
            tooltip: '나가기',
            onPressed: () => _confirmSignOut(session),
            icon: const Icon(Icons.logout, color: AppColor.muted),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          if (!payload.event.isOpen)
            const StatusStrip(
              icon: Icons.lock_outline,
              text: '심사가 마감되었습니다. 점수를 더 저장할 수 없습니다.',
              foreground: AppColor.warn,
              background: AppColor.warnSoft,
            ),
          SyncStrip(session: session),
          Expanded(
            child: RefreshIndicator(
              color: AppColor.accent,
              onRefresh: () =>
                  ref.read(judgeSessionProvider.notifier).syncNow(),
              child: CustomScrollView(
                // 목록이 화면을 다 채우지 못해도 당겨서 새로고침할 수 있어야 한다.
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                      child: SectionCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ProgressRow(
                              label: '심사 진행',
                              value: done,
                              total: total,
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Icon(
                                  session.isSettled
                                      ? Icons.cloud_done_outlined
                                      : Icons.cloud_queue,
                                  size: 14,
                                  color: AppColor.faint,
                                ),
                                const SizedBox(width: 5),
                                Expanded(
                                  child: Text(
                                    formatSyncedAt(session.lastSyncedAt),
                                    style: const TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w600,
                                      color: AppColor.muted,
                                    ),
                                  ),
                                ),
                                Text(
                                  session.syncing ? '전송 중' : '당겨서 새로고침',
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    color: AppColor.faint,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (todo != null)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                        child: _ResumeCard(
                          candidate: todo,
                          remaining: total - done,
                          onTap: () => _open(todo.id),
                        ),
                      ),
                    ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                      child: SearchField(
                        controller: _search,
                        hint: '이름 · 번호 · 소속으로 찾기',
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          _chip('전체', total, CandidateFilter.all),
                          const SizedBox(width: 8),
                          _chip('미완료', total - done, CandidateFilter.todo),
                          const SizedBox(width: 8),
                          _chip('완료', done, CandidateFilter.done),
                        ],
                      ),
                    ),
                  ),
                  if (visible.isEmpty)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: EmptyState(
                        icon: Icons.search_off,
                        text: '해당하는 평가 대상이 없습니다',
                        detail: '찾는 말을 지우거나 다른 묶음을 골라 보세요.',
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                      sliver: SliverList.separated(
                        itemCount: visible.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, index) => _CandidateTile(
                          candidate: visible[index],
                          payload: payload,
                          pending: session.isPending(visible[index].id),
                          onTap: () => _open(visible[index].id),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, int count, CandidateFilter filter) {
    final selected = _filter == filter;

    return ChoiceChip(
      label: Text('$label $count'),
      selected: selected,
      showCheckmark: false,
      visualDensity: VisualDensity.compact,
      backgroundColor: AppColor.surface,
      selectedColor: AppColor.accent,
      labelStyle: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: selected ? Colors.white : AppColor.muted,
      ),
      side: BorderSide(color: selected ? AppColor.accent : AppColor.line),
      shape: const StadiumBorder(),
      onSelected: (_) => setState(() => _filter = filter),
    );
  }
}

/// "이어서 채점하기" 카드. 미완료가 하나도 없으면 목록 위에 뜨지 않는다.
class _ResumeCard extends StatelessWidget {
  const _ResumeCard({
    required this.candidate,
    required this.remaining,
    required this.onTap,
  });

  final CandidateInfo candidate;
  final int remaining;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColor.accent,
      borderRadius: BorderRadius.circular(AppRadius.card),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '이어서 채점하기 · $remaining명 남음',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: Colors.white.withValues(alpha: 0.75),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      candidate.label,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward, color: Colors.white, size: 20),
              const SizedBox(width: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _CandidateTile extends StatelessWidget {
  const _CandidateTile({
    required this.candidate,
    required this.payload,
    required this.pending,
    required this.onTap,
  });

  final CandidateInfo candidate;
  final JudgePayload payload;
  final bool pending;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final complete = payload.isComplete(candidate.id);
    final total = payload.totalOf(candidate.id);
    final given = payload.scoresOf(candidate.id).length;
    final leaves = payload.leafItems.length;

    return Material(
      color: AppColor.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
        side: BorderSide(color: complete ? AppColor.successSoft : AppColor.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: complete ? AppColor.successSoft : AppColor.canvas,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  candidate.number,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    color: complete ? AppColor.success : AppColor.muted,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            candidate.name?.isNotEmpty == true
                                ? candidate.name!
                                : '${candidate.number}번',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w700,
                              color: AppColor.ink,
                            ),
                          ),
                        ),
                        if (pending) ...[
                          const SizedBox(width: 6),
                          const StatusPill(
                            text: '전송 대기',
                            icon: Icons.schedule,
                            color: AppColor.accent,
                            background: AppColor.accentSoft,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      complete
                          ? '완료 · ${formatScore(total)} / ${payload.totalMax}점'
                          : given == 0
                          ? '아직 채점하지 않음'
                          : '입력 중 · $leaves개 중 $given개',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: complete ? AppColor.success : AppColor.muted,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right,
                size: 20,
                color: AppColor.faint,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
