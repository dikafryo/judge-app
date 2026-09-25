import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 앱 전체의 디자인 언어.
///
/// 지금까지 화면마다 색을 직접 적고 다이얼로그는 기본 [AlertDialog] 를 그대로 썼다.
/// 그래서 같은 뜻의 회색이 파일마다 다른 값이었고, 입력창은 플랫폼 기본 모습이라
/// 나머지 화면과 따로 놀았다. 색·간격·모서리·버튼 높이를 여기 한 곳에 모은다.
///
/// 웹(judge.sw4u.kr)이 쓰는 Tailwind slate 계열과 같은 값을 쓴다 — 같은 시스템의
/// 웹과 앱을 오가는 사용자가 다른 제품처럼 느끼지 않게 하려는 것이다.
class AppColor {
  const AppColor._();

  static const canvas = Color(0xFFF1F5F9); // slate-100 — 화면 바탕
  static const surface = Color(0xFFFFFFFF); // 카드·다이얼로그
  static const field = Color(0xFFF8FAFC); // slate-50 — 입력칸 안쪽
  static const line = Color(0xFFE2E8F0); // slate-200 — 경계선

  static const ink = Color(0xFF0F172A); // slate-900 — 본문
  static const muted = Color(0xFF64748B); // slate-500 — 보조 설명
  // slate-400. 대비가 2.6:1 밖에 안 나와 **읽어야 하는 글씨에는 쓰지 않는다.**
  // 입력 전 placeholder, 화살표 같은 장식 아이콘 전용이다.
  static const faint = Color(0xFF94A3B8);

  static const accent = Color(0xFF4F46E5); // indigo-600 — 앱 아이콘의 강조 칸과 같은 색
  static const accentSoft = Color(0xFFEEF2FF); // indigo-50

  static const success = Color(0xFF15803D);
  static const successSoft = Color(0xFFDCFCE7);
  static const warn = Color(0xFF92400E);
  static const warnSoft = Color(0xFFFEF3C7);
  static const danger = Color(0xFFDC2626);
  static const dangerSoft = Color(0xFFFEE2E2);
  // dangerSoft 배경 위에 얹는 글씨. danger 를 그대로 쓰면 대비가 4.2:1 로 모자란다.
  static const dangerInk = Color(0xFFB91C1C);
}

/// 모서리 값도 흩어지지 않게 이름을 준다.
class AppRadius {
  const AppRadius._();

  static const card = 16.0;
  static const dialog = 22.0;
  static const field = 12.0;
  static const button = 12.0;
  static const pill = 999.0;
}

/// 카드가 바탕에서 살짝 떠 보이게 하는 그림자. 테두리 선 대신 쓴다 —
/// 선으로 구분한 흰 카드는 표처럼 보이고, 그림자로 띄운 카드는 물건처럼 보인다.
class AppShadow {
  const AppShadow._();

  static const card = [
    BoxShadow(color: Color(0x0F0F172A), blurRadius: 18, offset: Offset(0, 6)),
    BoxShadow(color: Color(0x080F172A), blurRadius: 2, offset: Offset(0, 1)),
  ];

  /// 색 있는 카드(강조 카드·머리 판)는 제 색의 그림자를 드리운다.
  static List<BoxShadow> tinted(Color color) => [
    BoxShadow(
      color: color.withValues(alpha: 0.28),
      blurRadius: 22,
      offset: const Offset(0, 8),
    ),
  ];
}

/// 화면 머리 판·강조 카드의 그라데이션. indigo → violet 한 가지만 쓴다.
class AppGradient {
  const AppGradient._();

  static const hero = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
  );

  static const success = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF059669), Color(0xFF0D9488)],
  );
}

/// 색조. 통계 타일·평가 항목 묶음·행사 아바타처럼 **여럿을 구분**해야 하는 자리에
/// 번갈아 쓴다. 뜻이 정해진 색(성공·경고·위험)은 [AppColor] 에 있다.
enum AppTone { indigo, violet, sky, teal, amber, rose }

extension AppToneColors on AppTone {
  /// 진한 색 — 아이콘·숫자·막대.
  Color get strong => switch (this) {
    AppTone.indigo => const Color(0xFF4F46E5),
    AppTone.violet => const Color(0xFF7C3AED),
    AppTone.sky => const Color(0xFF0284C7),
    AppTone.teal => const Color(0xFF0D9488),
    AppTone.amber => const Color(0xFFD97706),
    AppTone.rose => const Color(0xFFE11D48),
  };

  /// 연한 바탕 — 타일·배지 배경.
  Color get soft => switch (this) {
    AppTone.indigo => const Color(0xFFEEF2FF),
    AppTone.violet => const Color(0xFFF5F3FF),
    AppTone.sky => const Color(0xFFE0F2FE),
    AppTone.teal => const Color(0xFFCCFBF1),
    AppTone.amber => const Color(0xFFFEF3C7),
    AppTone.rose => const Color(0xFFFFE4E6),
  };

  /// 연한 바탕 위에 얹는 글씨. [strong] 보다 한 단계 어두워 4.5:1 이 나온다.
  Color get ink => switch (this) {
    AppTone.indigo => const Color(0xFF3730A3),
    AppTone.violet => const Color(0xFF5B21B6),
    AppTone.sky => const Color(0xFF075985),
    AppTone.teal => const Color(0xFF115E59),
    AppTone.amber => const Color(0xFF92400E),
    AppTone.rose => const Color(0xFF9F1239),
  };

  /// n 번째 것에 줄 색조. 목록이 여섯을 넘으면 처음부터 다시 돈다.
  static AppTone at(int index) => AppTone.values[index % AppTone.values.length];
}

/// 시스템 바(상태바·내비게이션바)는 늘 투명하다. Android 15 부터 앱이 그 뒤까지
/// 그리므로(edge-to-edge) 색을 칠하면 오히려 띠가 생긴다. 아이콘 색만 배경에 맞춘다.
const kLightSystemBars = SystemUiOverlayStyle(
  statusBarColor: Colors.transparent,
  statusBarIconBrightness: Brightness.dark,
  statusBarBrightness: Brightness.light,
  systemNavigationBarColor: Colors.transparent,
  systemNavigationBarDividerColor: Colors.transparent,
  systemNavigationBarIconBrightness: Brightness.dark,
  systemNavigationBarContrastEnforced: false,
);

/// 그라데이션 머리 판 위처럼 배경이 어두운 화면용.
const kDarkSystemBars = SystemUiOverlayStyle(
  statusBarColor: Colors.transparent,
  statusBarIconBrightness: Brightness.light,
  statusBarBrightness: Brightness.dark,
  systemNavigationBarColor: Colors.transparent,
  systemNavigationBarDividerColor: Colors.transparent,
  systemNavigationBarIconBrightness: Brightness.dark,
  systemNavigationBarContrastEnforced: false,
);

ThemeData buildAppTheme() {
  final scheme =
      ColorScheme.fromSeed(
        seedColor: AppColor.accent,
        surface: AppColor.surface,
      ).copyWith(
        primary: AppColor.accent,
        error: AppColor.danger,
        onSurface: AppColor.ink,
      );

  OutlineInputBorder border(Color color, double width) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(AppRadius.field),
    borderSide: BorderSide(color: color, width: width),
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColor.canvas,

    appBarTheme: const AppBarTheme(
      backgroundColor: AppColor.surface,
      surfaceTintColor: AppColor.surface,
      foregroundColor: AppColor.ink,
      elevation: 0,
      scrolledUnderElevation: 0.5,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: AppColor.ink,
        fontSize: 17,
        fontWeight: FontWeight.w700,
      ),
      // 밝은 앱바 위의 상태바 아이콘은 어두워야 읽힌다
      systemOverlayStyle: kLightSystemBars,
    ),

    textTheme: const TextTheme(
      titleLarge: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: AppColor.ink,
        height: 1.3,
      ),
      titleMedium: TextStyle(
        fontSize: 15.5,
        fontWeight: FontWeight.w700,
        color: AppColor.ink,
      ),
      bodyMedium: TextStyle(fontSize: 14.5, color: AppColor.ink, height: 1.5),
      bodySmall: TextStyle(fontSize: 12.5, color: AppColor.muted, height: 1.5),
      labelLarge: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColor.field,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      hintStyle: const TextStyle(color: AppColor.faint, fontSize: 14.5),
      helperStyle: const TextStyle(
        color: AppColor.muted,
        fontSize: 12,
        height: 1.45,
      ),
      errorStyle: const TextStyle(color: AppColor.danger, fontSize: 12),
      suffixStyle: const TextStyle(color: AppColor.muted, fontSize: 14),
      border: border(AppColor.line, 1),
      enabledBorder: border(AppColor.line, 1),
      focusedBorder: border(AppColor.accent, 1.6),
      errorBorder: border(AppColor.danger, 1),
      focusedErrorBorder: border(AppColor.danger, 1.6),
    ),

    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 48),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.button),
        ),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 48),
        foregroundColor: AppColor.muted,
        side: const BorderSide(color: AppColor.line),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.button),
        ),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColor.accent,
        minimumSize: const Size(0, 48),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.button),
        ),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
      ),
    ),

    dialogTheme: DialogThemeData(
      backgroundColor: AppColor.surface,
      surfaceTintColor: AppColor.surface,
      elevation: 8,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.dialog),
      ),
    ),

    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColor.surface,
      surfaceTintColor: AppColor.surface,
      indicatorColor: AppColor.accentSoft,
      height: 64,
      elevation: 3,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          color: states.contains(WidgetState.selected)
              ? AppColor.accent
              : AppColor.muted,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          size: 23,
          color: states.contains(WidgetState.selected)
              ? AppColor.accent
              : AppColor.muted,
        ),
      ),
    ),

    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: AppColor.accent,
      foregroundColor: Colors.white,
      elevation: 3,
      extendedTextStyle: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w700,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),

    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColor.ink,
      contentTextStyle: const TextStyle(fontSize: 14, color: Colors.white),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      insetPadding: const EdgeInsets.all(16),
    ),

    dividerTheme: const DividerThemeData(
      color: AppColor.line,
      thickness: 1,
      space: 1,
    ),
    listTileTheme: const ListTileThemeData(
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      titleTextStyle: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: AppColor.ink,
      ),
      subtitleTextStyle: TextStyle(fontSize: 12.5, color: AppColor.muted),
      iconColor: AppColor.muted,
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColor.accent,
    ),
  );
}

/// 다이얼로그의 성격. 색과 아이콘 배경만 달라진다.
enum DialogTone { neutral, danger }

/// 앱의 모든 입력·확인 창이 쓰는 껍데기.
///
/// 기본 [AlertDialog] 은 제목이 작고 버튼이 우하단에 작게 붙어서, 한 손으로 드는
/// 폰·태블릿에서 누르기 어려웠다. 여기서는 아이콘·제목·설명을 위에 쌓고 버튼을
/// 아래 가로로 꽉 채운다. 취소는 왼쪽, 실행은 오른쪽으로 자리를 고정해 두어야
/// 급하게 누를 때 실수하지 않는다.
class AppDialog extends StatelessWidget {
  const AppDialog({
    super.key,
    required this.title,
    required this.icon,
    required this.confirmLabel,
    required this.onConfirm,
    this.subtitle,
    this.child,
    this.tone = DialogTone.neutral,
    this.cancelLabel = '취소',
  });

  final String title;
  final String? subtitle;
  final IconData icon;
  final Widget? child;
  final DialogTone tone;
  final String cancelLabel;
  final String confirmLabel;

  /// **직접 [Navigator.pop] 을 불러야 한다.** 창은 스스로 닫히지 않는다 —
  /// 저장에 실패했을 때 열어 둔 채로 이유를 보여 줄 수 있어야 하기 때문이다.
  ///
  /// null 이면 실행 버튼이 흐려진다 — 눌러 놓고 아무 일도 안 일어나는 것보다 낫다.
  final VoidCallback? onConfirm;

  Color get _accent =>
      tone == DialogTone.danger ? AppColor.danger : AppColor.accent;
  Color get _accentSoft =>
      tone == DialogTone.danger ? AppColor.dangerSoft : AppColor.accentSoft;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 내용만 스크롤하고 버튼은 아래에 붙여 둔다. 결재란처럼 칸이 많은 창에서
            // 버튼이 스크롤에 묻히면, 정작 눌러야 할 것을 찾아 끝까지 밀어야 한다.
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 아이콘과 제목은 한 줄이다. 아이콘이 제 줄을 차지하면 머리에만
                    // 두 줄이 나가는데, 폰 세로 화면에서 그만큼 입력칸이 밀려난다.
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: _accentSoft,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(icon, size: 19, color: _accent),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            title,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                      ],
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        subtitle!,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                    if (child != null) ...[const SizedBox(height: 16), child!],
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(cancelLabel),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(backgroundColor: _accent),
                      onPressed: onConfirm,
                      child: Text(confirmLabel),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 라벨을 칸 위에 얹은 입력칸.
///
/// [InputDecoration.labelText] 는 입력하면 작아져 위로 올라가는데, 한 창에
/// 칸이 여럿이면 라벨 위치가 제각각이 되어 훑어보기 어렵다. 라벨을 밖에 고정한다.
class AppField extends StatelessWidget {
  const AppField({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    this.helper,
    this.suffix,
    this.obscure = false,
    this.autofocus = false,
    this.maxLines = 1,
    this.keyboardType,
    this.inputFormatters,
    this.onChanged,
    this.onSubmitted,
    this.errorText,
  });

  final String label;
  final TextEditingController controller;
  final String? hint;
  final String? helper;
  final String? suffix;
  final bool obscure;
  final bool autofocus;
  final int maxLines;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 라벨을 칸 밖에 직접 그리므로 스크린리더는 이것을 칸 이름으로 읽지 못한다.
        // 글자는 화면에만 남기고, 이름은 아래 Semantics 로 칸에 붙인다.
        ExcludeSemantics(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: AppColor.muted,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Semantics(
          label: label,
          child: TextField(
            controller: controller,
            autofocus: autofocus,
            obscureText: obscure,
            maxLines: obscure ? 1 : maxLines,
            keyboardType: keyboardType,
            inputFormatters: inputFormatters,
            onChanged: onChanged,
            onSubmitted: onSubmitted,
            style: const TextStyle(fontSize: 15, color: AppColor.ink),
            decoration: InputDecoration(
              hintText: hint,
              helperText: helper,
              helperMaxLines: 5,
              errorText: errorText,
              suffixText: suffix,
            ),
          ),
        ),
      ],
    );
  }
}

/// 화면 안의 흰 카드 한 장. 제목이 있으면 위에 작은 머리글을 단다.
class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.child,
    this.title,
    this.padding = const EdgeInsets.all(16),
    this.margin = EdgeInsets.zero,
    this.color = AppColor.surface,
  });

  final Widget child;
  final String? title;
  final EdgeInsets padding;
  final EdgeInsets margin;
  final Color color;

  static const sectionTitleStyle = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w800,
    color: AppColor.muted,
    letterSpacing: 0.4,
  );

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: margin,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
              child: Text(title!, style: sectionTitleStyle),
            ),
          // Material 로 바탕을 칠한다. Container 로 칠하면 안에 놓인 ListTile 의
          // 잉크 효과가 그 뒤로 숨어 눌러도 반응이 없는 것처럼 보인다.
          DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.card),
              boxShadow: AppShadow.card,
            ),
            child: Material(
              color: color,
              borderRadius: BorderRadius.circular(AppRadius.card),
              clipBehavior: Clip.antiAlias,
              child: Padding(
                padding: padding,
                child: SizedBox(width: double.infinity, child: child),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 상태를 한 단어로 보여 주는 작은 알약. 마감·대기·완료 같은 것.
class StatusPill extends StatelessWidget {
  const StatusPill({
    super.key,
    required this.text,
    this.color = AppColor.muted,
    this.background = AppColor.canvas,
    this.icon,
  });

  final String text;
  final Color color;
  final Color background;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(icon == null ? 9 : 7, 4, 9, 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            text,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// 아무것도 없을 때. 빈 화면에 글자만 덩그러니 두면 고장인지 비어 있는지 모른다.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.text,
    this.detail,
  });

  final IconData icon;
  final String text;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: const BoxDecoration(
                color: AppColor.surface,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 28, color: AppColor.faint),
            ),
            const SizedBox(height: 16),
            Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColor.muted,
              ),
            ),
            if (detail != null) ...[
              const SizedBox(height: 6),
              Text(
                detail!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: AppColor.muted),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

enum NoticeTone { info, good, warn }

/// 주의를 끌어야 하는 한 줄 안내 (배점 남음, 이미 점수 있음 등).
class NoticeBox extends StatelessWidget {
  const NoticeBox({
    super.key,
    required this.text,
    this.detail,
    this.tone = NoticeTone.info,
  });

  final String text;
  final String? detail;
  final NoticeTone tone;

  @override
  Widget build(BuildContext context) {
    final (bg, fg, icon) = switch (tone) {
      NoticeTone.info => (
        AppColor.accentSoft,
        AppColor.accent,
        Icons.info_outline,
      ),
      NoticeTone.good => (
        AppColor.successSoft,
        AppColor.success,
        Icons.check_circle_outline,
      ),
      NoticeTone.warn => (
        AppColor.warnSoft,
        AppColor.warn,
        Icons.error_outline,
      ),
    };

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: fg),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  text,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: fg,
                  ),
                ),
                if (detail != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    detail!,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: fg.withValues(alpha: 0.85),
                      height: 1.45,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 화면 위쪽에 붙는 얇은 띠. 마감·전송 대기처럼 **지금 상태**를 알린다.
///
/// [NoticeBox] 와 달리 카드 안이 아니라 화면 폭을 꽉 채운다. 목록과 채점 화면이
/// 같은 띠를 쓰도록 여기에 둔다 — 예전에는 목록에만 있어서, 채점하는 동안에는
/// 연결이 끊긴 줄도 모르고 계속 입력하다가 나중에야 알게 됐다.
class StatusStrip extends StatelessWidget {
  const StatusStrip({
    super.key,
    required this.icon,
    required this.text,
    required this.foreground,
    required this.background,
    this.action,
    this.onAction,
    this.busy = false,
  });

  final IconData icon;
  final String text;
  final Color foreground;
  final Color background;

  /// 오른쪽 끝 글자 버튼. 없으면 띠만 그린다.
  final String? action;
  final VoidCallback? onAction;

  /// 참이면 아이콘 자리에 회전하는 표시를 둔다.
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: background,
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 9, action == null ? 16 : 6, 9),
        child: Row(
          children: [
            SizedBox(
              width: 17,
              height: 17,
              child: busy
                  ? CircularProgressIndicator(strokeWidth: 2, color: foreground)
                  : Icon(icon, size: 17, color: foreground),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.4,
                  fontWeight: FontWeight.w600,
                  color: foreground,
                ),
              ),
            ),
            if (action != null)
              TextButton(
                onPressed: onAction,
                style: TextButton.styleFrom(
                  foregroundColor: foreground,
                  minimumSize: const Size(0, 36),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  // 테마 글꼴을 물려받도록 labelLarge 에서 파생한다.
                  textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                child: Text(action!),
              ),
          ],
        ),
      ),
    );
  }
}

/// 목록 위의 찾기 칸. 글자가 있으면 지우기 단추가 생긴다.
///
/// 칸이 비었을 때도 × 를 두면 누를 것이 없는 단추가 늘 떠 있게 된다.
class SearchField extends StatelessWidget {
  const SearchField({
    super.key,
    required this.controller,
    required this.hint,
    required this.onChanged,
  });

  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final hasText = controller.text.isNotEmpty;

    return TextField(
      controller: controller,
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      style: const TextStyle(fontSize: 14.5, color: AppColor.ink),
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: AppColor.surface,
        prefixIcon: const Icon(Icons.search, size: 19, color: AppColor.faint),
        prefixIconConstraints: const BoxConstraints(minWidth: 40),
        suffixIcon: hasText
            ? IconButton(
                tooltip: '지우기',
                icon: const Icon(Icons.cancel, size: 17, color: AppColor.faint),
                onPressed: () {
                  controller.clear();
                  onChanged('');
                },
              )
            : null,
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
      ),
    );
  }
}

/// 진행 막대 한 줄 — 제목·수치·막대.
class ProgressRow extends StatelessWidget {
  const ProgressRow({
    super.key,
    required this.label,
    required this.value,
    required this.total,
  });

  final String label;
  final int value;
  final int total;

  @override
  Widget build(BuildContext context) {
    final ratio = total == 0 ? 0.0 : value / total;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: AppColor.muted,
                ),
              ),
            ),
            Text(
              '$value',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: AppColor.accent,
              ),
            ),
            Text(
              ' / $total',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColor.muted,
              ),
            ),
          ],
        ),
        const SizedBox(height: 7),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.pill),
          // 0 일 때도 막대 자리는 남는다 — 자리가 없으면 "아직 0건"인지
          // "막대가 그려지지 않은 것"인지 구분되지 않는다.
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: ratio),
            duration: const Duration(milliseconds: 420),
            curve: Curves.easeOutCubic,
            builder: (context, animated, _) => LinearProgressIndicator(
              value: animated,
              minHeight: 7,
              backgroundColor: AppColor.line,
            ),
          ),
        ),
      ],
    );
  }
}

/// 그림자로 띄운 흰 카드. 누를 수 있으면 [onTap] 을 준다.
///
/// [SectionCard] 가 "머리글 달린 구역" 이라면 이것은 목록의 한 줄 같은 **낱개** 다.
/// [accent] 를 주면 왼쪽에 색 띠가 생긴다 — 묶음을 색으로 구분할 때 쓴다.
class CardBox extends StatelessWidget {
  const CardBox({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(16),
    this.color = AppColor.surface,
    this.accent,
    this.outline,
    this.radius = AppRadius.card,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets padding;
  final Color color;
  final Color? accent;

  /// 강조 테두리. 선정·동점처럼 한 줄만 눈에 띄어야 할 때.
  final Color? outline;
  final double radius;

  @override
  Widget build(BuildContext context) {
    Widget body = Padding(padding: padding, child: child);

    if (accent != null) {
      // 목록 안에서는 높이가 정해져 있지 않으므로, 색 띠가 내용 높이만큼만 늘어나게
      // IntrinsicHeight 로 감싼다.
      body = IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 5, color: accent),
            Expanded(child: body),
          ],
        ),
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: AppShadow.card,
      ),
      child: Material(
        color: color,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
          side: outline == null
              ? BorderSide.none
              : BorderSide(color: outline!, width: 1.6),
        ),
        clipBehavior: Clip.antiAlias,
        child: onTap == null ? body : InkWell(onTap: onTap, child: body),
      ),
    );
  }
}

/// 그라데이션 머리 판. 화면 맨 위에서 행사명·진행률처럼 **지금 어디에 있는지**를 알린다.
class HeroPanel extends StatelessWidget {
  const HeroPanel({
    super.key,
    required this.child,
    this.gradient = AppGradient.hero,
    this.padding = const EdgeInsets.all(20),
    this.radius = const BorderRadius.all(Radius.circular(24)),
  });

  final Widget child;
  final Gradient gradient;
  final EdgeInsets padding;
  final BorderRadius radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: radius,
        boxShadow: AppShadow.tinted(gradient.colors.first),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // 밋밋한 그라데이션 위에 큰 원 두 개를 흐리게 얹어 깊이를 준다.
          Positioned(
            right: -40,
            top: -50,
            child: _Bubble(size: 160, alpha: 0.10),
          ),
          Positioned(
            right: 60,
            bottom: -70,
            child: _Bubble(size: 140, alpha: 0.07),
          ),
          Padding(padding: padding, child: child),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.size, required this.alpha});

  final double size;
  final double alpha;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: alpha),
      ),
    );
  }
}

/// 그라데이션 머리 판([HeroPanel]) 위의 둥근 흰 단추. 목록·관리자 머리에서 같이 쓴다.
class HeroAction extends StatelessWidget {
  const HeroAction({
    required this.tooltip,
    required this.icon,
    required this.onTap,
    this.highlighted = false,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onTap;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: Material(
        color: Colors.white.withValues(alpha: highlighted ? 0.9 : 0.16),
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: IconButton(
          tooltip: tooltip,
          onPressed: onTap,
          icon: Icon(
            icon,
            size: 21,
            color: highlighted ? AppColor.accent : Colors.white,
          ),
        ),
      ),
    );
  }
}

/// 색 바탕에 아이콘 하나. 목록 줄 앞, 설정 줄 앞에 둔다.
class IconBadge extends StatelessWidget {
  const IconBadge({
    super.key,
    required this.icon,
    this.tone = AppTone.indigo,
    this.size = 40,
    this.filled = false,
  });

  final IconData icon;
  final AppTone tone;
  final double size;

  /// 참이면 진한 색 바탕에 흰 아이콘.
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: filled ? tone.strong : tone.soft,
        borderRadius: BorderRadius.circular(size * 0.3),
      ),
      child: Icon(
        icon,
        size: size * 0.5,
        color: filled ? Colors.white : tone.strong,
      ),
    );
  }
}

/// 색 있는 통계 타일 — 큰 숫자 하나와 그 뜻.
///
/// [onTap] 을 주면 누를 수 있고 [selected] 로 고른 표시(진한 테두리)를 낸다.
/// 목록의 "전체·미완료·완료" 처럼 통계가 곧 필터인 자리에 쓴다.
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.label,
    required this.value,
    required this.tone,
    this.icon,
    this.onTap,
    this.selected = false,
    this.suffix,
  });

  final String label;
  final String value;
  final AppTone tone;
  final IconData? icon;
  final VoidCallback? onTap;
  final bool selected;

  /// 숫자 뒤에 작게 붙는 단위. "/ 12" 나 "점" 같은 것.
  final String? suffix;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: onTap != null,
      selected: onTap == null ? null : selected,
      label: '$label $value${suffix ?? ''}',
      child: Material(
        color: tone.soft,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
          side: BorderSide(
            color: selected ? tone.strong : Colors.transparent,
            width: 2,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 18, color: tone.strong),
                  const SizedBox(height: 8),
                ],
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Flexible(
                      child: Text(
                        value,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 24,
                          height: 1.1,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                          color: tone.ink,
                        ),
                      ),
                    ),
                    if (suffix != null)
                      Text(
                        suffix!,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: tone.ink.withValues(alpha: 0.7),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: tone.ink.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 순위 배지. 1·2·3 위는 금·은·동, 나머지는 회색 숫자.
class RankBadge extends StatelessWidget {
  const RankBadge({super.key, required this.rank, this.size = 40});

  final int? rank;
  final double size;

  @override
  Widget build(BuildContext context) {
    final (bg, fg, medal) = switch (rank) {
      1 => (const Color(0xFFF59E0B), Colors.white, true),
      2 => (const Color(0xFF94A3B8), Colors.white, true),
      3 => (const Color(0xFFD97706), Colors.white, true),
      _ => (AppColor.canvas, AppColor.muted, false),
    };

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(size * 0.3),
        boxShadow: medal ? AppShadow.tinted(bg) : null,
      ),
      child: Text(
        rank?.toString() ?? '–',
        style: TextStyle(
          fontSize: size * 0.42,
          fontWeight: FontWeight.w800,
          color: fg,
        ),
      ),
    );
  }
}

/// 이름 첫 글자를 색 바탕에 얹은 아바타. 사진이 없는 목록에서 줄을 구분해 준다.
class LetterAvatar extends StatelessWidget {
  const LetterAvatar({
    super.key,
    required this.text,
    required this.tone,
    this.size = 44,
  });

  final String text;
  final AppTone tone;
  final double size;

  @override
  Widget build(BuildContext context) {
    final letter = text.trim().isEmpty
        ? '?'
        : String.fromCharCode(text.trim().runes.first);

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: tone.soft,
        borderRadius: BorderRadius.circular(size * 0.3),
      ),
      child: Text(
        letter,
        style: TextStyle(
          fontSize: size * 0.42,
          fontWeight: FontWeight.w800,
          color: tone.ink,
        ),
      ),
    );
  }
}

/// "방금 전" · "3분 전" 처럼 마지막 전송 시각을 사람 말로 바꾼다.
/// 한 시간이 넘으면 시:분 을 그대로 보여 준다 — "97분 전"은 세어 봐야 안다.
String formatSyncedAt(DateTime? at, {DateTime? now}) {
  if (at == null) return '아직 전송 전';

  final elapsed = (now ?? DateTime.now()).difference(at);

  if (elapsed.inSeconds < 45) return '방금 전 전송됨';
  if (elapsed.inMinutes < 60) return '${elapsed.inMinutes}분 전 전송됨';

  final hour = at.hour.toString().padLeft(2, '0');
  final minute = at.minute.toString().padLeft(2, '0');

  return '$hour:$minute 전송됨';
}
