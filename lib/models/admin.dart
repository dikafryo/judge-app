/// 관리자 API 응답 모델.
///
/// 심사위원 payload 와 달리 **기기에 저장하지 않는다.** 집계는 언제나 최신이어야 하고,
/// 오래된 순위를 최신인 줄 알고 발표하는 사고가 연결 오류보다 훨씬 무섭다.
library;

class AdminEvent {
  const AdminEvent({
    required this.id,
    required this.name,
    required this.isOpen,
    required this.isBlind,
    required this.scoringMethod,
    required this.scoringNote,
    this.passCount,
  });

  final int id;
  final String name;
  final bool isOpen;
  final bool isBlind;

  /// 'all' = 전체 합계·평균, 'trimmed' = 대상별 최고·최저 총점 심사위원 제외
  final String scoringMethod;
  final String scoringNote;
  final int? passCount;

  factory AdminEvent.fromJson(Map<String, dynamic> json) => AdminEvent(
        id: json['id'] as int,
        name: json['name'] as String? ?? '',
        isOpen: json['is_open'] as bool? ?? true,
        isBlind: json['is_blind'] as bool? ?? false,
        scoringMethod: json['scoring_method'] as String? ?? 'all',
        scoringNote: json['scoring_note'] as String? ?? '',
        passCount: json['pass_count'] as int?,
      );
}

/// 목록 화면에서 고르는 행사 한 건.
class EventSummary {
  const EventSummary({
    required this.id,
    required this.name,
    required this.isOpen,
    required this.candidates,
    required this.criteria,
    required this.judges,
    this.date,
  });

  final int id;
  final String name;
  final bool isOpen;
  final int candidates;
  final int criteria;
  final int judges;
  final String? date;

  factory EventSummary.fromJson(Map<String, dynamic> json) => EventSummary(
        id: json['id'] as int,
        name: json['name'] as String? ?? '',
        isOpen: json['is_open'] as bool? ?? true,
        candidates: json['candidates_count'] as int? ?? 0,
        criteria: json['criteria_count'] as int? ?? 0,
        judges: json['judges_count'] as int? ?? 0,
        date: json['event_date'] as String?,
      );
}

class SetupCriterion {
  const SetupCriterion({
    required this.id,
    required this.name,
    required this.maxScore,
    required this.hasScores,
    this.parentId,
    this.description,
  });

  final int id;
  final String name;
  final int maxScore;

  /// 이미 채점된 항목은 구조를 바꿀 수 없다. 화면에서 미리 알려 준다.
  final bool hasScores;
  final int? parentId;
  final String? description;

  factory SetupCriterion.fromJson(Map<String, dynamic> json) => SetupCriterion(
        id: json['id'] as int,
        name: json['name'] as String? ?? '',
        maxScore: (json['max_score'] as num?)?.toInt() ?? 0,
        hasScores: json['has_scores'] as bool? ?? false,
        parentId: json['parent_id'] as int?,
        description: json['description'] as String?,
      );
}

class SetupCandidate {
  const SetupCandidate({required this.id, required this.name, this.affiliation});

  final int id;
  final String name;
  final String? affiliation;

  factory SetupCandidate.fromJson(Map<String, dynamic> json) => SetupCandidate(
        id: json['id'] as int,
        name: json['name'] as String? ?? '',
        affiliation: json['affiliation'] as String?,
      );
}

class SetupJudge {
  const SetupJudge({required this.id, required this.name, this.code, this.entryUrl, this.signedAt});

  final int id;
  final String name;

  /// 마감하면 코드가 회수되어 null 이 된다.
  final String? code;
  final String? entryUrl;
  final String? signedAt;

  factory SetupJudge.fromJson(Map<String, dynamic> json) => SetupJudge(
        id: json['id'] as int,
        name: json['name'] as String? ?? '',
        code: json['code'] as String?,
        entryUrl: json['entry_url'] as String?,
        signedAt: json['signed_at'] as String?,
      );
}

class SetupData {
  const SetupData({
    required this.criteria,
    required this.candidates,
    required this.judges,
    required this.totalMax,
  });

  final List<SetupCriterion> criteria;
  final List<SetupCandidate> candidates;
  final List<SetupJudge> judges;
  final int totalMax;

  List<SetupCriterion> get topLevel => criteria.where((c) => c.parentId == null).toList();

  List<SetupCriterion> childrenOf(int parentId) =>
      criteria.where((c) => c.parentId == parentId).toList();

  factory SetupData.fromJson(Map<String, dynamic> json) => SetupData(
        criteria: (json['criteria'] as List? ?? [])
            .map((e) => SetupCriterion.fromJson(e as Map<String, dynamic>))
            .toList(),
        candidates: (json['candidates'] as List? ?? [])
            .map((e) => SetupCandidate.fromJson(e as Map<String, dynamic>))
            .toList(),
        judges: (json['judges'] as List? ?? [])
            .map((e) => SetupJudge.fromJson(e as Map<String, dynamic>))
            .toList(),
        totalMax: (json['total_max'] as num?)?.toInt() ?? 0,
      );
}

/// 집계 한 줄. 계산은 전부 서버(DashboardController::aggregate)가 한다 —
/// 앱이 다시 계산하면 웹 대시보드와 숫자가 어긋날 수 있다.
class DashboardRow {
  const DashboardRow({
    required this.candidateId,
    required this.number,
    required this.judgedCount,
    this.name,
    this.affiliation,
    this.sum,
    this.avg,
    this.rank,
    this.pass,
  });

  final int candidateId;
  final String number;
  final int judgedCount;
  final String? name;
  final String? affiliation;
  final double? sum;
  final double? avg;
  final int? rank;

  /// 'pass' = 확정 선정, 'tie' = 마지막 선정 순위 동점(해소 필요)
  final String? pass;

  factory DashboardRow.fromJson(Map<String, dynamic> json) => DashboardRow(
        candidateId: json['candidate_id'] as int,
        number: json['number']?.toString() ?? '',
        judgedCount: json['judged_count'] as int? ?? 0,
        name: json['name'] as String?,
        affiliation: json['affiliation'] as String?,
        sum: (json['sum'] as num?)?.toDouble(),
        avg: (json['avg'] as num?)?.toDouble(),
        rank: json['rank'] as int?,
        pass: json['pass'] as String?,
      );
}

class JudgeProgress {
  const JudgeProgress({
    required this.name,
    required this.done,
    required this.total,
    required this.signed,
    this.code,
  });

  final String name;
  final int done;
  final int total;
  final bool signed;
  final String? code;

  factory JudgeProgress.fromJson(Map<String, dynamic> json) => JudgeProgress(
        name: json['name'] as String? ?? '',
        done: json['done'] as int? ?? 0,
        total: json['total'] as int? ?? 0,
        signed: json['signed'] as bool? ?? false,
        code: json['code'] as String?,
      );
}

class Dashboard {
  const Dashboard({
    required this.eventName,
    required this.isOpen,
    required this.totalMax,
    required this.scoringNote,
    required this.rows,
    required this.judges,
    required this.generatedAt,
    this.passCount,
    this.passTie,
  });

  final String eventName;
  final bool isOpen;
  final int totalMax;
  final String scoringNote;
  final List<DashboardRow> rows;
  final List<JudgeProgress> judges;
  final String generatedAt;
  final int? passCount;

  /// 마지막 선정 순위에 동점이 있어 선정자 수를 넘긴 상태. 발표 전에 반드시 해소해야 한다.
  final Map<String, dynamic>? passTie;

  factory Dashboard.fromJson(Map<String, dynamic> json) {
    final event = json['event'] as Map<String, dynamic>? ?? const {};

    return Dashboard(
      eventName: event['name'] as String? ?? '',
      isOpen: event['is_open'] as bool? ?? true,
      totalMax: (event['total_max'] as num?)?.toInt() ?? 0,
      scoringNote: event['scoring_note'] as String? ?? '',
      passCount: event['pass_count'] as int?,
      passTie: json['pass_tie'] as Map<String, dynamic>?,
      rows: (json['rows'] as List? ?? [])
          .map((e) => DashboardRow.fromJson(e as Map<String, dynamic>))
          .toList(),
      judges: (json['judges'] as List? ?? [])
          .map((e) => JudgeProgress.fromJson(e as Map<String, dynamic>))
          .toList(),
      generatedAt: json['generated_at'] as String? ?? '',
    );
  }
}
