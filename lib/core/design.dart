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
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
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
  });

  final Widget child;
  final String? title;
  final EdgeInsets padding;
  final EdgeInsets margin;

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
          Material(
            color: AppColor.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.card),
              side: const BorderSide(color: AppColor.line),
            ),
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: padding,
              child: SizedBox(width: double.infinity, child: child),
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
