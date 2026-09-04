import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api.dart';
import '../core/brand.dart';
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
    _poll = Timer.periodic(const Duration(seconds: 5), (_) => unawaited(_load()));
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

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          if (_error != null)
            _Notice(
              color: const Color(0xFFFEE2E2),
              icon: Icons.cloud_off,
              text: '최신이 아닙니다 — $_error',
            ),
          if (data.passTie != null)
            const _Notice(
              color: Color(0xFFFEF3C7),
              icon: Icons.warning_amber_outlined,
              text: '선정 경계에 동점이 있습니다. 발표 전에 동점을 해소해야 합니다.',
            ),
          Text(
            data.scoringNote,
            style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 12),
          _JudgeProgressCard(judges: data.judges),
          const SizedBox(height: 16),
          const Text('순위', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          for (final row in data.rows) _RankTile(row: row, totalMax: data.totalMax),
          const SizedBox(height: 12),
          Center(
            child: Text(
              '${data.generatedAt} 기준',
              style: const TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8)),
            ),
          ),
        ],
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.color, required this.icon, required this.text});

  final Color color;
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(10)),
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

class _JudgeProgressCard extends StatelessWidget {
  const _JudgeProgressCard({required this.judges});

  final List<JudgeProgress> judges;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('심사위원 진행', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          for (final judge in judges)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(child: Text(judge.name, style: const TextStyle(fontSize: 14))),
                  if (judge.signed)
                    const Padding(
                      padding: EdgeInsets.only(right: 8),
                      child: Icon(Icons.draw_outlined, size: 16, color: Color(0xFF15803D)),
                    ),
                  Text(
                    '${judge.done} / ${judge.total}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: judge.done >= judge.total && judge.total > 0
                          ? const Color(0xFF15803D)
                          : const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
          if (judges.isEmpty)
            const Text('등록된 심사위원이 없습니다.', style: TextStyle(color: Color(0xFF94A3B8))),
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

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: tie
            ? Border.all(color: const Color(0xFFF59E0B), width: 1.5)
            : selected
                ? Border.all(color: const Color(0xFF4F46E5), width: 1.5)
                : null,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 34,
            child: Text(
              row.rank?.toString() ?? '–',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  row.name?.isNotEmpty == true ? row.name! : '${row.number}번',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
                Text(
                  '${row.affiliation ?? ''}${row.affiliation != null ? ' · ' : ''}'
                  '심사 ${row.judgedCount}명 완료',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                row.avg == null ? '–' : '${formatScore(row.avg!)}점',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF4F46E5)),
              ),
              if (tie)
                const Text('동점', style: TextStyle(fontSize: 11, color: Color(0xFFB45309)))
              else if (selected)
                const Text('선정', style: TextStyle(fontSize: 11, color: Color(0xFF4F46E5))),
            ],
          ),
        ],
      ),
    );
  }
}
