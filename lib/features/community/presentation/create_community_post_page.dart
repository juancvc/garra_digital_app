import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/garra_colors.dart';
import '../../../core/design/garra_spacing.dart';
import '../../../core/widgets/garra_ui.dart';
import '../../marketplace/data/marketplace_media_service.dart';
import '../data/community_service.dart';
import '../data/create_wall_post_request.dart';

/// Full-screen compose surface for community posts (optional photo via R2).
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
    var matchId = widget.matchId;
    if (matchId == null || matchId.isEmpty) {
      final status = await _community.getCurrentWallStatus();
      matchId = status?.matchId;
    }
    if (matchId == null || matchId.isEmpty) {
      setState(() => _error = 'No hay muro abierto ahora. Vuelve en día de partido.');
      return;
    }

    setState(() {
      _publishing = true;
      _error = null;
    });
    try {
      final result = await _community.createPost(
        CreateWallPostRequest(
          matchId: matchId,
          content: text,
          locationTag: 'HOME',
          mediaAssetId: _draft?.isReady == true ? _draft!.assetId : null,
        ),
      );
      if (!mounted) return;
      if (!result.success) {
        setState(() => _error = result.message);
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Publicación creada')),
      );
      context.pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'No pudimos publicar. Inténtalo de nuevo.');
    } finally {
      if (mounted) setState(() => _publishing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bytes = _draft?.bytes;
    return Scaffold(
      backgroundColor: const Color(GarraColors.charcoal),
      appBar: AppBar(
        title: const Text('Nueva publicación'),
        backgroundColor: const Color(GarraColors.charcoal),
      ),
      body: ListView(
        padding: const EdgeInsets.all(GarraSpacing.lg),
        children: [
          TextField(
            controller: _content,
            maxLength: 220,
            maxLines: 5,
            decoration: const InputDecoration(
              hintText: '¿Qué quieres compartir con la comunidad?',
              filled: true,
            ),
          ),
          const SizedBox(height: GarraSpacing.lg),
          if (bytes != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.memory(
                bytes,
                height: 220,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
          if (_draft != null && _draft!.state == ListingImageUploadState.uploading)
            Padding(
              padding: const EdgeInsets.only(top: GarraSpacing.sm),
              child: LinearProgressIndicator(value: _draft!.progress),
            ),
          const SizedBox(height: GarraSpacing.md),
          OutlinedButton.icon(
            onPressed: _uploading ? null : _pickPhoto,
            icon: const Icon(Icons.photo_outlined),
            label: Text(_draft == null ? 'Agregar foto' : 'Cambiar foto'),
          ),
          if (_error != null) ...[
            const SizedBox(height: GarraSpacing.md),
            Text(_error!, style: const TextStyle(color: Color(GarraColors.danger))),
          ],
          const SizedBox(height: GarraSpacing.xxl),
          GarraPrimaryButton(
            label: _publishing ? 'Publicando…' : 'Publicar',
            onPressed: (_publishing || _uploading) ? null : _publish,
          ),
        ],
      ),
    );
  }
}
