import 'package:flutter/material.dart';

const Color kAccent = Color(0xFF3B7DD8);

/// App palette for both brightnesses (calm blue accents, light blue-gray
/// background, white cards). Contrast of text colors against their
/// backgrounds is >= 4.5:1.
class Palette {
  final Color background;
  final Color card;
  final Color cardBorder;
  final Color text;
  final Color textMuted;
  final Color accent;
  final Color accentSoft;
  final Color danger;
  final Color dangerSoft;
  final Color warning;
  final Color warningSoft;
  final Color success;
  final Color successSoft;
  final Color followUp;
  final Color followUpSoft;
  final Color chip;

  const Palette({
    required this.background,
    required this.card,
    required this.cardBorder,
    required this.text,
    required this.textMuted,
    required this.accent,
    required this.accentSoft,
    required this.danger,
    required this.dangerSoft,
    required this.warning,
    required this.warningSoft,
    required this.success,
    required this.successSoft,
    required this.followUp,
    required this.followUpSoft,
    required this.chip,
  });

  static const light = Palette(
    background: Color(0xFFF2F5F9),
    card: Color(0xFFFFFFFF),
    cardBorder: Color(0xFFE3E8EF),
    text: Color(0xFF1C2530),
    textMuted: Color(0xFF5A6675),
    accent: Color(0xFF2F6FC4),
    accentSoft: Color(0xFFE3EDFA),
    danger: Color(0xFFC0392B),
    dangerSoft: Color(0xFFFBE7E5),
    warning: Color(0xFF9A6200),
    warningSoft: Color(0xFFFFF1D6),
    success: Color(0xFF237A57),
    successSoft: Color(0xFFDDF3E8),
    followUp: Color(0xFF6A4BB0),
    followUpSoft: Color(0xFFEDE7F8),
    chip: Color(0xFFE8EDF4),
  );

  static const dark = Palette(
    background: Color(0xFF10151B),
    card: Color(0xFF1A2129),
    cardBorder: Color(0xFF29323D),
    text: Color(0xFFE7ECF2),
    textMuted: Color(0xFFA3AEBB),
    accent: Color(0xFF7FB0F0),
    accentSoft: Color(0xFF1E3350),
    danger: Color(0xFFF08A7E),
    dangerSoft: Color(0xFF3D2220),
    warning: Color(0xFFF0C063),
    warningSoft: Color(0xFF3A2E14),
    success: Color(0xFF6FD3A4),
    successSoft: Color(0xFF173528),
    followUp: Color(0xFFB9A2EE),
    followUpSoft: Color(0xFF2C2443),
    chip: Color(0xFF222B35),
  );

  static Palette of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;
}

ThemeData buildTheme(Brightness brightness) {
  final p = brightness == Brightness.dark ? Palette.dark : Palette.light;
  final scheme = ColorScheme.fromSeed(seedColor: kAccent, brightness: brightness).copyWith(
    primary: p.accent,
    onPrimary: brightness == Brightness.dark ? const Color(0xFF0B1A2E) : Colors.white,
    surface: p.card,
    onSurface: p.text,
    error: p.danger,
  );
  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    fontFamily: 'Tajawal',
    scaffoldBackgroundColor: p.background,
    appBarTheme: AppBarTheme(
      backgroundColor: p.background,
      foregroundColor: p.text,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(fontFamily: 'Tajawal', fontSize: 22, fontWeight: FontWeight.w700, color: p.text),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: p.card,
      indicatorColor: p.accentSoft,
      elevation: 0,
      height: 68,
      labelTextStyle: WidgetStatePropertyAll(TextStyle(fontFamily: 'Tajawal', fontSize: 12, color: p.text)),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: p.accent,
      foregroundColor: scheme.onPrimary,
      elevation: 2,
      shape: const CircleBorder(),
    ),
    dividerTheme: DividerThemeData(color: p.cardBorder, thickness: 1, space: 1),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
  );
}

/// White rounded card used for tasks, habits and transactions.
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final EdgeInsetsGeometry margin;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.onTap,
    this.onLongPress,
    this.margin = const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
  });

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Padding(
      padding: margin,
      child: Material(
        color: p.card,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          onLongPress: onLongPress,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: p.cardBorder),
            ),
            padding: padding,
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Small rounded label (status, priority, due/follow-up).
class Pill extends StatelessWidget {
  final String text;
  final Color fg;
  final Color bg;
  final IconData? icon;
  const Pill({super.key, required this.text, required this.fg, required this.bg, this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 13, color: fg), const SizedBox(width: 3)],
          Flexible(
            child: Text(
              text,
              style: TextStyle(fontSize: 12, color: fg, fontWeight: FontWeight.w500, height: 1.2),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// Circular completion control with a 48dp touch target.
class CompletionCircle extends StatelessWidget {
  final bool done;
  final Color color;
  final VoidCallback onTap;
  final String semanticLabel;
  final double size;

  const CompletionCircle({
    super.key,
    required this.done,
    required this.color,
    required this.onTap,
    required this.semanticLabel,
    this.size = 24,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      checked: done,
      label: semanticLabel,
      child: InkResponse(
        onTap: onTap,
        radius: 24,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: done ? color : Colors.transparent,
                border: Border.all(color: color, width: 2),
              ),
              child: done ? Icon(Icons.check, size: size * 0.7, color: Colors.white) : null,
            ),
          ),
        ),
      ),
    );
  }
}

/// Section header for lists.
class SectionLabel extends StatelessWidget {
  final String text;
  final Widget? trailing;
  const SectionLabel(this.text, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(20, 18, 16, 6),
      child: Row(
        children: [
          Expanded(
            child: Text(text, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: p.textMuted)),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// Calm empty-state block (no oversized illustrations).
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? body;
  final Widget? action;
  const EmptyState({super.key, required this.icon, required this.title, this.body, this.action});

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 40, color: p.textMuted),
          const SizedBox(height: 12),
          Text(title,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: p.text)),
          if (body != null) ...[
            const SizedBox(height: 6),
            Text(body!, textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: p.textMuted, height: 1.4)),
          ],
          if (action != null) ...[const SizedBox(height: 16), action!],
        ],
      ),
    );
  }
}
