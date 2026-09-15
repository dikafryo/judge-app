class ReportSigner {
  const ReportSigner({
    required this.role,
    required this.dept,
    required this.position,
    required this.name,
  });

  final String role;
  final String dept;
  final String position;
  final String name;

  factory ReportSigner.fromJson(Map<String, dynamic> json) => ReportSigner(
    role: json['role'] as String? ?? '',
    dept: json['dept'] as String? ?? '',
    position: json['position'] as String? ?? '',
    name: json['name'] as String? ?? '',
  );

  Map<String, dynamic> toJson() => {
    'role': role,
    'dept': dept,
    'position': position,
    'name': name,
  };
}
