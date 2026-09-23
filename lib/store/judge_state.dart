import '../models/payload.dart';
import 'queued_op.dart';

enum SessionStatus { loading, signedOut, ready }

class JudgeState {
  const JudgeState({
    this.status = SessionStatus.loading,
    this.payload,
    this.queue = const [],
    this.syncing = false,
    this.offline = false,
    this.serverError = false,
    this.lastSyncedAt,
    this.notice,
  });

  final SessionStatus status;
  final JudgePayload? payload;
  final List<QueuedOp> queue;
  final bool syncing;
  final bool offline;

  /// 연결은 되는데 서버가 받아 주지 않는 상태(5xx·429·예상 못 한 실패).
  /// 오프라인과 구분해야 심사위원에게 "보내는 중"이라고 잘못 안내하지 않는다.
  final bool serverError;

  /// 서버와 마지막으로 이야기가 통한 시각. 대기열이 비어 있어도 이 값이 오래됐으면
  /// 화면이 옛날 데이터라는 뜻이다 — 심사위원에게 그 사실을 숨기지 않는다.
  final DateTime? lastSyncedAt;

  final String? notice;

  int get pendingCount => queue.length;

  bool isPending(int candidateId) =>
      queue.any((op) => op.candidateId == candidateId);

  /// 보낼 것이 없고 연결도 멀쩡한 상태.
  bool get isSettled => queue.isEmpty && !offline && !serverError;

  JudgeState copyWith({
    SessionStatus? status,
    JudgePayload? payload,
    List<QueuedOp>? queue,
    bool? syncing,
    bool? offline,
    bool? serverError,
    DateTime? lastSyncedAt,
    String? notice,
    bool clearNotice = false,
    bool clearPayload = false,
  }) => JudgeState(
    status: status ?? this.status,
    payload: clearPayload ? null : (payload ?? this.payload),
    queue: queue ?? this.queue,
    syncing: syncing ?? this.syncing,
    offline: offline ?? this.offline,
    serverError: serverError ?? this.serverError,
    lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
    notice: clearNotice ? null : (notice ?? this.notice),
  );
}
