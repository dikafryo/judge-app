import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/payload.dart';
import '../store/judge_session.dart';
import 'scoring_screen.dart';
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

  @override
  void dispose() {
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

      return '${c.number} ${c.name ?? ''} ${c.affiliation ?? ''}'.toLowerCase().contains(keyword);
    }).toList();
  }

  Future<void> _confirmSignOut(JudgeState session) async {
    final pending = session.pendingCount;

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('심사를 끝내고 나갈까요?'),
        content: Text(
          pending > 0
              ? '아직 서버로 보내지 못한 입력이 $pending건 있습니다.\n지금 나가면 그 입력은 사라집니다.'
              : '다시 심사하려면 접속 코드를 새로 입력해야 합니다.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('계속 심사')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('나가기', style: TextStyle(color: pending > 0 ? Colors.red : null)),
          ),
        ],
      ),
    );

    if (ok == true) await ref.read(judgeSessionProvider.notifier).signOut();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(judgeSessionProvider);
    final payload = session.payload;

    if (payload == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    final visible = _visible(payload);
    final total = payload.candidates.length;
    final done = payload.completedCount;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(payload.event.name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            Text(
              '${payload.judgeName} 심사위원',
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: '새로고침',
            onPressed: () => ref.read(judgeSessionProvider.notifier).sync(),
            icon: session.syncing
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.refresh),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'signature') {
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SignatureScreen()));
              } else {
                _confirmSignOut(session);
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'signature',
                child: Text(payload.hasSignature ? '서명 다시 하기' : '서명하기'),
              ),
              const PopupMenuItem(value: 'signout', child: Text('나가기')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          if (!payload.event.isOpen)
            const _Banner(
              color: Color(0xFFFEF3C7),
              text: '심사가 마감되었습니다. 점수를 더 저장할 수 없습니다.',
              icon: Icons.lock_outline,
            ),
          if (session.pendingCount > 0)
            _Banner(
              color: const Color(0xFFE0E7FF),
              icon: Icons.cloud_upload_outlined,
              text: session.offline
                  ? '연결이 끊겨 ${session.pendingCount}건이 기기에 보관 중입니다. 연결되면 자동으로 전송됩니다.'
                  : '${session.pendingCount}건 전송 중입니다.',
            ),
          _Progress(done: done, total: total),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: TextField(
              controller: _search,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: '이름 · 번호로 찾기',
                prefixIcon: const Icon(Icons.search, size: 20),
                isDense: true,
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          SingleChildScrollView(
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
          const SizedBox(height: 4),
          Expanded(
            child: visible.isEmpty
                ? const Center(
                    child: Text('해당하는 평가 대상이 없습니다.', style: TextStyle(color: Color(0xFF94A3B8))),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    itemCount: visible.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) => _CandidateTile(
                      candidate: visible[index],
                      payload: payload,
                      pending: session.isPending(visible[index].id),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ScoringScreen(candidateId: visible[index].id),
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, int count, CandidateFilter filter) => ChoiceChip(
        label: Text('$label $count'),
        selected: _filter == filter,
        onSelected: (_) => setState(() => _filter = filter),
      );
}

class _Progress extends StatelessWidget {
  const _Progress({required this.done, required this.total});

  final int done;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('심사 진행', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
              Text(
                '$done / $total',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: total == 0 ? 0 : done / total,
              minHeight: 6,
              backgroundColor: const Color(0xFFE2E8F0),
            ),
          ),
        ],
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.color, required this.text, required this.icon});

  final Color color;
  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: color,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Icon(icon, size: 18, color: const Color(0xFF334155)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: const TextStyle(fontSize: 13, color: Color(0xFF334155))),
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

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: complete ? const Color(0xFFDCFCE7) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  candidate.number,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: complete ? const Color(0xFF15803D) : const Color(0xFF64748B),
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
                            candidate.name?.isNotEmpty == true ? candidate.name! : '${candidate.number}번',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                        ),
                        if (pending) ...[
                          const SizedBox(width: 6),
                          const _Tag(text: '대기', color: Color(0xFF4F46E5)),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      complete
                          ? '완료 · ${formatScore(total)} / ${payload.totalMax}점'
                          : given == 0
                              ? '아직 채점하지 않음'
                              : '입력 중 · ${payload.leafItems.length}개 중 $given개',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: complete ? const Color(0xFF15803D) : const Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Color(0xFFCBD5E1)),
            ],
          ),
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
    );
  }
}
