import 'package:flutter/material.dart';

class TwColors {
  static const slate50 = Color(0xFFf8fafc);
  static const slate100 = Color(0xFFf1f5f9);
  static const slate200 = Color(0xFFe2e8f0);
  static const slate300 = Color(0xFFcbd5e1);
  static const slate400 = Color(0xFF94a3b8);
  static const slate500 = Color(0xFF64748b);
  static const slate600 = Color(0xFF475569);
  static const slate700 = Color(0xFF334155);
  static const slate800 = Color(0xFF1e293b);
  static const slate900 = Color(0xFF0f172a);
  static const slate950 = Color(0xFF020617);
  static const primaryBg = Color(0xFF050D18);
  static const cardBg = Color(0xFF0D1926);

  static const lime400 = Color(0xFFa3e635);
  static const lime500 = Color(0xFF84cc16);
  static const brightGreen = Color(0xFFB8FF3B);

  static const blue500 = Color(0xFF0ea5e9);
  static const sky50 = Color(0xFFf0f9ff);
  static const sky100 = Color(0xFFe0f2fe);
  static const sky200 = Color(0xFFbae6fd);
  static const sky300 = Color(0xFF7dd3fc);
  static const sky400 = Color(0xFF38bdf8);
  static const sky500 = Color(0xFF0ea5e9);
  static const sky600 = Color(0xFF0284c7);
  static const sky700 = Color(0xFF0369a1);
  static const sky800 = Color(0xFF075985);
  static const sky900 = Color(0xFF0c4a6e);

  static const violet50 = Color(0xFFf5f3ff);
  static const violet100 = Color(0xFFede9fe);
  static const violet200 = Color(0xFFddd6fe);
  static const violet300 = Color(0xFFc4b5fd);
  static const violet400 = Color(0xFFa78bfa);
  static const violet500 = Color(0xFF8b5cf6);
  static const violet600 = Color(0xFF7c3aed);
  static const violet700 = Color(0xFF6d28d9);
  static const violet800 = Color(0xFF5b21b6);
  static const violet900 = Color(0xFF4c1d95);

  static const emerald50 = Color(0xFFecfdf5);
  static const emerald100 = Color(0xFFd1fae5);
  static const emerald200 = Color(0xFFa7f3d0);
  static const emerald300 = Color(0xFF6ee7b7);
  static const emerald400 = Color(0xFF34d399);
  static const emerald500 = Color(0xFF10b981);
  static const emerald600 = Color(0xFF059669);
  static const emerald700 = Color(0xFF047857);
  static const emerald800 = Color(0xFF065f46);
  static const emerald900 = Color(0xFF064e3b);

  static const amber50 = Color(0xFFfffbeb);
  static const amber100 = Color(0xFFfef3c7);
  static const amber200 = Color(0xFFfde68a);
  static const amber300 = Color(0xFFfcd34d);
  static const amber400 = Color(0xFFfbbf24);
  static const amber500 = Color(0xFFf59e0b);
  static const amber600 = Color(0xFFd97706);
  static const amber700 = Color(0xFFb45309);
  static const amber800 = Color(0xFF92400e);
  static const amber900 = Color(0xFF78350f);

  static const red50 = Color(0xFFfef2f2);
  static const red100 = Color(0xFFfee2e2);
  static const red200 = Color(0xFFfecaca);
  static const red300 = Color(0xFFfca5a5);
  static const red400 = Color(0xFFf87171);
  static const red500 = Color(0xFFef4444);
  static const red600 = Color(0xFFdc2626);
  static const red700 = Color(0xFFb91c1c);
  static const red800 = Color(0xFF991b1b);
  static const red900 = Color(0xFF7f1d1d);

  static const white = Color(0xFFFFFFFF);
  static const white70 = Color(0xB3FFFFFF);
}

class Tw {
  static Widget column(List<Widget> children, {
    MainAxisAlignment mainAxisAlignment = MainAxisAlignment.start,
    CrossAxisAlignment crossAxisAlignment = CrossAxisAlignment.center,
  }) {
    return Column(
      mainAxisAlignment: mainAxisAlignment,
      crossAxisAlignment: crossAxisAlignment,
      children: children,
    );
  }

  static Widget row(List<Widget> children, {
    MainAxisAlignment mainAxisAlignment = MainAxisAlignment.start,
    CrossAxisAlignment crossAxisAlignment = CrossAxisAlignment.center,
  }) {
    return Row(
      mainAxisAlignment: mainAxisAlignment,
      crossAxisAlignment: crossAxisAlignment,
      children: children,
    );
  }
}

extension PaddingExtension on Widget {
  Widget px(double value) => Padding(padding: EdgeInsets.symmetric(horizontal: value), child: this);
  Widget py(double value) => Padding(padding: EdgeInsets.symmetric(vertical: value), child: this);
  Widget p(double value) => Padding(padding: EdgeInsets.all(value), child: this);
}

extension LayoutExtension on Widget {
  Widget expanded({int flex = 1}) => Expanded(flex: flex, child: this);
  Widget center() => Center(child: this);
}
