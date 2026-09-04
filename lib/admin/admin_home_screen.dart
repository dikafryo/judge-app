import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/api.dart';
import '../store/admin_api.dart';
import 'admin_dashboard_tab.dart';
import 'admin_settings_tab.dart';
import 'admin_setup_tabs.dart';

/// 관리자 홈. 웹의 좌측 메뉴(집계·항목·대상·심사위원·설정)를 하단 탭으로 옮겼다.
class AdminHomeScreen extends ConsumerStatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  ConsumerState<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends ConsumerState<AdminHomeScreen> {
  int _tab = 0;

  Future<void> _openPrint(AdminApi admin, String kind) async {
    try {
      // 인쇄물은 서버의 A4 출력을 시스템 브라우저로 넘긴다.
      final url = await admin.printUrl(kind);

      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final admin = ref.watch(adminApiProvider);

    if (admin == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(admin.event.name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            Text(
              admin.event.isOpen ? '심사 진행 중' : '심사 마감',
              style: TextStyle(
                fontSize: 12,
                color: admin.event.isOpen ? const Color(0xFF15803D) : const Color(0xFF92400E),
              ),
            ),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.print_outlined),
            tooltip: '출력',
            onSelected: (kind) => _openPrint(admin, kind),
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'report', child: Text('최종집계표 (A4)')),
              PopupMenuItem(value: 'csv', child: Text('결과 CSV')),
              PopupMenuItem(value: 'judge-cards', child: Text('심사위원 접속 카드')),
            ],
          ),
          IconButton(
            tooltip: '나가기',
            icon: const Icon(Icons.logout),
            onPressed: () {
              ref.read(adminApiProvider.notifier).state = null;
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
      body: IndexedStack(
        index: _tab,
        children: const [
          AdminDashboardTab(),
          AdminCriteriaTab(),
          AdminCandidatesTab(),
          AdminJudgesTab(),
          AdminSettingsTab(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (index) => setState(() => _tab = index),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.leaderboard_outlined), label: '집계'),
          NavigationDestination(icon: Icon(Icons.checklist_outlined), label: '항목'),
          NavigationDestination(icon: Icon(Icons.groups_outlined), label: '대상'),
          NavigationDestination(icon: Icon(Icons.badge_outlined), label: '심사위원'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), label: '설정'),
        ],
      ),
    );
  }
}
