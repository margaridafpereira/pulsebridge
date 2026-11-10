import 'package:flutter/material.dart';

/// PulseBridge design tokens: a dark clinical-monitor palette where colour
/// always carries meaning (green normal, amber warning, coral alarm).
abstract final class AppColors {
  static const background = Color(0xFF070B0F);
  static const surface = Color(0xFF0F161C);
  static const surfaceHigh = Color(0xFF16212A);
  static const outline = Color(0xFF223038);
  static const textPrimary = Color(0xFFE8F0F2);
  static const textSecondary = Color(0xFF8A9BA5);

  static const ecg = Color(0xFF3DDC84);
  static const heart = Color(0xFF3DDC84);
  static const info = Color(0xFF4FC3F7);
  static const warning = Color(0xFFFFB020);
  static const alarm = Color(0xFFFF5A5F);
}

const tabular = [FontFeature.tabularFigures()];

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.ecg,
    brightness: Brightness.dark,
    surface: AppColors.surface,
    primary: AppColors.ecg,
    error: AppColors.alarm,
  );
  final base = ThemeData(useMaterial3: true, colorScheme: scheme, brightness: Brightness.dark);
  return base.copyWith(
    scaffoldBackgroundColor: AppColors.background,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.background,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
      titleTextStyle: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: -0.3),
    ),
    cardTheme: CardThemeData(
      color: AppColors.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppColors.outline),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.surface,
      indicatorColor: AppColors.ecg.withValues(alpha: 0.18),
      surfaceTintColor: Colors.transparent,
      labelTextStyle: WidgetStateProperty.all(const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
    ),
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: AppColors.surfaceHigh,
      side: BorderSide.none,
      shape: const StadiumBorder(),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(56),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surfaceHigh,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
    ),
    dividerTheme: const DividerThemeData(color: AppColors.outline, space: 1),
  );
}

/// Small rounded label with an icon, used for statuses and stats.
class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.label, this.icon, this.color = AppColors.textSecondary, this.filled = false});

  final String label;
  final IconData? icon;
  final Color color;
  final bool filled;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: filled ? color : color.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(100),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[
            Icon(icon, size: 15, color: filled ? Colors.black : color),
            const SizedBox(width: 5),
          ],
          // Wraps onto a second line with large text instead of overflowing.
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                color: filled ? Colors.black : color,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                fontFeatures: tabular,
              ),
            ),
          ),
        ]),
      );
}

/// Labelled number tile for summaries.
class StatTile extends StatelessWidget {
  const StatTile({super.key, required this.label, required this.value, this.unit, this.color = AppColors.textPrimary});

  final String label;
  final String value;
  final String? unit;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: AppColors.surfaceHigh, borderRadius: BorderRadius.circular(16)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label.toUpperCase(),
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.8)),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
              Text(value,
                  style: TextStyle(color: color, fontSize: 24, fontWeight: FontWeight.w800, fontFeatures: tabular)),
              if (unit != null) ...[
                const SizedBox(width: 4),
                Text(unit!, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
              ],
            ]),
          ),
        ]),
      );
}
