import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api.dart';
import '../models/payload.dart';
import 'local_store.dart';
import 'queued_op.dart';

enum SessionStatus { loading, signedOut, ready }

class JudgeState {
  const JudgeState({
    this.status = SessionStatus.loading,
    this.payload,
    this.queue = const [],
    this.syncing = false,
    this.offline = false,
    this.notice,
  });

  final SessionStatus status;
  final JudgePayload? payload;
  final List<QueuedOp> queue;
  final bool syncing;

  /// 마지막 전송이 연결 문제로 실패했다. 화면 상단 안내에만 쓴다.
  final bool offline;

  /// 한 번 보여주고 지우는 안내(스낵바).
  final String? notice;

  int get pendingCount => queue.length;

  bool isPending(int candidateId) => queue.any((op) => op.candidateId == candidateId);

  JudgeState copyWith({
    SessionStatus? status,
    JudgePayload? payload,
    List<QueuedOp>? queue,
    bool? syncing,
    bool? offline,
    String? notice,
    bool clearNotice = false,
    bool clearPayload = false,
  }) =>
      JudgeState(
        status: status ?? this.status,
        payload: clearPayload ? null : (payload ?? this.payload),
        queue: queue ?? this.queue,
        syncing: syncing ?? this.syncing,
        offline: offline ?? this.offline,
        notice: clearNotice ? null : (notice ?? this.notice),
      );
}

/// 심사위원 세션 전체 — 로그인 · 로컬 상태 · 전송 대기열을 한 곳에서 관리한다.
///
/// 핵심 규칙: **화면은 언제나 로컬 상태를 그린다.** 저장을 누르면 로컬을 먼저 고치고
/// 대기열에 넣은 뒤 전송을 시도한다. 서버가 멱등(같은 요청을 다시 보내도 결과가 같음)이라
/// 재전송이 안전하다는 것이 이 설계의 근거다.
class JudgeSession extends StateNotifier<JudgeState> {
  JudgeSession(this._api, this._store) : super(const JudgeState());

  final Api _api;
  final LocalStore _store;

  String? _token;

  /// 앱을 켤 때 기기에 저장된 세션을 되살린다. 여기서 네트워크를 기다리지 않는 것이 요점 —
  /// 연결이 없어도 즉시 심사 화면이 뜬다.
  Future<void> restore() async {
    _token = _store.token;
    final payload = _store.payload;

    if (_token == null || payload == null) {
      state = state.copyWith(status: SessionStatus.signedOut);

      return;
    }

    state = state.copyWith(
      status: SessionStatus.ready,
      payload: payload,
      queue: _store.queue,
    );

    unawaited(sync());
  }

  /// 접속 코드로 입장. 성공하면 payload 를 통째로 받아 기기에 저장한다.
  Future<void> signIn(String code) async {
    final session = await _api.post('/judge/session', {'code': code});
    final token = session['token'] as String;

    final payload = JudgePayload.fromJson(await _api.get('/judge/me', token: token));

    _token = token;
    await _store.saveToken(token);
    await _store.savePayload(payload);
    await _store.saveQueue(const []);

    state = JudgeState(status: SessionStatus.ready, payload: payload);
  }

  /// 점수 저장. 말단 항목 전체를 보낸다 — 부분 전송을 하지 않아야 'null 은 삭제' 규칙이
  /// 대기열 재전송과 엉키지 않는다.
  Future<void> saveScores(int candidateId, Map<int, double?> values) async {
    final payload = state.payload;

    if (payload == null) return;

    final next = Map<int, Map<int, double>>.from(payload.scores);
    next[candidateId] = {
      for (final entry in values.entries)
        if (entry.value != null) entry.key: entry.value!,
    };

    final updated = payload.copyWith(scores: next);
    await _store.savePayload(updated);

    state = state.copyWith(payload: updated);

    await _enqueue(QueuedOp.scores(candidateId, {
      for (final entry in values.entries) entry.key.toString(): entry.value,
    }));
  }

  Future<void> saveSignature(String dataUrl) async {
    final payload = state.payload;

    if (payload != null) {
      final updated = payload.copyWith(hasSignature: true);
      await _store.savePayload(updated);
      state = state.copyWith(payload: updated);
    }

    await _enqueue(QueuedOp.signature(dataUrl));
  }

  Future<void> _enqueue(QueuedOp op) async {
    // 같은 대상의 이전 작업은 버린다. 두 API 모두 전체 교체라 마지막 것만 보내면 된다.
    final queue = [...state.queue.where((e) => e.key != op.key), op];

    await _store.saveQueue(queue);
    state = state.copyWith(queue: queue);

    await flush();
  }

  /// 대기열을 순서대로 비운다. 연결이 없으면 그대로 두고 다음 기회를 기다린다.
  Future<void> flush() async {
    if (state.syncing || state.queue.isEmpty || _token == null) return;

    state = state.copyWith(syncing: true);

    final remaining = [...state.queue];
    var offline = false;
    String? notice;

    while (remaining.isNotEmpty) {
      try {
        await _api.put(remaining.first.path, remaining.first.body, token: _token);
        remaining.removeAt(0);
      } on ApiException catch (e) {
        if (e.isExpired) {
          await _expire();

          return;
        }

        if (e.isOffline) {
          offline = true;
          break;
        }

        if (e.isLocked) {
          // 마감됐다. 남은 것을 계속 보내봐야 전부 같은 결과다.
          _markClosed();
          notice = e.message;
          remaining.clear();
          break;
        }

        if (e.isPermanent) {
          // 서버가 거절한 내용이다. 다시 보내도 같으므로 빼고 사유를 알린다.
          remaining.removeAt(0);
          notice = e.message;

          continue;
        }

        // 5xx — 서버 쪽 일시 장애. 남겨 두고 나중에 다시 보낸다.
        break;
      }
    }

    await _store.saveQueue(remaining);

    state = state.copyWith(queue: remaining, syncing: false, offline: offline, notice: notice);
  }

  /// 전송을 끝낸 뒤 서버 상태로 맞춘다.
  ///
  /// 대기열이 남아 있으면 새로 받지 않는다 — 아직 못 보낸 점수를 서버의 옛 값으로
  /// 덮어써 버리면 그 입력이 사라진다.
  Future<void> sync() async {
    await flush();

    if (state.queue.isNotEmpty || _token == null) return;

    try {
      final payload = JudgePayload.fromJson(await _api.get('/judge/me', token: _token));

      await _store.savePayload(payload);
      state = state.copyWith(payload: payload, offline: false);
    } on ApiException catch (e) {
      if (e.isExpired) {
        await _expire();

        return;
      }

      state = state.copyWith(offline: e.isOffline);
    }
  }

  void _markClosed() {
    final payload = state.payload;

    if (payload == null) return;

    state = state.copyWith(
      payload: payload.copyWith(
        event: EventInfo(name: payload.event.name, isOpen: false, isBlind: payload.event.isBlind),
      ),
    );
  }

  /// 토큰이 죽었다. 행사를 마감하면 서버가 코드와 토큰을 함께 회수하므로,
  /// 사용자에게는 "없는 주소"가 아니라 **코드 만료**로 설명해야 원인을 안다.
  Future<void> _expire() async {
    await _store.clear();
    _token = null;

    state = const JudgeState(
      status: SessionStatus.signedOut,
      notice: '접속 코드가 만료되었습니다. 심사가 마감되었거나 코드가 새로 발급된 경우입니다.',
    );
  }

  Future<void> signOut() async {
    final token = _token;

    _token = null;
    await _store.clear();
    state = const JudgeState(status: SessionStatus.signedOut);

    if (token == null) return;

    try {
      await _api.delete('/session', token: token);
    } on ApiException {
      // 서버 정리는 못 했어도 기기에서는 이미 지웠다. 다음 마감 때 함께 폐기된다.
    }
  }

  void clearNotice() => state = state.copyWith(clearNotice: true);
}

final apiProvider = Provider<Api>((ref) => Api());

/// main() 에서 실제 LocalStore 로 덮어쓴다.
final localStoreProvider = Provider<LocalStore>((ref) => throw UnimplementedError());

final judgeSessionProvider = StateNotifierProvider<JudgeSession, JudgeState>(
  (ref) => JudgeSession(ref.watch(apiProvider), ref.watch(localStoreProvider)),
);
