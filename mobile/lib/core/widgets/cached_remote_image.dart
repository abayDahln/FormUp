import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:form_up/core/widgets/app_loading_indicator.dart';

class CachedRemoteImage extends StatelessWidget {
  final String url;
  final BoxFit fit;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final Widget? placeholder;
  final Widget? errorWidget;

  const CachedRemoteImage({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.borderRadius,
    this.placeholder,
    this.errorWidget,
  });

  @override
  Widget build(BuildContext context) {
    final image = CachedNetworkImage(
      imageUrl: url,
      fit: fit,
      width: width,
      height: height,
      placeholder: (_, __) =>
          placeholder ?? const Center(child: AppLoadingIndicator.circular()),
      errorWidget: (_, __, ___) =>
          errorWidget ?? const SizedBox.shrink(),
    );

    final radius = borderRadius;
    if (radius == null) return image;
    return ClipRRect(borderRadius: radius, child: image);
  }
}

class CachedRemoteCircleAvatar extends StatelessWidget {
  final String? url;
  final double radius;
  final Color backgroundColor;
  final Widget fallback;

  const CachedRemoteCircleAvatar({
    super.key,
    required this.url,
    required this.radius,
    required this.backgroundColor,
    required this.fallback,
  });

  @override
  Widget build(BuildContext context) {
    if (url == null || url!.isEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: backgroundColor,
        child: fallback,
      );
    }

    return CircleAvatar(
      radius: radius,
      backgroundColor: backgroundColor,
      backgroundImage: CachedNetworkImageProvider(url!),
      onBackgroundImageError: (_, __) {},
      child: fallback,
    );
  }
}
