import 'package:flutter/material.dart';

const paper = Color(0xfff6f5ef);
const ink = Color(0xff182c29);
const pine = Color(0xff146658);
const mint = Color(0xffd9f1e7);
const stone = Color(0xff52635d);
const border = Color(0xffdbe1d7);
const amber = Color(0xff865100);
const wheat = Color(0xfffaebcf);

ThemeData ticketTheme() {
  final colors = ColorScheme.fromSeed(seedColor: pine).copyWith(
    primary: pine,
    onPrimary: Colors.white,
    surface: paper,
    onSurface: ink,
    onSurfaceVariant: stone,
    outline: stone,
    outlineVariant: border,
    secondaryContainer: mint,
    onSecondaryContainer: pine,
  );
  final theme = ThemeData(
    useMaterial3: true,
    colorScheme: colors,
    scaffoldBackgroundColor: paper,
    appBarTheme: const AppBarTheme(
      backgroundColor: paper,
      foregroundColor: ink,
      centerTitle: false,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: TextStyle(
        color: ink,
        fontSize: 19,
        fontWeight: FontWeight.w700,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: border),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48)),
    ),
  );
  return theme.copyWith(
    textTheme: theme.textTheme.copyWith(
      headlineLarge: const TextStyle(
        color: ink,
        fontSize: 37,
        height: 1.08,
        letterSpacing: -1.5,
        fontWeight: FontWeight.w800,
      ),
      headlineMedium: const TextStyle(
        color: ink,
        fontSize: 28,
        height: 1.15,
        letterSpacing: -.6,
        fontWeight: FontWeight.w800,
      ),
      titleLarge: const TextStyle(
        color: ink,
        fontSize: 20,
        fontWeight: FontWeight.w700,
      ),
      titleMedium: const TextStyle(
        color: ink,
        fontSize: 16,
        fontWeight: FontWeight.w700,
      ),
      bodyMedium: const TextStyle(color: stone, fontSize: 14, height: 1.4),
    ),
  );
}

class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 46});

  final double size;

  @override
  Widget build(BuildContext context) => Container(
    height: size,
    width: size,
    decoration: BoxDecoration(
      color: pine,
      borderRadius: BorderRadius.circular(size * .3),
    ),
    child: Icon(Icons.receipt_long_rounded, size: size * .55, color: mint),
  );
}

class Notice extends StatelessWidget {
  const Notice(
    this.text, {
    super.key,
    this.icon = Icons.info_outline,
    this.warning = false,
  });

  final String text;
  final IconData icon;
  final bool warning;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: warning ? wheat : mint,
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: warning ? amber : pine),
          const SizedBox(width: 11),
          Expanded(
            child: Text(text, style: TextStyle(color: warning ? amber : ink)),
          ),
        ],
      ),
    ),
  );
}

class BoundedList extends StatelessWidget {
  const BoundedList({
    super.key,
    required this.children,
    this.onRefresh,
    this.bottom = 24,
  });

  final List<Widget> children;
  final Future<void> Function()? onRefresh;
  final double bottom;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final side = width > 652 ? (width - 604) / 2 : 24.0;
    final list = ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(side, 12, side, bottom),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: children,
    );
    return onRefresh == null
        ? list
        : RefreshIndicator(onRefresh: onRefresh!, child: list);
  }
}

BoxDecoration cardDecoration({Color color = Colors.white}) => BoxDecoration(
  color: color,
  borderRadius: BorderRadius.circular(19),
  border: Border.all(color: border),
);
