/// 아직 서버에 보내지 못한 작업 하나.
///
/// 두 API 모두 **전체 교체(PUT)** 라서, 같은 대상에 대한 새 작업은 이전 것을 덮어써도 된다.
/// 그래서 [key] 가 같으면 대기열에서 교체한다 — 오프라인에서 한 대상을 열 번 고쳐도
/// 대기열은 한 건으로 유지되고, 마지막 상태만 서버로 간다.
class QueuedOp {
  const QueuedOp({
    required this.key,
    required this.path,
    required this.body,
    this.candidateId,
  });

  final String key;
  final String path;
  final Map<String, dynamic> body;
  final int? candidateId;

  factory QueuedOp.scores(int candidateId, Map<String, dynamic> scores) => QueuedOp(
        key: 'scores:$candidateId',
        path: '/judge/candidates/$candidateId/scores',
        body: {'scores': scores},
        candidateId: candidateId,
      );

  factory QueuedOp.signature(String dataUrl) => QueuedOp(
        key: 'signature',
        path: '/judge/signature',
        body: {'signature': dataUrl},
      );

  factory QueuedOp.fromJson(Map<String, dynamic> json) => QueuedOp(
        key: json['key'] as String,
        path: json['path'] as String,
        body: json['body'] as Map<String, dynamic>,
        candidateId: json['candidate_id'] as int?,
      );

  Map<String, dynamic> toJson() =>
      {'key': key, 'path': path, 'body': body, 'candidate_id': candidateId};
}
