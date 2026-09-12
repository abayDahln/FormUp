import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:form_up/core/widgets/app_loading_indicator.dart';
import 'package:form_up/core/widgets/responsive.dart';

/// Provider gambar jaringan aman lintas platform: desktop (Windows/macOS/
/// Linux) memakai [NetworkImage] karena cache sqflite tidak punya
/// implementasi desktop; mobile tetap cached.
ImageProvider adaptiveNetworkImage(String url) =>
    isDesktopPlatform ? NetworkImage(url) : CachedNetworkImageProvider(url);

/// Widget gambar jaringan adaptif — pengganti pemakaian [CachedNetworkImage]
/// langsung di layar (banner template dkk).
Widget adaptiveCachedImage({
  required String url,
  BoxFit fit = BoxFit.cover,
  double? width,
  double? height,
  int? memCacheWidth,
  Widget? placeholder,
  Widget? errorWidget,
}) {
  if (isDesktopPlatform) {
    return Image.network(
      url,
      fit: fit,
      width: width,
      height: height,
      // cacheWidth meniru memCacheWidth agar hemat memori di desktop.
      cacheWidth: memCacheWidth,
      loadingBuilder: (_, child, progress) =>
          progress == null ? child : (placeholder ?? const AppLoadingOverlay()),
      errorBuilder: (_, _, _) => errorWidget ?? const SizedBox.shrink(),
    );
  }
  return CachedNetworkImage(
    imageUrl: url,
    fit: fit,
    width: width,
    height: height,
    memCacheWidth: memCacheWidth,
    placeholder: (_, __) => placeholder ?? const AppLoadingOverlay(),
    errorWidget: (_, __, ___) => errorWidget ?? const SizedBox.shrink(),
  );
}

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
    final image = adaptiveCachedImage(
      url: url,
      fit: fit,
      width: width,
      height: height,
      placeholder: placeholder,
      errorWidget: errorWidget,
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
      // foregroundImage (bukan backgroundImage) agar foto menutup huruf
      // inisial saat berhasil dimuat; huruf tetap tampil saat loading/gagal.
      foregroundImage: adaptiveNetworkImage(url!),
      onForegroundImageError: (_, __) {},
      child: fallback,
    );
  }
}
