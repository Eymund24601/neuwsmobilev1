import 'package:flutter/material.dart';

class AdaptiveImage extends StatelessWidget {
  const AdaptiveImage({
    super.key,
    required this.source,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
  });

  final String source;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final fallback = _assetPlaceholder;
    final normalized = source.trim();
    final resolved = normalized.isEmpty ? fallback : normalized;

    final widget = _isRemoteUrl(resolved)
        ? Image.network(
            resolved,
            width: width,
            height: height,
            fit: fit,
            errorBuilder: (context, error, stackTrace) =>
                Image.asset(fallback, width: width, height: height, fit: fit),
          )
        : Image.asset(
            resolved,
            width: width,
            height: height,
            fit: fit,
            errorBuilder: (context, error, stackTrace) =>
                Image.asset(fallback, width: width, height: height, fit: fit),
          );

    if (borderRadius == null) {
      return widget;
    }
    return ClipRRect(borderRadius: borderRadius!, child: widget);
  }

  bool _isRemoteUrl(String value) {
    final lower = value.toLowerCase();
    return lower.startsWith('http://') || lower.startsWith('https://');
  }

  static const _assetPlaceholder = 'assets/images/placeholder.jpg';
}
