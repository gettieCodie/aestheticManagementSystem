import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

/// Optional profile-photo uploader backed by [ImagePicker].
class UploadProfileWidget extends StatelessWidget {
  const UploadProfileWidget({
    super.key,
    required this.photoPath,
    required this.onPhotoSelected,
    required this.onPhotoRemoved,
  });

  final String? photoPath;
  final ValueChanged<String> onPhotoSelected;
  final VoidCallback onPhotoRemoved;

  bool get _hasPhoto => photoPath != null && photoPath!.isNotEmpty;

  Future<void> _onPick() async {
    final XFile? picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (picked != null) {
      onPhotoSelected(picked.path);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        children: [
          ProfilePhotoPreview(photoPath: photoPath, size: 56),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Profile photo',
                  style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  _hasPhoto ? 'Photo added' : 'Optional — add a photo',
                  style: text.bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          if (_hasPhoto)
            TextButton.icon(
              onPressed: onPhotoRemoved,
              icon: const Icon(Icons.delete_outline_rounded, size: 18),
              label: const Text('Remove'),
            )
          else
            FilledButton.tonalIcon(
              onPressed: _onPick,
              icon: const Icon(Icons.upload_rounded, size: 18),
              label: const Text('Upload'),
            ),
        ],
      ),
    );
  }
}

/// Circular preview of the selected photo (or a fallback avatar icon).
class ProfilePhotoPreview extends StatelessWidget {
  const ProfilePhotoPreview({
    super.key,
    required this.photoPath,
    this.size = 56,
  });

  final String? photoPath;
  final double size;

  bool get _hasPhoto => photoPath != null && photoPath!.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      height: size,
      width: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: scheme.primaryContainer.withValues(alpha: 0.5),
        border: Border.all(color: scheme.outlineVariant),
      ),
      alignment: Alignment.center,
      clipBehavior: Clip.antiAlias,
      child: _hasPhoto
          ? ClipOval(
              child: _buildPhoto(context, scheme),
            )
          : Icon(
              Icons.add_a_photo_outlined,
              color: scheme.primary,
              size: size * 0.42,
            ),
    );
  }

  /// image_picker returns a browser blob URL on web (use [Image.network]) and a
  /// filesystem path on native platforms (use [Image.file]).
  Widget _buildPhoto(BuildContext context, ColorScheme scheme) {
    Widget fallback(_, _, _) => Icon(
          Icons.person_rounded,
          color: scheme.primary,
          size: size * 0.42,
        );

    if (kIsWeb) {
      return Image.network(
        photoPath!,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: fallback,
      );
    }
    return Image.file(
      File(photoPath!),
      width: size,
      height: size,
      fit: BoxFit.cover,
      errorBuilder: fallback,
    );
  }
}
