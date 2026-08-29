import 'package:flutter/material.dart';
import 'package:form_up/core/widgets/cached_remote_image.dart';

/// Buka overlay full-screen dengan pinch-zoom (InteractiveViewer) dan hero animation
void showFullScreenImage(BuildContext context, String url) {
  Navigator.of(context).push(
    PageRouteBuilder(
      opaque: false,
      barrierColor: Colors.black87,
      barrierDismissible: true,
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (_, __, ___) => FullScreenImageViewer(url: url),
    ),
  );
}

class FullScreenImageViewer extends StatelessWidget {
  final String url;
  const FullScreenImageViewer({super.key, required this.url});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black87,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: Hero(
          tag: url,
          child: InteractiveViewer(
            minScale: 0.5,
            maxScale: 4.0,
            child: CachedRemoteImage(
              url: url,
              fit: BoxFit.contain,
              errorWidget: const Icon(Icons.broken_image_outlined, color: Colors.white54, size: 48),
            ),
          ),
        ),
      ),
    );
  }
}
