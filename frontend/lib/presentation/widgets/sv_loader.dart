import 'package:flutter/material.dart';
import '../../theme/app_tokens.dart';

enum _SvLoaderVariant { page, button, inline, large }

class SvLoader extends StatelessWidget {
  final _SvLoaderVariant _variant;
  final double _size;
  final double _strokeWidth;
  final Color _color;
  final Color? _backgroundColor;

  const SvLoader({super.key})
    : _variant = _SvLoaderVariant.page,
      _size = AppTokens.loaderPageSize,
      _strokeWidth = AppTokens.loaderPageStroke,
      _color = AppTokens.accent,
      _backgroundColor = null;

  const SvLoader.page({super.key, Color? color, Color? backgroundColor})
    : _variant = _SvLoaderVariant.page,
      _size = AppTokens.loaderPageSize,
      _strokeWidth = AppTokens.loaderPageStroke,
      _color = color ?? AppTokens.accent,
      _backgroundColor = backgroundColor;

  const SvLoader.button({super.key, Color? color})
    : _variant = _SvLoaderVariant.button,
      _size = AppTokens.loaderButtonSize,
      _strokeWidth = AppTokens.loaderButtonStroke,
      _color = color ?? AppTokens.obsidian950,
      _backgroundColor = null;

  const SvLoader.inline({super.key, Color? color})
    : _variant = _SvLoaderVariant.inline,
      _size = AppTokens.loaderInlineSize,
      _strokeWidth = AppTokens.loaderInlineStroke,
      _color = color ?? AppTokens.accent,
      _backgroundColor = null;

  const SvLoader.large({super.key, Color? color})
    : _variant = _SvLoaderVariant.large,
      _size = AppTokens.loaderLargeSize,
      _strokeWidth = AppTokens.loaderLargeStroke,
      _color = color ?? AppTokens.accent,
      _backgroundColor = null;

  Color? get _trackColor {
    if (_backgroundColor != null) return _backgroundColor;
    if (_variant == _SvLoaderVariant.page) {
      return _color.withValues(alpha: AppTokens.alphaLow);
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
