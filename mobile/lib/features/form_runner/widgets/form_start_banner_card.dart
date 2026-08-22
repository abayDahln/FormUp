import 'package:flutter/material.dart';
import 'package:form_up/core/services/auth_service.dart';
import 'package:form_up/core/widgets/auth_widgets.dart';

/// Kartu banner form pada halaman awal pengerjaan
class FormStartBannerCard extends StatelessWidget {
  final String bannerImage;

  const FormStartBannerCard({super.key, required this.bannerImage});

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: softShadow(),
      ),
      child: AspectRatio(
        aspectRatio: 16 / 7,
        child: Image.network(
          profileImageUrl(bannerImage),
          fit: BoxFit.cover,
          width: double.infinity,
          errorBuilder: (_, _, _) => Container(
            color: kPrimarySoft,
            child: const Icon(
              Icons.image_outlined,
              size: 40,
              color: kAuthPrimary,
            ),
          ),
        ),
      ),
    );
  }
}
