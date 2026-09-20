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
  final String? notice;

  int get pendingCount => queue.length;

  bool isPending(int candidateId) =>
      queue.any((op) => op.candidateId == candidateId);

  JudgeState copyWith({
    SessionStatus? status,
    JudgePayload? payload,
    List<QueuedOp>? queue,
    bool? syncing,
    bool? offline,
    bool? serverError,
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
    notice: clearNotice ? null : (notice ?? this.notice),
  );
}
