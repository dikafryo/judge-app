import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/api.dart';
import '../core/design.dart';
import '../models/admin.dart';
import '../store/admin_api.dart';
import 'admin_dashboard_tab.dart';
import 'admin_settings_tab.dart';
import 'admin_setup_tabs.dart';

Key adminSetupRevision(AdminEvent event, int visit) =>
    ValueKey('setup-${event.id}-${event.isOpen}-$visit');

/// 관리자 홈. 웹의 좌측 메뉴(집계·항목·대상·심사위원·설정)를 하단 탭으로 옮겼다.
class AdminHomeScreen extends ConsumerStatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  ConsumerState<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends ConsumerState<AdminHomeScreen> {
  int _tab = 0;
  int _judgesVisit = 0;
  bool _signingOut = false;

  /// 나갈 때 서버의 토큰부터 폐기한다. 기기에서만 잊으면 토큰이 서버에 살아 남는다.
  Future<void> _signOut(AdminApi admin) async {
    if (_signingOut) return;

    setState(() => _signingOut = true);
    await admin.signOut();

    if (!mounted) return;

    ref.read(adminApiProvider.notifier).state = null;
    Navigator.of(context).pop();
  }

  Future<void> _openPrint(AdminApi admin, String kind) async {
    try {
      // 인쇄물은 서버의 A4 출력을 시스템 브라우저로 넘긴다.
      final url = await admin.printUrl(kind);

      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final admin = ref.watch(adminApiProvider);

    if (admin == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: kDarkSystemBars,
      child: Scaffold(
        body: Column(
          children: [
            _AdminHeader(
              event: admin.event,
              onPrint: (kind) => _openPrint(admin, kind),
              onSignOut: _signingOut ? null : () => _signOut(admin),
            ),
            if (admin.event.isDemo)
              const StatusStrip(
                icon: Icons.visibility_outlined,
                text: '체험 행사는 둘러보기만 할 수 있습니다',
                foreground: AppColor.warn,
                background: AppColor.warnSoft,
              ),
            Expanded(
              // 상태바 인셋은 머리 판이 이미 비켰다. 탭 목록이 한 번 더 비키지 않게 뗀다.
              child: MediaQuery.removePadding(
                context: context,
                removeTop: true,
                child: IndexedStack(
                  index: _tab,
                  children: [
                    const AdminDashboardTab(),
                    const AdminCriteriaTab(),
                    const AdminCandidatesTab(),
                    AdminJudgesTab(
                      key: adminSetupRevision(admin.event, _judgesVisit),
                    ),
                    const AdminSettingsTab(),
                  ],
                ),
              ),
            ),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _tab,
          onDestinationSelected: (index) => setState(() {
            // 심사위원 탭은 열 때마다 서버에서 새로 읽어야 마감·재개 코드가 즉시 반영된다.
            if (index == 3) _judgesVisit++;
            _tab = index;
          }),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.leaderboard_outlined),
              selectedIcon: Icon(Icons.leaderboard),
              label: '집계',
            ),
            NavigationDestination(
              icon: Icon(Icons.checklist_outlined),
              selectedIcon: Icon(Icons.checklist),
              label: '항목',
            ),
            NavigationDestination(
              icon: Icon(Icons.groups_outlined),
              selectedIcon: Icon(Icons.groups),
              label: '대상',
            ),
            NavigationDestination(
              icon: Icon(Icons.badge_outlined),
              selectedIcon: Icon(Icons.badge),
              label: '심사위원',
            ),
            NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings),
              label: '설정',
            ),
          ],
        ),
      ),
    );
  }
}

/// 관리자 머리 판. 심사위원 목록과 같은 그라데이션 판을 써서
/// 주요 화면 중 흰 앱바만 남아 있던 곳을 없앤다. 긴 행사명은 두 줄까지 보인다.
class _AdminHeader extends StatelessWidget {
  const _AdminHeader({
    required this.event,
    required this.onPrint,
    required this.onSignOut,
  });

  final AdminEvent event;
  final ValueChanged<String> onPrint;

  /// null 이면 로그아웃 중이라 다시 누를 수 없다.
  final VoidCallback? onSignOut;

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;

    return HeroPanel(
      radius: const BorderRadius.vertical(bottom: Radius.circular(28)),
      padding: EdgeInsets.fromLTRB(20, topInset + 10, 12, 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 20,
                      height: 1.3,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // 판 위에서는 연한 성공·경고 바탕이 탁해 보여 흰 바탕 알약을 쓴다.
                  event.isOpen
                      ? StatusPill(
                          text: '심사 진행 중',
                          icon: Icons.play_arrow_rounded,
                          color: AppColor.success,
                          background: Colors.white.withValues(alpha: 0.9),
                        )
                      : StatusPill(
                          text: '심사 마감',
                          icon: Icons.lock_outline,
                          color: AppColor.warn,
                          background: Colors.white.withValues(alpha: 0.9),
                        ),
                ],
              ),
            ),
          ),
          Builder(
            builder: (context) => HeroAction(
              tooltip: '출력',
              icon: Icons.print_outlined,
              onTap: () => _showPrintMenu(context),
            ),
          ),
          HeroAction(
            tooltip: '나가기',
            icon: Icons.logout,
            onTap: onSignOut ?? () {},
          ),
        ],
      ),
    );
  }

  /// [HeroAction] 은 단추 모양만 책임지므로, 출력 메뉴는 단추 자리 아래에 직접 띄운다.
  Future<void> _showPrintMenu(BuildContext anchor) async {
    final box = anchor.findRenderObject()! as RenderBox;
    final overlay =
        Navigator.of(anchor).overlay!.context.findRenderObject()! as RenderBox;
    final position = RelativeRect.fromRect(
      Rect.fromPoints(
        box.localToGlobal(box.size.bottomLeft(Offset.zero), ancestor: overlay),
        box.localToGlobal(box.size.bottomRight(Offset.zero), ancestor: overlay),
      ),
      Offset.zero & overlay.size,
    );

    final kind = await showMenu<String>(
      context: anchor,
      position: position,
      items: const [
        PopupMenuItem(
          value: 'report',
          child: ListTile(
            leading: IconBadge(icon: Icons.description_outlined, size: 32),
            title: Text('최종집계표 (A4)'),
          ),
        ),
        PopupMenuItem(
          value: 'csv',
          child: ListTile(
            leading: IconBadge(
              icon: Icons.table_chart_outlined,
              tone: AppTone.teal,
              size: 32,
            ),
            title: Text('결과 CSV'),
          ),
        ),
        PopupMenuItem(
          value: 'judge-cards',
          child: ListTile(
            leading: IconBadge(
              icon: Icons.qr_code_2,
              tone: AppTone.violet,
              size: 32,
            ),
            title: Text('심사위원 접속 카드'),
          ),
        ),
      ],
    );

    if (kind != null) onPrint(kind);
  }
}
