import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../models/report.dart';
import '../services/report_local_service.dart';

/// Report photo that works offline and online ("Hybrid Shield"):
/// the local file is preferred while it still exists, otherwise the cached
/// cloud copy is used, and only when neither is available does it show a
/// placeholder.
///
/// Used by the History card (square thumbnail) and by the Report detail screen
/// (full-width photo, `fit: BoxFit.contain`).
class ReportThumbnail extends StatelessWidget {
  const ReportThumbnail({
    super.key,
    required this.report,
    this.size,
    this.fit = BoxFit.cover,
    this.iconSize = 32,
    this.pathOverride,
    this.urlOverride,
  });

  final Report report;

  /// Square edge length. `null` lets the image fill its parent (detail view).
  final double? size;

  final BoxFit fit;
  final double iconSize;

  /// Media source overrides. Default (null) reads the report's own photo;
  /// the detail screen passes the TL's rejection proof paths/urls so that
  /// media resolves through the same Hybrid-Shield logic.
  final String? pathOverride;
  final String? urlOverride;

  @override
  Widget build(BuildContext context) {
    final media = ReportLocalService.resolveMedia(
      pathOverride ?? report.photoPath,
      urlOverride ?? report.photoUrl,
    );
    switch (media.origin) {
      case MediaOrigin.localFile:
        return Image.file(
          File(media.location),
          width: size,
          height: size,
          fit: fit,
          errorBuilder: (context, error, stackTrace) =>
              _placeholder(Icons.broken_image),
        );
      case MediaOrigin.network:
        return CachedNetworkImage(
          imageUrl: media.location,
          width: size,
          height: size,
          fit: fit,
          placeholder: (context, url) =>
              _placeholder(Icons.image_not_supported, loading: true),
          errorWidget: (context, url, error) =>
              _placeholder(Icons.broken_image),
        );
      case MediaOrigin.none:
        return _placeholder(Icons.image_not_supported, loading: true);
    }
  }

  /// Same visual contract as the original inline thumbnail: a soft grey tile
  /// with a status icon.
  Widget _placeholder(IconData icon, {bool loading = false}) => Container(
    width: size,
    height: size,
    color: loading ? Colors.grey.shade200 : Colors.grey.shade300,
    child: Icon(icon, size: iconSize),
  );
}
