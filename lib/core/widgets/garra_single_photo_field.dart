import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../design/garra_radius.dart';
import '../design/garra_spacing.dart';
import '../media/media_upload_service.dart';
import '../theme/garra_semantic_colors.dart';
import 'garra_cached_network_image.dart';

/// UX_08: exactly ONE optional image for a form (Garra Solidaria, Eventos,
/// Emprendimiento). The parent owns the selected [file]; this widget only
/// renders pick / preview / change / remove. Upload happens on submit via
/// [uploadSinglePhoto] (existing signed-upload media pipeline).
class GarraSinglePhotoField extends StatelessWidget {
  const GarraSinglePhotoField({
    super.key,
    required this.file,
    required this.onPick,
    required this.onRemove,
    this.label = 'Foto (opcional)',
    this.helper = 'Puedes agregar una sola foto.',
    this.enabled = true,
    this.aspectRatio = 16 / 9,
    this.previewMaxWidth,
    this.currentUrl,
    this.addLabel = 'Agregar foto',
  });

  final XFile? file;
  final VoidCallback onPick;
  final VoidCallback onRemove;
  final String label;
  final String helper;
  final bool enabled;

  /// Preview shape (16:9 by default; 1 for a square avatar).
  final double aspectRatio;

  /// Optional cap for the preview width (e.g. a compact avatar preview).
  final double? previewMaxWidth;

  /// Already-saved image shown when no new [file] is selected (edit flows).
  final String? currentUrl;
  final String addLabel;

  @override
  Widget build(BuildContext context) {
    final colors = context.garraColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isDark ? colors.brandPrestige : colors.brandPrimary;
    final textTheme = Theme.of(context).textTheme;
    final selected = file;
    final saved = currentUrl?.trim() ?? '';
    final hasImage = selected != null || saved.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.only(bottom: GarraSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            label,
            style: textTheme.labelLarge?.copyWith(
              color: colors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: GarraSpacing.xs),
          Text(
            helper,
            style: textTheme.bodySmall?.copyWith(color: colors.textSecondary),
          ),
          const SizedBox(height: GarraSpacing.sm),
          if (!hasImage)
            OutlinedButton.icon(
              key: const ValueKey('single_photo_add'),
              onPressed: enabled ? onPick : null,
              icon: Icon(Icons.add_photo_alternate_outlined, color: accent),
              label: Text(
                addLabel,
                style: TextStyle(color: colors.textPrimary),
              ),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                side: BorderSide(color: colors.border),
                backgroundColor: colors.surfaceRaised,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(GarraRadius.md),
                ),
              ),
            )
          else ...[
            Align(
              alignment: Alignment.centerLeft,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: previewMaxWidth ?? double.infinity,
                ),
                child: ClipRRect(
                  key: const ValueKey('single_photo_preview'),
                  borderRadius: BorderRadius.circular(GarraRadius.md),
                  child: AspectRatio(
                    aspectRatio: aspectRatio,
                    child: ColoredBox(
                      color: colors.surfaceMuted,
                      child: selected != null
                          ? Image.file(
                              File(selected.path),
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => _broken(colors),
                            )
                          : GarraCachedNetworkImage(
                              imageUrl: saved,
                              fit: BoxFit.cover,
                              errorWidget: _broken(colors),
                            ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: GarraSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: TextButton.icon(
                    key: const ValueKey('single_photo_change'),
                    onPressed: enabled ? onPick : null,
                    icon: Icon(Icons.swap_horiz_rounded, color: accent),
                    label: Text(
                      'Cambiar',
                      style: TextStyle(color: colors.textPrimary),
                    ),
                  ),
                ),
                Expanded(
                  child: TextButton.icon(
                    key: const ValueKey('single_photo_remove'),
                    onPressed: enabled ? onRemove : null,
                    icon: Icon(Icons.delete_outline, color: colors.danger),
                    label: Text(
                      'Quitar',
                      style: TextStyle(color: colors.textPrimary),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  static Widget _broken(GarraSemanticColors colors) => Center(
    child: Icon(Icons.image_outlined, size: 40, color: colors.textSecondary),
  );
}

/// Uploads the single selected photo through the existing media pipeline and
/// returns its READY asset id. Throws [SinglePhotoUploadException] (Spanish
/// message) when the upload fails, so the form can keep the user's data.
Future<String> uploadSinglePhoto(
  MediaUploadService media,
  XFile file,
  MediaUploadPurpose purpose,
  {bool Function()? canStartRemote}
) async {
  final draft = await media.uploadFile(file: file, purpose: purpose, canStartRemote: canStartRemote);
  if (!draft.isReady) {
    throw SinglePhotoUploadException(
      draft.error ?? MediaUploadService.uploadFailedMessage,
    );
  }
  return draft.assetId!;
}

class SinglePhotoUploadException implements Exception {
  SinglePhotoUploadException(this.message);
  final String message;

  @override
  String toString() => message;
}
