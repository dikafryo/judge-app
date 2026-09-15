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
    this.notice,
  });

  final SessionStatus status;
  final JudgePayload? payload;
  final List<QueuedOp> queue;
  final bool syncing;
  final bool offline;
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
    String? notice,
    bool clearNotice = false,
    bool clearPayload = false,
  }) => JudgeState(
    status: status ?? this.status,
    payload: clearPayload ? null : (payload ?? this.payload),
    queue: queue ?? this.queue,
    syncing: syncing ?? this.syncing,
    offline: offline ?? this.offline,
    notice: clearNotice ? null : (notice ?? this.notice),
  );
}
