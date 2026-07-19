import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

/// Optional profile-photo uploader: picks an image via [ImagePicker], uploads
/// it through [uploadPhoto] (Cloud Storage), and only reports the resulting
/// download URL back via [onPhotoSelected] once the upload succeeds.
class UploadProfileWidget extends StatefulWidget {
  const UploadProfileWidget({
    super.key,
    required this.photoPath,
    required this.onPhotoSelected,
    required this.onPhotoRemoved,
    required this.uploadPhoto,
  });

  final String? photoPath;
  final ValueChanged<String> onPhotoSelected;
  final VoidCallback onPhotoRemoved;
  final Future<String> Function(Uint8List bytes, String fileName) uploadPhoto;

  @override
  State<UploadProfileWidget> createState() => _UploadProfileWidgetState();
}

class _UploadProfileWidgetState extends State<UploadProfileWidget> {
  bool _uploading = false;

  bool get _hasPhoto =>
      widget.photoPath != null && widget.photoPath!.isNotEmpty;

  Future<void> _onPick() async {
    final XFile? picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (picked == null) return;

    setState(() => _uploading = true);
    try {
      final bytes = await picked.readAsBytes();
      final url = await widget.uploadPhoto(bytes, picked.name);
      widget.onPhotoSelected(url);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not upload photo: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
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
          ProfilePhotoPreview(photoPath: widget.photoPath, size: 56),
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
                  _uploading
                      ? 'Uploading…'
                      : _hasPhoto
                          ? 'Photo added'
                          : 'Optional — add a photo',
                  style: text.bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          if (_uploading)
            const Padding(
              padding: EdgeInsets.all(8),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else if (_hasPhoto)
            TextButton.icon(
              onPressed: widget.onPhotoRemoved,
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

  /// [photoPath] is always a Cloud Storage download URL by the time it
  /// reaches here — the upload happens before [UploadProfileWidget] reports
  /// the path back — so this only ever needs [Image.network].
  Widget _buildPhoto(BuildContext context, ColorScheme scheme) {
    Widget fallback(_, _, _) => Icon(
          Icons.person_rounded,
          color: scheme.primary,
          size: size * 0.42,
        );

    return Image.network(
      photoPath!,
      width: size,
      height: size,
      fit: BoxFit.cover,
      errorBuilder: fallback,
    );
  }
}
