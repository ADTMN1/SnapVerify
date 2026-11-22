import 'package:flutter/material.dart';
import '../../core/tailwind.dart';

enum _SvLoaderVariant { page, button, inline, large }

class SvLoader extends StatelessWidget {
  final _SvLoaderVariant _variant;
  final double _size;
  final double _strokeWidth;
  final Color _color;
  final Color? _backgroundColor;

  const SvLoader({super.key})
    : _variant = _SvLoaderVariant.page,
      _size = 28,
      _strokeWidth = 2.6,
      _color = TwColors.brightGreen,
      _backgroundColor = null;

  const SvLoader.page({super.key, Color? color, Color? backgroundColor})
    : _variant = _SvLoaderVariant.page,
      _size = 28,
      _strokeWidth = 2.6,
      _color = color ?? TwColors.brightGreen,
      _backgroundColor = backgroundColor;

  const SvLoader.button({super.key, Color? color})
    : _variant = _SvLoaderVariant.button,
      _size = 18,
      _strokeWidth = 2.2,
      _color = color ?? TwColors.primaryBg,
      _backgroundColor = null;

  const SvLoader.inline({super.key, Color? color})
    : _variant = _SvLoaderVariant.inline,
      _size = 16,
      _strokeWidth = 2.0,
      _color = color ?? TwColors.brightGreen,
      _backgroundColor = null;

  const SvLoader.large({super.key, Color? color})
    : _variant = _SvLoaderVariant.large,
      _size = 56,
      _strokeWidth = 3.0,
      _color = color ?? TwColors.brightGreen,
      _backgroundColor = null;

  Color? get _trackColor {
    if (_backgroundColor != null) return _backgroundColor;
    if (_variant == _SvLoaderVariant.page) {
      return _color.withValues(alpha: 0.12);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _size,
      height: _size,
      child: CircularProgressIndicator(
        strokeWidth: _strokeWidth,
        valueColor: AlwaysStoppedAnimation<Color>(_color),
        backgroundColor: _trackColor,
      ),
    );
  }
}
