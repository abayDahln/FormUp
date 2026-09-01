// Deprecated re-export – pecah jadi LoadingIndicator vs ProgressIndicator
// ignore_for_file: deprecated_member_use_from_same_package
export 'loading_indicator.dart';
export 'progress_indicator.dart';

import 'package:flutter/material.dart';
import 'loading_indicator.dart';
import 'progress_indicator.dart' as pi;

/// @deprecated Gunakan LoadingIndicator untuk menunggu data,
/// dan ProgressIndicator untuk proses simpan ke database.
@Deprecated('Gunakan LoadingIndicator (load data/media) atau ProgressIndicator (save/update DB)')
class AppLoadingIndicator extends StatelessWidget {
  final double? size;
  final double? strokeWidth;
  final double? value;
  final Color? color;
  final Color? backgroundColor;
  final double? linearHeight;
  final bool _isLinear;
  final bool _isContained;
  final String? semanticsLabel;

  const AppLoadingIndicator({
    super.key,
    this.size = 72,
    this.strokeWidth,
    this.value,
    this.color,
    this.backgroundColor,
    this.linearHeight,
    this.semanticsLabel,
  })  : _isLinear = false,
        _isContained = false;

  const AppLoadingIndicator.circular({
    super.key,
    this.size = 72,
    this.strokeWidth,
    this.value,
    this.color,
    this.backgroundColor,
    this.linearHeight,
    this.semanticsLabel,
  })  : _isLinear = false,
        _isContained = false;

  const AppLoadingIndicator.contained({
    super.key,
    this.size = 80,
    this.strokeWidth,
    this.value,
    this.color,
    this.backgroundColor,
    this.linearHeight,
    this.semanticsLabel,
  })  : _isLinear = false,
        _isContained = true;

  const AppLoadingIndicator.inline({
    super.key,
    this.size = 36,
    this.strokeWidth,
    this.value,
    this.color,
    this.backgroundColor,
    this.linearHeight,
    this.semanticsLabel,
  })  : _isLinear = false,
        _isContained = false;

  const AppLoadingIndicator.small({
    super.key,
    this.size = 24,
    this.strokeWidth,
    this.value,
    this.color,
    this.backgroundColor,
    this.linearHeight,
    this.semanticsLabel,
  })  : _isLinear = false,
        _isContained = false;

  const AppLoadingIndicator.button({
    super.key,
    this.size = 18,
    this.strokeWidth,
    this.value,
    this.color = Colors.white,
    this.backgroundColor,
    this.linearHeight,
    this.semanticsLabel,
  })  : _isLinear = false,
        _isContained = false;

  const AppLoadingIndicator.linear({
    super.key,
    this.value,
    this.color,
    this.backgroundColor,
    this.linearHeight = 4,
    this.semanticsLabel,
  })  : _isLinear = true,
        _isContained = false,
        size = null,
        strokeWidth = null;

  @override
  Widget build(BuildContext context) {
    if (_isLinear) {
      return pi.ProgressIndicator.linear(
        value: value,
        color: color,
        backgroundColor: backgroundColor,
        linearHeight: linearHeight ?? 4,
        semanticsLabel: semanticsLabel,
      );
    }
    if (_isContained) {
      return LoadingIndicator.contained(
        size: size,
        strokeWidth: strokeWidth,
        value: value,
        color: color,
        backgroundColor: backgroundColor,
        semanticsLabel: semanticsLabel,
      );
    }
    if (size == 36) {
      return LoadingIndicator.inline(
        size: size,
        color: color,
        semanticsLabel: semanticsLabel,
      );
    }
    if (size == 24) {
      return LoadingIndicator.small(color: color, semanticsLabel: semanticsLabel);
    }
    if (size == 18) {
      return LoadingIndicator.button(color: color, semanticsLabel: semanticsLabel);
    }
    return LoadingIndicator.circular(
      size: size,
      color: color,
      semanticsLabel: semanticsLabel,
    );
  }
}

@Deprecated('Gunakan LoadingOverlay')
class AppLoadingOverlay extends StatelessWidget {
  final String? message;
  final bool contained;
  const AppLoadingOverlay({super.key, this.message, this.contained = false});

  @override
  Widget build(BuildContext context) {
    return LoadingOverlay(message: message, contained: contained);
  }
}
