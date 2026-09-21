import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/garra_colors.dart';
import '../../../core/design/garra_spacing.dart';
import '../../../core/widgets/garra_ui.dart';
import '../../marketplace/data/marketplace_media_service.dart';
import '../data/community_service.dart';
import '../data/create_wall_post_request.dart';

/// Full-screen compose. Without [matchId] → GLOBAL (365). With matchId → MATCH wall.
class CreateCommunityPostPage extends ConsumerStatefulWidget {
  const CreateCommunityPostPage({super.key, this.matchId});

  final String? matchId;

  @override
  ConsumerState<CreateCommunityPostPage> createState() =>
      _CreateCommunityPostPageState();
}

class _CreateCommunityPostPageState
    extends ConsumerState<CreateCommunityPostPage> {
  final _content = TextEditingController();
  final _media = MarketplaceMediaService();
  final _community = CommunityService();

  ListingImageDraft? _draft;
  bool _uploading = false;
  bool _publishing = false;
  String? _error;

  bool get _isMatchScoped =>
      widget.matchId != null && widget.matchId!.isNotEmpty;

  @override
  void dispose() {
    _content.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    setState(() {
      _error = null;
      _uploading = true;
    });
    try {
      final draft = await _media.pickAndPrepareDraft();
      setState(() => _draft = draft);
      final uploaded = await _media.uploadDraft(
        draft,
        purpose: MediaUploadPurpose.communityPost,
        onProgress: (p) {
          if (!mounted) return;
          setState(() => _draft?.progress = p);
        },
      );
      if (!mounted) return;
      setState(() => _draft = uploaded);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().contains('cancel')
          ? null
          : 'No pudimos subir la foto. Inténtalo de nuevo.');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _publish() async {
    final text = _content.text.trim();
    if (text.isEmpty) {
      setState(() => _error = 'Escribe algo para compartir');
      return;
    }

    setState(() {
      _publishing = true;
      _error = null;
    });
    try {
      final result = _isMatchScoped
          ? await _community.createPost(
              CreateWallPostRequest(
                matchId: widget.matchId!,
                content: text,
                locationTag: 'HOME',
                mediaAssetId:
                    _draft?.isReady == true ? _draft!.assetId : null,
              ),
            )
          : await _community.createGlobalPost(
              content: text,
              mediaAssetId: _draft?.isReady == true ? _draft!.assetId : null,
              locationTag: 'HOME',
            );
      if (!mounted) return;
      if (!result.success) {
        setState(() => _error = result.message);
        return;
      }
      context.pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'No se pudo publicar');
    } finally {
      if (mounted) setState(() => _publishing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(GarraColors.charcoal),
      appBar: AppBar(
        title: Text(
          _isMatchScoped ? 'Publicación del partido' : 'Nueva publicación',
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(GarraSpacing.lg),
        children: [
          TextField(
            controller: _content,
            maxLength: 220,
            maxLines: 6,
            decoration: const InputDecoration(
              hintText: '¿Qué quieres compartir con la comunidad?',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: GarraSpacing.md),
          if (_draft?.bytes != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.memory(
                _draft!.bytes!,
                height: 180,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
          if (_uploading || (_draft != null && !(_draft!.isReady)))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: LinearProgressIndicator(
                value: _draft?.progress,
                color: const Color(GarraColors.gold),
              ),
            ),
          const SizedBox(height: GarraSpacing.sm),
          OutlinedButton.icon(
            onPressed: _uploading || _publishing ? null : _pickPhoto,
            icon: const Icon(Icons.photo_outlined),
            label: Text(
              _draft == null ? 'Agregar foto (opcional)' : 'Cambiar foto',
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: GarraSpacing.sm),
            Text(_error!, style: const TextStyle(color: Colors.orangeAccent)),
          ],
          const SizedBox(height: GarraSpacing.lg),
          GarraPrimaryButton(
            label: _publishing ? 'Publicando…' : 'Publicar',
            onPressed: _publishing || _uploading ? null : _publish,
          ),
        ],
      ),
    );
  }
}
