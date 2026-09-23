import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api.dart';
import '../core/brand.dart';
import '../core/design.dart';
import '../models/admin.dart';
import '../models/payload.dart' show formatScore;
import '../store/admin_api.dart';

/// 실시간 집계. 5초마다 다시 읽는다 — 웹 대시보드와 같은 주기다.
///
/// 계산은 전부 서버가 한다. 앱이 순위를 다시 매기면 웹과 숫자가 어긋날 수 있고,
/// 그 어긋남이 발표장에서 드러나는 것이 가장 나쁜 결과다.
class AdminDashboardTab extends ConsumerStatefulWidget {
  const AdminDashboardTab({super.key});

  @override
  ConsumerState<AdminDashboardTab> createState() => _AdminDashboardTabState();
}

class _AdminDashboardTabState extends ConsumerState<AdminDashboardTab> {
  Timer? _poll;
  Dashboard? _data;
  String? _error;

  @override
  void initState() {
    super.initState();

    unawaited(_load());
    _poll = Timer.periodic(
      const Duration(seconds: 5),
      (_) => unawaited(_load()),
    );
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final admin = ref.read(adminApiProvider);

    if (admin == null) return;

    try {
      final data = await admin.dashboard();

      if (mounted) {
        setState(() {
          _data = data;
          _error = null;
        });
      }
    } on ApiException catch (e) {
      // 이미 받아 둔 집계가 있으면 그것을 계속 보여주되, 최신이 아님을 알린다.
      if (mounted) setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;

    if (data == null) {
      return _error == null
          ? const Center(child: CircularProgressIndicator())
          : ErrorView(message: _error!, onRetry: () => unawaited(_load()));
    }

    final judgesDone = data.judges
        .where((j) => j.total > 0 && j.done >= j.total)
        .length;
    final scored = data.rows.where((r) => r.avg != null).length;
    final top = data.rows.isEmpty ? null : data.rows.first;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
        children: [
          if (_error != null) ...[
            NoticeBox(
              tone: NoticeTone.warn,
              text: '최신 집계가 아닙니다',
              detail: _error,
            ),
            const SizedBox(height: 12),
          ],
          if (data.passTie != null) ...[
            const NoticeBox(
              tone: NoticeTone.warn,
              text: '선정 경계에 동점이 있습니다',
              detail: '발표 전에 동점을 해소해야 합니다.',
            ),
            const SizedBox(height: 12),
          ],
          // 한눈에 볼 숫자 네 개. 발표 직전에 사회자가 보는 것은 이 줄이다.
          Row(
            children: [
              Expanded(
                child: StatTile(
                  label: '심사 완료',
                  value: '$judgesDone',
                  suffix: ' / ${data.judges.length}명',
                  tone: AppTone.indigo,
                  icon: Icons.badge_outlined,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: StatTile(
                  label: '채점된 대상',
                  value: '$scored',
                  suffix: ' / ${data.rows.length}',
                  tone: AppTone.sky,
                  icon: Icons.groups_outlined,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: StatTile(
                  label: '선정 인원',
                  value: data.passCount?.toString() ?? '–',
                  suffix: data.passCount == null ? null : '곳',
                  tone: AppTone.amber,
                  icon: Icons.emoji_events_outlined,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: StatTile(
                  label: '현재 1위',
                  value: top?.avg == null ? '–' : formatScore(top!.avg!),
                  suffix: top?.avg == null ? null : ' / ${data.totalMax}점',
                  tone: AppTone.teal,
                  icon: Icons.leaderboard_outlined,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _JudgeProgressCard(judges: data.judges),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
            child: Row(
              children: [
                const Expanded(
                  child: Text('순위', style: SectionCard.sectionTitleStyle),
                ),
                Text(
                  data.scoringMethodLabel,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: AppColor.muted,
                  ),
                ),
              ],
            ),
          ),
          if (data.rows.isEmpty)
            const EmptyState(
              icon: Icons.leaderboard_outlined,
              text: '아직 순위가 없습니다',
              detail: '심사위원이 점수를 넣으면 여기에 순위가 나타납니다.',
            ),
          for (final row in data.rows)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _RankTile(row: row, totalMax: data.totalMax),
            ),
          const SizedBox(height: 6),
          Text(
            data.scoringNote,
            style: const TextStyle(
              fontSize: 11.5,
              color: AppColor.muted,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              '${data.generatedAt} 기준 · 5초마다 갱신',
              style: const TextStyle(fontSize: 11.5, color: AppColor.muted),
            ),
          ),
        ],
      ),
    );
  }
}

extension on Dashboard {
  /// 집계 방식을 순위 머리에 짧게 적는다. 긴 설명([scoringNote])은 맨 아래에 있다.
  String get scoringMethodLabel =>
      scoringNote.contains('제외') ? '최고·최저 제외' : '전체 평균';
}

class _JudgeProgressCard extends StatelessWidget {
  const _JudgeProgressCard({required this.judges});

  final List<JudgeProgress> judges;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: '심사위원 진행',
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (judges.isEmpty)
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text(
                '등록된 심사위원이 없습니다.',
                style: TextStyle(color: AppColor.muted),
              ),
            ),
          for (final (index, judge) in judges.indexed)
            _JudgeRow(judge: judge, tone: AppToneColors.at(index)),
        ],
      ),
    );
  }
}

class _JudgeRow extends StatelessWidget {
  const _JudgeRow({required this.judge, required this.tone});

  final JudgeProgress judge;
  final AppTone tone;

  @override
  Widget build(BuildContext context) {
    final complete = judge.total > 0 && judge.done >= judge.total;
    final ratio = judge.total == 0 ? 0.0 : judge.done / judge.total;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          LetterAvatar(text: judge.name, tone: tone, size: 38),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        judge.name,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: AppColor.ink,
                        ),
                      ),
                    ),
                    if (judge.signed)
                      const Padding(
                        padding: EdgeInsets.only(right: 8),
                        child: StatusPill(
                          text: '서명',
                          icon: Icons.draw_outlined,
                          color: AppColor.success,
                          background: AppColor.successSoft,
                        ),
                      ),
                    Text(
                      '${judge.done} / ${judge.total}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: complete ? AppColor.success : AppColor.muted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  child: LinearProgressIndicator(
                    value: ratio,
                    minHeight: 6,
                    color: complete ? AppColor.success : tone.strong,
                    backgroundColor: AppColor.canvas,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RankTile extends StatelessWidget {
  const _RankTile({required this.row, required this.totalMax});

  final DashboardRow row;
  final int totalMax;

  @override
  Widget build(BuildContext context) {
    final selected = row.pass == 'pass';
    final tie = row.pass == 'tie';
    final ratio = row.avg == null || totalMax == 0 ? 0.0 : row.avg! / totalMax;

    return CardBox(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      color: tie
          ? AppColor.warnSoft
          : selected
          ? AppColor.accentSoft
          : AppColor.surface,
      outline: tie ? AppTone.amber.strong : null,
      child: Row(
        children: [
          RankBadge(rank: row.rank),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  row.name?.isNotEmpty == true ? row.name! : '${row.number}번',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColor.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${row.affiliation ?? ''}${row.affiliation != null ? ' · ' : ''}'
                  '심사 ${row.judgedCount}명 완료',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: AppColor.muted),
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  child: LinearProgressIndicator(
                    value: ratio,
                    minHeight: 5,
                    color: tie
                        ? AppTone.amber.strong
                        : selected
                        ? AppColor.accent
                        : AppColor.faint,
                    backgroundColor: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                row.avg == null ? '–' : formatScore(row.avg!),
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                  color: tie
                      ? AppTone.amber.ink
                      : selected
                      ? AppColor.accent
                      : AppColor.ink,
                ),
              ),
              if (tie)
                const StatusPill(
                  text: '동점',
                  color: AppColor.warn,
                  background: Colors.white,
                )
              else if (selected)
                const StatusPill(
                  text: '선정',
                  icon: Icons.check,
                  color: AppColor.accent,
                  background: Colors.white,
                )
              else
                Text(
                  '/ $totalMax점',
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: AppColor.muted,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
