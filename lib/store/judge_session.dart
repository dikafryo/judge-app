import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api.dart';
import '../models/payload.dart';
import 'judge_state.dart';
import 'local_store.dart';
import 'queued_op.dart';

export 'judge_state.dart';

/// 심사위원 세션 전체 — 로그인 · 로컬 상태 · 전송 대기열을 한 곳에서 관리한다.
///
/// 핵심 규칙: **화면은 언제나 로컬 상태를 그린다.** 저장을 누르면 로컬을 먼저 고치고
/// 대기열에 넣은 뒤 전송을 시도한다. 서버가 멱등(같은 요청을 다시 보내도 결과가 같음)이라
/// 재전송이 안전하다는 것이 이 설계의 근거다.
class JudgeSession extends StateNotifier<JudgeState> {
  JudgeSession(
    this._api,
    this._store, {
    this.refreshInterval = const Duration(seconds: 5),
    this.maxRefreshInterval = const Duration(seconds: 60),
  }) : super(const JudgeState());

  final Api _api;
  final LocalStore _store;

  /// 서버가 잘 받아 줄 때의 확인 주기.
  final Duration refreshInterval;

  /// 연달아 실패할 때 늘려 갈 수 있는 최대 주기.
  final Duration maxRefreshInterval;

  String? _token;
  Timer? _refreshTimer;
  bool _polling = false;
  bool _refreshing = false;

  /// 연속 실패 횟수. 주기를 얼마나 늘릴지 정하는 데만 쓴다.
  int _failures = 0;

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

    _startPolling();
    unawaited(sync());
  }

  /// 접속 코드로 입장. 성공하면 payload 를 통째로 받아 기기에 저장한다.
  Future<void> signIn(String code) async {
    final session = await _api.post('/judge/session', {'code': code});
    final token = session['token'] as String;

    final payload = JudgePayload.fromJson(
      await _api.get('/judge/me', token: token),
    );

    _token = token;
    await _store.saveToken(token);
    await _store.savePayload(payload);
    await _store.saveQueue(const []);

    state = JudgeState(
      status: SessionStatus.ready,
      payload: payload,
      lastSyncedAt: DateTime.now(),
    );
    _startPolling();
  }

  /// 다음 확인까지 기다릴 시간.
  ///
  /// 실패가 이어지면 주기를 곱절로 늘린다. 비행기모드인 심사장에서 5초마다
  /// 소켓을 열면 배터리만 녹고 달라지는 것이 없다. 성공하면 곧바로 원래 주기로 돌아온다.
  Duration get _nextDelay {
    if (_failures == 0) return refreshInterval;

    final scaled = refreshInterval * (1 << _failures.clamp(1, 4));

    return scaled > maxRefreshInterval ? maxRefreshInterval : scaled;
  }

  /// 테스트에서 주기가 실제로 늘고 줄었는지 확인하는 창. 타이머를 실제로 기다리면
  /// 테스트가 1분씩 걸리므로, 계산 결과만 들여다본다.
  @visibleForTesting
  Duration get debugNextDelay => _nextDelay;

  void _startPolling() {
    if (_polling) return;
    _polling = true;
    _scheduleNext();
  }

  void _scheduleNext() {
    _refreshTimer?.cancel();

    if (!_polling || !mounted) return;

    _refreshTimer = Timer(_nextDelay, () async {
      await sync();
      _scheduleNext();
    });
  }

  void _stopPolling() {
    _polling = false;
    _refreshTimer?.cancel();
    _refreshTimer = null;
  }

  /// 사용자가 직접 "지금 전송"을 눌렀을 때. 늘어나 있던 주기를 되돌리고 즉시 시도한다.
  /// 자동 재시도를 기다리는 것 말고 할 수 있는 일을 남겨 두는 것이 요점이다.
  Future<void> syncNow() async {
    _failures = 0;
    await sync();
    _scheduleNext();
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

    await _enqueue(
      QueuedOp.scores(candidateId, {
        for (final entry in values.entries) entry.key.toString(): entry.value,
      }),
    );
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
  ///
  /// 보낼 것은 매번 [state] 에서 다시 꺼낸다 — 전송 중에 심사위원이 새로 저장한 건을
  /// 옛 목록으로 덮어써 버리면 그 입력이 조용히 사라진다.
  Future<void> flush() async {
    if (state.syncing || state.queue.isEmpty || _token == null) return;

    state = state.copyWith(syncing: true);

    try {
      while (state.queue.isNotEmpty) {
        final op = state.queue.first;

        try {
          await _api.put(op.path, op.body, token: _token);
          await _drop(op);
          state = state.copyWith(
            offline: false,
            serverError: false,
            lastSyncedAt: DateTime.now(),
          );
        } on ApiException catch (e) {
          if (e.isExpired) {
            await _expire();

            return;
          }

          if (e.isOffline) {
            state = state.copyWith(offline: true, serverError: false);
            break;
          }

          if (e.isLocked) {
            // 마감됐다. 남은 것을 계속 보내봐야 전부 같은 결과다.
            _markClosed();
            await _store.saveQueue(const []);
            state = state.copyWith(
              queue: const [],
              notice: e.message,
              offline: false,
              serverError: false,
            );
            break;
          }

          if (e.isPermanent) {
            // 서버가 거절한 내용이다. 다시 보내도 같으므로 빼고 사유를 알린다.
            await _drop(op);
            state = state.copyWith(notice: e.message);

            continue;
          }

          // 5xx · 429 — 서버 쪽 일시 장애. 남겨 두고 나중에 다시 보낸다.
          state = state.copyWith(serverError: true, offline: false);
          break;
        }
      }
    } catch (_) {
      // TLS 오류처럼 예상 못 한 실패. 여기서 syncing 을 되돌리지 않으면 다음 전송이
      // 전부 위 가드에 막혀 **대기열이 영영 비워지지 않는다.** 대기열은 그대로 둔다.
      state = state.copyWith(serverError: true);
    } finally {
      if (mounted) state = state.copyWith(syncing: false);
    }
  }

  /// 보낸 작업 하나를 대기열에서 뺀다.
  ///
  /// 키가 아니라 **그 객체 자체**를 뺀다. 전송 중에 같은 대상을 다시 저장하면
  /// [_enqueue] 가 같은 키로 새 객체를 넣어 두는데, 키로 지우면 그 새 입력까지 함께 사라진다.
  Future<void> _drop(QueuedOp op) async {
    final queue = state.queue.where((e) => !identical(e, op)).toList();

    await _store.saveQueue(queue);
    state = state.copyWith(queue: queue);
  }

  /// 전송을 끝낸 뒤 서버 상태로 맞춘다.
  ///
  /// 대기열이 남아 있으면 새로 받지 않는다 — 아직 못 보낸 점수를 서버의 옛 값으로
  /// 덮어써 버리면 그 입력이 사라진다.
  Future<void> sync() async {
    if (_refreshing) return;
    _refreshing = true;

    try {
      await flush();

      if (state.queue.isNotEmpty || _token == null) {
        // 아직 못 보낸 것이 남았다 = 이번 시도도 실패다. 여기서 세지 않으면
        // 대기열이 있는 동안에는 주기가 영영 5초에 머문다.
        if (state.offline || state.serverError) _failures += 1;

        return;
      }

      try {
        final payload = JudgePayload.fromJson(
          await _api.get('/judge/me', token: _token),
        );

        await _store.savePayload(payload);
        _failures = 0;
        state = state.copyWith(
          payload: payload,
          offline: false,
          serverError: false,
          lastSyncedAt: DateTime.now(),
        );
      } on ApiException catch (e) {
        if (e.isExpired) {
          await _expire();

          return;
        }

        _failures += 1;
        state = state.copyWith(offline: e.isOffline, serverError: !e.isOffline);
      }
    } finally {
      _refreshing = false;
    }
  }

  void _markClosed() {
    final payload = state.payload;

    if (payload == null) return;

    state = state.copyWith(
      payload: payload.copyWith(
        event: EventInfo(
          name: payload.event.name,
          isOpen: false,
          isBlind: payload.event.isBlind,
        ),
      ),
    );
  }

  /// 토큰이 죽었다. 행사를 마감하면 서버가 코드와 토큰을 함께 회수하므로,
  /// 사용자에게는 "없는 주소"가 아니라 **코드 만료**로 설명해야 원인을 안다.
  Future<void> _expire() async {
    _stopPolling();
    await _store.clear();
    _token = null;

    state = const JudgeState(
      status: SessionStatus.signedOut,
      notice: '접속 코드가 만료되었습니다. 심사가 마감되었거나 코드가 새로 발급된 경우입니다.',
    );
  }

  Future<void> signOut() async {
    final token = _token;

    _stopPolling();
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

  @override
  void dispose() {
    _stopPolling();
    super.dispose();
  }
}

final apiProvider = Provider<Api>((ref) => Api());

/// main() 에서 실제 LocalStore 로 덮어쓴다.
final localStoreProvider = Provider<LocalStore>(
  (ref) => throw UnimplementedError(),
);

final judgeSessionProvider = StateNotifierProvider<JudgeSession, JudgeState>(
  (ref) => JudgeSession(ref.watch(apiProvider), ref.watch(localStoreProvider)),
);
