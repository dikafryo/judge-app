import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
    final topInset = MediaQuery.paddingOf(context).top;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: kDarkSystemBars,
      child: Scaffold(
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _create,
          icon: const Icon(Icons.add_rounded),
          label: const Text('새 행사'),
        ),
        body: FutureBuilder<List<EventSummary>>(
          future: _events,
          builder: (context, snapshot) {
            final events = snapshot.data ?? const <EventSummary>[];
            final open = events.where((e) => e.isOpen).length;

            return Column(
              children: [
                HeroPanel(
                  radius: const BorderRadius.vertical(
                    bottom: Radius.circular(28),
                  ),
                  padding: EdgeInsets.fromLTRB(8, topInset + 4, 20, 22),
                  child: Row(
                    children: [
                      IconButton(
                        tooltip: '뒤로',
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(
                          Icons.arrow_back_rounded,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '행사 관리',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              snapshot.hasData
                                  ? '행사 ${events.length}개 · 진행 중 $open개'
                                  : '행사를 골라 관리 비밀번호로 들어갑니다',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: Colors.white.withValues(alpha: 0.8),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const IconBadge(
                        icon: Icons.admin_panel_settings_outlined,
                        tone: AppTone.indigo,
                        filled: true,
                        size: 44,
                      ),
                    ],
                  ),
                ),
                Expanded(child: _body(snapshot, events)),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _body(
    AsyncSnapshot<List<EventSummary>> snapshot,
    List<EventSummary> events,
  ) {
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

    if (events.isEmpty) {
      return const EmptyState(
        icon: Icons.event_note_outlined,
        text: '아직 만들어진 행사가 없습니다.',
        detail: "아래 '새 행사' 를 눌러 첫 행사를 만드세요.",
      );
    }

    return ListView.separated(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        100 + MediaQuery.paddingOf(context).bottom,
      ),
      itemCount: events.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) => _EventTile(
        event: events[index],
        tone: AppToneColors.at(index),
        onTap: () => _signIn(events[index]),
      ),
    );
  }
}

class _EventTile extends StatelessWidget {
  const _EventTile({
    required this.event,
    required this.tone,
    required this.onTap,
  });

  final EventSummary event;
  final AppTone tone;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return CardBox(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(16, 16, 12, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _EventMark(date: event.date, tone: tone),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      keepWords(event.name),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColor.ink,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
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
                        if (event.date != null) ...[
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              event.date!,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColor.muted,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: Icon(Icons.chevron_right, color: AppColor.faint),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _Stat(
                icon: Icons.groups_outlined,
                value: event.candidates,
                label: '대상',
                tone: AppTone.sky,
              ),
              const SizedBox(width: 8),
              _Stat(
                icon: Icons.checklist_outlined,
                value: event.criteria,
                label: '항목',
                tone: AppTone.violet,
              ),
              const SizedBox(width: 8),
              _Stat(
                icon: Icons.badge_outlined,
                value: event.judges,
                label: '심사위원',
                tone: AppTone.teal,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 행사 카드 앞의 표식. 행사명 첫 글자("제", "2", "봄")는 아무 뜻이 없어
/// 날짜가 있으면 달력 한 장처럼 월·일을, 없으면 행사 아이콘을 둔다.
class _EventMark extends StatelessWidget {
  const _EventMark({required this.date, required this.tone});

  final String? date;
  final AppTone tone;

  static const _size = 46.0;

  @override
  Widget build(BuildContext context) {
    final day = date == null ? null : DateTime.tryParse(date!);

    if (day == null) {
      return IconBadge(
        icon: Icons.event_note_outlined,
        tone: tone,
        size: _size,
      );
    }

    return Semantics(
      label: '${day.month}월 ${day.day}일',
      child: ExcludeSemantics(
        child: Container(
          width: _size,
          height: _size,
          decoration: BoxDecoration(
            color: tone.soft,
            borderRadius: BorderRadius.circular(_size * 0.3),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${day.month}월',
                style: TextStyle(
                  fontSize: 10.5,
                  height: 1.1,
                  fontWeight: FontWeight.w700,
                  color: tone.ink,
                ),
              ),
              Text(
                '${day.day}',
                style: TextStyle(
                  fontSize: 19,
                  height: 1.1,
                  fontWeight: FontWeight.w800,
                  color: tone.ink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 대상 · 항목 · 심사위원 수를 색 상자 세 개로 나눈다.
/// 숫자와 이름을 한 줄에 두면 좁은 폭에서 "5 심사…" 처럼 잘려 위아래로 쌓는다.
class _Stat extends StatelessWidget {
  const _Stat({
    required this.icon,
    required this.value,
    required this.label,
    required this.tone,
  });

  final IconData icon;
  final int value;
  final String label;
  final AppTone tone;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: tone.soft,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: tone.strong),
                const SizedBox(width: 6),
                Text(
                  '$value',
                  style: TextStyle(
                    fontSize: 18,
                    height: 1.1,
                    fontWeight: FontWeight.w800,
                    color: tone.ink,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: tone.ink,
              ),
            ),
          ],
        ),
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
