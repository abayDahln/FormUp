import 'package:flutter/material.dart';
import 'package:form_up/core/services/auth_service.dart';
import 'package:form_up/core/widgets/auth_widgets.dart';
import 'package:form_up/core/widgets/cached_remote_image.dart';
import 'package:form_up/core/widgets/full_screen_image_viewer.dart';

/// Gambar soal — tap untuk full-screen
class QuestionImage extends StatelessWidget {
  final String url;

  const QuestionImage({super.key, required this.url});

  @override
  Widget build(BuildContext context) {
    final fullUrl = profileImageUrl(url);
    return GestureDetector(
      onTap: () => showFullScreenImage(context, fullUrl),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxHeight: 220),
          color: kPrimarySoft,
          child: Hero(
            tag: fullUrl,
            child: CachedRemoteImage(
              url: fullUrl,
              fit: BoxFit.contain,
              errorWidget: const SizedBox(
                height: 140,
                child: Center(
                  child: Icon(
                    Icons.broken_image_outlined,
                    color: Colors.grey,
                    size: 32,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
