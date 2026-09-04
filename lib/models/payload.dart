/// 서버 /api/v1/judge/me 응답을 그대로 옮긴 모델.
///
/// 이 payload 하나가 오프라인 동작의 전부다. 입장할 때 통째로 받아 기기에 저장해 두면
/// 이후에는 연결이 없어도 목록·항목·이미 넣은 점수가 모두 보인다.
/// 서버 조립 규칙은 App\Services\JudgePayloadService 한 곳에 있다 — 여기서 가공하지 않는다.
library;

/// 점수 표기. 정수면 소수점을 붙이지 않고, 0.5 단위 입력만 한 자리로 보인다.
String formatScore(double value) => value == value.roundToDouble()
    ? value.toStringAsFixed(0)
    : value.toStringAsFixed(1);

class EventInfo {
  const EventInfo({
    required this.name,
    required this.isOpen,
    required this.isBlind,
  });

  final String name;
  final bool isOpen;
  final bool isBlind;

  factory EventInfo.fromJson(Map<String, dynamic> json) => EventInfo(
    name: json['name'] as String? ?? '',
    isOpen: json['is_open'] as bool? ?? true,
    isBlind: json['is_blind'] as bool? ?? false,
  );

  Map<String, dynamic> toJson() => {
    'name': name,
    'is_open': isOpen,
    'is_blind': isBlind,
  };
}

/// 실제로 점수를 넣는 말단 항목.
class CriterionItem {
  const CriterionItem({
    required this.id,
    required this.name,
    required this.maxScore,
    this.description,
  });

  final int id;
  final String name;
  final int maxScore;
  final String? description;

  factory CriterionItem.fromJson(Map<String, dynamic> json) => CriterionItem(
    id: json['id'] as int,
    name: json['name'] as String? ?? '',
    maxScore: (json['max_score'] as num?)?.toInt() ?? 0,
    description: json['description'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'max_score': maxScore,
    'description': description,
  };
}

/// 대분류. 자식이 없으면 자기 자신이 말단이 되며, 그 처리는 서버가 이미 끝내서 보낸다.
class CriterionGroup {
  const CriterionGroup({
    required this.id,
    required this.name,
    required this.maxScore,
    required this.hasChildren,
    required this.items,
  });

  final int id;
  final String name;
  final int maxScore;
  final bool hasChildren;
  final List<CriterionItem> items;

  factory CriterionGroup.fromJson(Map<String, dynamic> json) => CriterionGroup(
    id: json['id'] as int,
    name: json['name'] as String? ?? '',
    maxScore: (json['max_score'] as num?)?.toInt() ?? 0,
    hasChildren: json['has_children'] as bool? ?? false,
    items: (json['items'] as List? ?? [])
        .map((e) => CriterionItem.fromJson(e as Map<String, dynamic>))
        .toList(),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'max_score': maxScore,
    'has_children': hasChildren,
    'items': items.map((e) => e.toJson()).toList(),
  };
}

/// 블라인드 행사면 name·affiliation 이 **애초에 내려오지 않는다.**
/// 화면에서 감추는 것이 아니라 데이터가 없는 것이므로, null 을 그대로 존중한다.
class CandidateInfo {
  const CandidateInfo({
    required this.id,
    required this.number,
    this.name,
    this.affiliation,
  });

  final int id;
  final String number;
  final String? name;
  final String? affiliation;

  String get label =>
      name == null || name!.isEmpty ? '$number번' : '$number. ${name!}';

  factory CandidateInfo.fromJson(Map<String, dynamic> json) => CandidateInfo(
    id: json['id'] as int,
    number: json['number'] as String? ?? '',
    name: json['name'] as String?,
    affiliation: json['affiliation'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'number': number,
    'name': name,
    'affiliation': affiliation,
  };
}

class JudgePayload {
  JudgePayload({
    required this.judgeId,
    required this.judgeName,
    required this.event,
    required this.groups,
    required this.candidates,
    required this.scores,
    required this.hasSignature,
    required this.totalMax,
  });

  final int judgeId;
  final String judgeName;
  final EventInfo event;
  final List<CriterionGroup> groups;
  final List<CandidateInfo> candidates;

  /// { 평가대상 id: { 평가항목 id: 점수 } }
  final Map<int, Map<int, double>> scores;

  final bool hasSignature;
  final int totalMax;

  /// 점수를 넣어야 하는 말단 항목 전체. 완료 판정과 전송 본문이 모두 이 목록을 기준으로 한다.
  List<CriterionItem> get leafItems => [for (final g in groups) ...g.items];

  Map<int, double> scoresOf(int candidateId) => scores[candidateId] ?? const {};

  double totalOf(int candidateId) =>
      scoresOf(candidateId).values.fold(0, (sum, value) => sum + value);

  /// 말단 항목을 하나도 빠짐없이 채웠을 때만 완료다. 부분 입력은 미완료로 본다.
  bool isComplete(int candidateId) {
    final given = scoresOf(candidateId);

    return leafItems.isNotEmpty &&
        leafItems.every((item) => given.containsKey(item.id));
  }

  int get completedCount => candidates.where((c) => isComplete(c.id)).length;

  JudgePayload copyWith({
    Map<int, Map<int, double>>? scores,
    bool? hasSignature,
    EventInfo? event,
  }) => JudgePayload(
    judgeId: judgeId,
    judgeName: judgeName,
    event: event ?? this.event,
    groups: groups,
    candidates: candidates,
    scores: scores ?? this.scores,
    hasSignature: hasSignature ?? this.hasSignature,
    totalMax: totalMax,
  );

  factory JudgePayload.fromJson(Map<String, dynamic> json) {
    final judge = json['judge'] as Map<String, dynamic>? ?? const {};
    final rawScores = _scoresFromJson(json['scores']);

    return JudgePayload(
      judgeId: judge['id'] as int? ?? 0,
      judgeName: judge['name'] as String? ?? '',
      event: EventInfo.fromJson(
        json['event'] as Map<String, dynamic>? ?? const {},
      ),
      groups: (json['groups'] as List? ?? [])
          .map((e) => CriterionGroup.fromJson(e as Map<String, dynamic>))
          .toList(),
      candidates: (json['candidates'] as List? ?? [])
          .map((e) => CandidateInfo.fromJson(e as Map<String, dynamic>))
          .toList(),
      scores: {
        for (final entry in rawScores.entries)
          int.parse(entry.key): {
            for (final score in (entry.value as Map<String, dynamic>).entries)
              int.parse(score.key): (score.value as num).toDouble(),
          },
      },
      hasSignature: json['hasSignature'] as bool? ?? false,
      totalMax: (json['totalMax'] as num?)?.toInt() ?? 0,
    );
  }

  /// PHP 서버가 빈 연관 배열을 []로 직렬화하던 구버전 응답도 받아들인다.
  /// 점수가 하나라도 있으면 반드시 candidate_id를 키로 쓰는 객체여야 한다.
  static Map<String, dynamic> _scoresFromJson(Object? value) {
    if (value == null) return const {};
    if (value is Map<String, dynamic>) return value;
    if (value is List && value.isEmpty) return const {};

    throw const FormatException('scores는 객체여야 합니다.');
  }

  /// 기기 저장용. fromJson 과 같은 모양이라 그대로 되읽을 수 있다.
  Map<String, dynamic> toJson() => {
    'judge': {'id': judgeId, 'name': judgeName},
    'event': event.toJson(),
    'groups': groups.map((e) => e.toJson()).toList(),
    'candidates': candidates.map((e) => e.toJson()).toList(),
    'scores': {
      for (final entry in scores.entries)
        entry.key.toString(): {
          for (final score in entry.value.entries)
            score.key.toString(): score.value,
        },
    },
    'hasSignature': hasSignature,
    'totalMax': totalMax,
  };
}
