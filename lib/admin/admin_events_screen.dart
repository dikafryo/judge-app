import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api.dart';
import '../core/brand.dart';
import '../core/design.dart';
import '../models/admin.dart';
import '../store/admin_api.dart';
import 'admin_home_screen.dart';

/// 관리자 입구 — 행사를 고르고 관리 비밀번호로 들어간다.
/// 회원가입이 없고 행사별 비밀번호가 유일한 열쇠라는 점이 웹과 같다.
class AdminEventsScreen extends ConsumerStatefulWidget {
  const AdminEventsScreen({super.key});

  @override
  ConsumerState<AdminEventsScreen> createState() => _AdminEventsScreenState();
}

class _AdminEventsScreenState extends ConsumerState<AdminEventsScreen> {
  late Future<List<EventSummary>> _events;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _events = AdminApi.events(ref.read(adminBaseApiProvider));
  }

  Future<void> _open(AdminApi admin) async {
    ref.read(adminApiProvider.notifier).state = admin;

    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const AdminHomeScreen()));

    // 돌아왔으면 로그아웃된 것이다. 목록의 진행 상태가 바뀌었을 수 있어 다시 읽는다.
    if (mounted) setState(_load);
  }

  Future<void> _signIn(EventSummary event) async {
    final password = await _askPassword(event.name);

    if (password == null || !mounted) return;

    await _run(() async {
      final admin = await AdminApi.signIn(
        ref.read(adminBaseApiProvider),
        event.id,
        password,
      );

      await _open(admin);
    });
  }

  Future<void> _create() async {
    final input = await _askNewEvent();

    if (input == null || !mounted) return;

    await _run(() async {
      final admin = await AdminApi.createEvent(
        ref.read(adminBaseApiProvider),
        name: input.$1,
        password: input.$2,
      );

      await _open(admin);
    });
  }

  Future<void> _run(Future<void> Function() action) async {
    try {
      await action();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  Future<String?> _askPassword(String eventName) {
    final controller = TextEditingController();

    return showDialog<String>(
      context: context,
      builder: (context) => AppDialog(
        icon: Icons.lock_outline,
        title: eventName,
        subtitle: '회원가입 없이 이 비밀번호만으로 들어갑니다.',
        confirmLabel: '들어가기',
        onConfirm: () => Navigator.pop(context, controller.text),
        child: AppField(
          label: '관리 비밀번호',
          controller: controller,
          autofocus: true,
          obscure: true,
          onSubmitted: (value) => Navigator.pop(context, value),
        ),
      ),
    );
  }

  Future<(String, String)?> _askNewEvent() {
    return showDialog<(String, String)>(
      context: context,
      builder: (context) => const _NewEventDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 20,
        title: const Text('행사 관리'),
        bottom: const _AppBarHairline(),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _create,
        icon: const Icon(Icons.add_rounded),
        label: const Text('새 행사'),
      ),
      body: FutureBuilder<List<EventSummary>>(
        future: _events,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return ErrorView(
              message: snapshot.error is ApiException
                  ? (snapshot.error as ApiException).message
                  : '행사 목록을 불러오지 못했습니다.',
              onRetry: () => setState(_load),
            );
          }

          final events = snapshot.data ?? const <EventSummary>[];

          if (events.isEmpty) {
            return const EmptyState(
              icon: Icons.event_note_outlined,
              text: '아직 만들어진 행사가 없습니다.',
              detail: "아래 '새 행사' 를 눌러 첫 행사를 만드세요.",
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            itemCount: events.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) => _EventTile(
              event: events[index],
              onTap: () => _signIn(events[index]),
            ),
          );
        },
      ),
    );
  }
}

/// 앱바와 내용 사이의 실선. 흰 앱바가 흰 카드 위에 떠 있으면 경계가 사라진다.
class _AppBarHairline extends StatelessWidget implements PreferredSizeWidget {
  const _AppBarHairline();

  @override
  Size get preferredSize => const Size.fromHeight(1);

  @override
  Widget build(BuildContext context) => const Divider(height: 1);
}

class _EventTile extends StatelessWidget {
  const _EventTile({required this.event, required this.onTap});

  final EventSummary event;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColor.surface,
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: AppColor.line),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 15, 12, 15),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              event.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppColor.ink,
                                height: 1.3,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (event.isOpen)
                            const StatusPill(
                              text: '진행 중',
                              icon: Icons.play_arrow_rounded,
                              color: AppColor.success,
                              background: AppColor.successSoft,
                            )
                          else
                            const StatusPill(
                              text: '마감',
                              icon: Icons.lock_outline,
                              color: AppColor.warn,
                              background: AppColor.warnSoft,
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          _Stat(
                            icon: Icons.groups_outlined,
                            value: event.candidates,
                            label: '대상',
                          ),
                          _Stat(
                            icon: Icons.checklist_outlined,
                            value: event.criteria,
                            label: '항목',
                          ),
                          _Stat(
                            icon: Icons.badge_outlined,
                            value: event.judges,
                            label: '심사위원',
                          ),
                        ],
                      ),
                      if (event.date != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          event.date!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColor.muted,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: AppColor.faint),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 대상 12 · 항목 3 처럼 한 줄로 늘어놓던 것을 아이콘과 함께 끊어 읽게 한다.
class _Stat extends StatelessWidget {
  const _Stat({required this.icon, required this.value, required this.label});

  final IconData icon;
  final int value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 16),
      child: Row(
        children: [
          Icon(icon, size: 14, color: AppColor.faint),
          const SizedBox(width: 4),
          Text(
            '$label $value',
            style: const TextStyle(fontSize: 12.5, color: AppColor.muted),
          ),
        ],
      ),
    );
  }
}

/// 새 행사 만들기.
///
/// 예전에는 이름이 비었거나 비밀번호가 짧으면 '만들기' 를 눌러도 **아무 일도
/// 일어나지 않았다.** 왜 안 되는지 알 길이 없었으므로, 지금은 버튼을 흐리게 두고
/// 비밀번호 칸에 이유를 적는다.
class _NewEventDialog extends StatefulWidget {
  const _NewEventDialog();

  @override
  State<_NewEventDialog> createState() => _NewEventDialogState();
}

class _NewEventDialogState extends State<_NewEventDialog> {
  final _name = TextEditingController();
  final _password = TextEditingController();

  static const _minPassword = 4;

  @override
  void dispose() {
    _name.dispose();
    _password.dispose();
    super.dispose();
  }

  bool get _valid =>
      _name.text.trim().isNotEmpty && _password.text.length >= _minPassword;

  @override
  Widget build(BuildContext context) {
    return AppDialog(
      icon: Icons.add_rounded,
      title: '새 행사 만들기',
      subtitle: '행사명과 비밀번호만 있으면 시작합니다.',
      confirmLabel: '만들기',
      onConfirm: _valid
          ? () => Navigator.pop(context, (_name.text.trim(), _password.text))
          : null,
      child: Column(
        children: [
          AppField(
            label: '행사명',
            controller: _name,
            autofocus: true,
            hint: '예: 제1회 가을 경진대회',
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          AppField(
            label: '관리 비밀번호',
            controller: _password,
            obscure: true,
            helper:
                _password.text.isEmpty || _password.text.length >= _minPassword
                ? '이 비밀번호가 유일한 열쇠입니다. 잊으면 되찾을 수 없습니다.'
                : '$_minPassword자 이상 입력하세요.',
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
    );
  }
}
