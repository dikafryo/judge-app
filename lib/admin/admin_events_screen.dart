import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api.dart';
import '../core/brand.dart';
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

    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AdminHomeScreen()),
    );

    // 돌아왔으면 로그아웃된 것이다. 목록의 진행 상태가 바뀌었을 수 있어 다시 읽는다.
    if (mounted) setState(_load);
  }

  Future<void> _signIn(EventSummary event) async {
    final password = await _askPassword(event.name);

    if (password == null || !mounted) return;

    await _run(() async {
      final admin = await AdminApi.signIn(ref.read(adminBaseApiProvider), event.id, password);

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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  Future<String?> _askPassword(String eventName) {
    final controller = TextEditingController();

    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(eventName),
        content: TextField(
          controller: controller,
          autofocus: true,
          obscureText: true,
          decoration: const InputDecoration(labelText: '관리 비밀번호'),
          onSubmitted: (value) => Navigator.pop(context, value),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('들어가기'),
          ),
        ],
      ),
    );
  }

  Future<(String, String)?> _askNewEvent() {
    final name = TextEditingController();
    final password = TextEditingController();

    return showDialog<(String, String)>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('새 행사 만들기'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              autofocus: true,
              decoration: const InputDecoration(labelText: '행사명'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: password,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: '관리 비밀번호',
                helperText: '이 비밀번호가 유일한 열쇠입니다. 잊으면 되찾을 수 없습니다.',
                helperMaxLines: 2,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
          TextButton(
            onPressed: () {
              if (name.text.trim().isEmpty || password.text.length < 4) return;

              Navigator.pop(context, (name.text.trim(), password.text));
            },
            child: const Text('만들기'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('행사 관리')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _create,
        icon: const Icon(Icons.add),
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
            return const Center(
              child: Text('아직 만들어진 행사가 없습니다.', style: TextStyle(color: Color(0xFF94A3B8))),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            itemCount: events.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
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

class _EventTile extends StatelessWidget {
  const _EventTile({required this.event, required this.onTap});

  final EventSummary event;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      event.name,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                  if (!event.isOpen)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        '마감',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF92400E)),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '대상 ${event.candidates} · 항목 ${event.criteria} · 심사위원 ${event.judges}'
                '${event.date != null ? ' · ${event.date}' : ''}',
                style: const TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
