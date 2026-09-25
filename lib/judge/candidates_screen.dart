import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
///
/// 맨 위 그라데이션 판이 행사명·심사위원·진행률을, 그 아래 색 타일 세 장이
/// 전체·미완료·완료 수를 보여 주면서 동시에 목록의 필터 노릇을 한다.
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
      MaterialPageRoute(
        builder: (_) => ScoringScreen(candidateId: candidateId),
      ),
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
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: kDarkSystemBars,
      child: Scaffold(
        body: Column(
          children: [
            _Header(
              payload: payload,
              session: session,
              done: done,
              total: total,
              onSign: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SignatureScreen()),
              ),
              onSignOut: () => _confirmSignOut(session),
            ),
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
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                        child: Row(
                          children: [
                            Expanded(
                              child: _filterTile(
                                '전체',
                                total,
                                CandidateFilter.all,
                                AppTone.indigo,
                                Icons.groups_outlined,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _filterTile(
                                '미완료',
                                total - done,
                                CandidateFilter.todo,
                                AppTone.amber,
                                Icons.pending_actions_outlined,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _filterTile(
                                '완료',
                                done,
                                CandidateFilter.done,
                                AppTone.teal,
                                Icons.task_alt_outlined,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (todo != null)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                          child: _ResumeCard(
                            candidate: todo,
                            remaining: total - done,
                            onTap: () => _open(todo.id),
                          ),
                        ),
                      ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                        child: SearchField(
                          controller: _search,
                          hint: '이름 · 번호 · 소속으로 찾기',
                          onChanged: (_) => setState(() {}),
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
                        padding: EdgeInsets.fromLTRB(
                          16,
                          10,
                          16,
                          24 + bottomInset,
                        ),
                        sliver: SliverList.separated(
                          itemCount: visible.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 10),
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
      ),
    );
  }

  Widget _filterTile(
    String label,
    int count,
    CandidateFilter filter,
    AppTone tone,
    IconData icon,
  ) {
    return StatTile(
      label: label,
      value: '$count',
      tone: tone,
      icon: icon,
      selected: _filter == filter,
      onTap: () => setState(() => _filter = filter),
    );
  }
}

/// 그라데이션 머리 판 — 행사명·심사위원·진행률·마지막 전송 시각.
class _Header extends StatelessWidget {
  const _Header({
    required this.payload,
    required this.session,
    required this.done,
    required this.total,
    required this.onSign,
    required this.onSignOut,
  });

  final JudgePayload payload;
  final JudgeState session;
  final int done;
  final int total;
  final VoidCallback onSign;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    final ratio = total == 0 ? 0.0 : done / total;

    return HeroPanel(
      radius: const BorderRadius.vertical(bottom: Radius.circular(28)),
      padding: EdgeInsets.fromLTRB(20, topInset + 10, 12, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        payload.event.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 18,
                          height: 1.3,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${payload.judgeName} 심사위원',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              HeroAction(
                tooltip: payload.hasSignature ? '서명 다시 하기' : '서명하기',
                icon: payload.hasSignature ? Icons.draw : Icons.draw_outlined,
                highlighted: payload.hasSignature,
                onTap: onSign,
              ),
              HeroAction(tooltip: '나가기', icon: Icons.logout, onTap: onSignOut),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(AppRadius.card),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Expanded(
                      child: Text(
                        '심사 진행',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                      ),
                    ),
                    Text(
                      '$done',
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                    ),
                    Text(
                      ' / $total',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: ratio),
                    duration: const Duration(milliseconds: 420),
                    curve: Curves.easeOutCubic,
                    builder: (context, animated, _) => LinearProgressIndicator(
                      value: animated,
                      minHeight: 8,
                      color: Colors.white,
                      backgroundColor: Colors.white.withValues(alpha: 0.25),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(
                      session.isSettled
                          ? Icons.cloud_done_outlined
                          : Icons.cloud_queue,
                      size: 14,
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        formatSyncedAt(session.lastSyncedAt),
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                      ),
                    ),
                    Text(
                      session.syncing ? '전송 중' : '당겨서 새로고침',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: Colors.white.withValues(alpha: 0.65),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
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
    return CardBox(
      color: AppColor.ink,
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
      child: Row(
        children: [
          const IconBadge(
            icon: Icons.play_arrow_rounded,
            tone: AppTone.indigo,
            filled: true,
            size: 44,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '이어서 채점하기 · $remaining명 남음',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: Colors.white.withValues(alpha: 0.7),
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
          Icon(
            Icons.arrow_forward_rounded,
            color: Colors.white.withValues(alpha: 0.8),
            size: 22,
          ),
        ],
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
    final started = !complete && given > 0;

    // 상태마다 색을 정한다: 완료=청록, 입력 중=호박, 아직=회색.
    final (badgeBg, badgeFg) = complete
        ? (AppTone.teal.soft, AppTone.teal.ink)
        : started
        ? (AppTone.amber.soft, AppTone.amber.ink)
        : (AppColor.canvas, AppColor.muted);

    return CardBox(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: badgeBg,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              candidate.number,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: badgeFg,
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
                const SizedBox(height: 4),
                if (candidate.affiliation?.isNotEmpty == true)
                  Text(
                    candidate.affiliation!,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: AppColor.muted,
                    ),
                  ),
                if (started) ...[
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    child: LinearProgressIndicator(
                      value: leaves == 0 ? 0 : given / leaves,
                      minHeight: 5,
                      color: AppTone.amber.strong,
                      backgroundColor: AppTone.amber.soft,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          if (complete)
            _ScoreChip(text: '${formatScore(total)}점', tone: AppTone.teal)
          else if (started)
            _ScoreChip(text: '$given / $leaves', tone: AppTone.amber)
          else
            const Icon(Icons.chevron_right, size: 22, color: AppColor.faint),
        ],
      ),
    );
  }
}

/// 줄 오른쪽 끝의 점수·진행 표시.
class _ScoreChip extends StatelessWidget {
  const _ScoreChip({required this.text, required this.tone});

  final String text;
  final AppTone tone;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: tone.soft,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13.5,
          fontWeight: FontWeight.w800,
          color: tone.ink,
        ),
      ),
    );
  }
}
