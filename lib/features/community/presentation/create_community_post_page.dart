import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/design/garra_colors.dart';
import '../../../core/design/garra_spacing.dart';
import '../../../core/media/media_upload_service.dart';
import '../data/community_service.dart';
import '../data/create_wall_post_request.dart';

/// Social composer V3 — Cancelar / Nueva publicación / Publicar + photo toolbar.
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
  final _media = MediaUploadService();
  final _community = CommunityService();

  final List<MediaDraft> _drafts = [];
  bool _publishing = false;
  String? _error;

  bool get _isMatchScoped =>
      widget.matchId != null && widget.matchId!.isNotEmpty;

  @override
  void dispose() {
    _content.dispose();
    super.dispose();
  }

  Future<void> _pickPhotos() async {
    if (_drafts.length >= 4) return;
    setState(() => _error = null);
    try {
      final remaining = 4 - _drafts.length;
      final files = await _media.pickMultiImage(max: remaining);
      for (final file in files) {
        if (_drafts.length >= 4) break;
        late MediaDraft draft;
        draft = await _media.uploadFile(
          file: file,
          purpose: MediaUploadPurpose.communityPost,
          onUpdate: (d) {
            draft = d;
            if (!mounted) return;
            final idx = _drafts.indexWhere((x) => x.localId == d.localId);
            setState(() {
              if (idx >= 0) {
                _drafts[idx] = d;
              } else if (!_drafts.any((x) => x.localId == d.localId)) {
                _drafts.add(d);
              }
            });
          },
        );
        if (!mounted) return;
        setState(() {
          final idx = _drafts.indexWhere((x) => x.localId == draft.localId);
          if (idx >= 0) {
            _drafts[idx] = draft;
          } else {
            _drafts.add(draft);
          }
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'No pudimos cargar las fotos.');
    }
  }

  Future<void> _retry(MediaDraft draft) async {
    if (draft.localPath == null) return;
    final uploaded = await _media.uploadFile(
      file: XFile(draft.localPath!),
      purpose: MediaUploadPurpose.communityPost,
      onUpdate: (d) {
        if (!mounted) return;
        final idx = _drafts.indexWhere((x) => x.localId == draft.localId);
        if (idx >= 0) setState(() => _drafts[idx] = d);
      },
    );
    final idx = _drafts.indexWhere((d) => d.localId == draft.localId);
    if (idx >= 0 && mounted) {
      setState(() => _drafts[idx] = uploaded);
    }
  }

  Future<void> _publish() async {
    final text = _content.text.trim();
    if (text.isEmpty) {
      setState(() => _error = 'Escribe algo para compartir');
      return;
    }
    if (_drafts.any((d) => d.state == MediaUploadState.uploading)) {
      setState(() => _error = 'Espera a que terminen las fotos');
      return;
    }
    if (_drafts.any((d) => d.state == MediaUploadState.failed)) {
      setState(() => _error = 'Hay fotos con error. Reintenta o quítalas.');
      return;
    }
    final readyIds = _drafts
        .where((d) => d.isReady)
        .map((d) => d.assetId!)
        .toList();

    setState(() {
      _publishing = true;
      _error = null;
    });
    try {
      if (_isMatchScoped) {
        await _community.createPost(
          CreateWallPostRequest(
            matchId: widget.matchId!,
            content: text,
            locationTag: 'HOME',
            mediaAssetId: readyIds.isEmpty ? null : readyIds.first,
          ),
        );
      } else {
        final result = await _community.createGlobalPost(
          content: text,
          mediaAssetIds: readyIds.isEmpty ? null : readyIds,
        );
        if (!result.success) {
          throw Exception(result.message);
        }
      }
      if (!mounted) return;
      context.pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'No pudimos publicar. Intenta nuevamente.');
    } finally {
      if (mounted) setState(() => _publishing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(GarraColors.background),
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Cancelar',
          onPressed: () => context.pop(),
          icon: const Icon(Icons.close),
        ),
        title: const Text('Nueva publicación'),
        actions: [
          TextButton(
            onPressed: _publishing ? null : _publish,
            child: Text(
              _publishing ? '…' : 'Publicar',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(GarraSpacing.lg),
              child: TextField(
                controller: _content,
                maxLength: 220,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  hintText: '¿Qué está pasando en la tribuna?',
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
                  counterText: '',
                ),
              ),
            ),
          ),
          if (_drafts.isNotEmpty)
            SizedBox(
              height: 96,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: GarraSpacing.lg,
                ),
                itemCount: _drafts.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final d = _drafts[i];
                  return Stack(
                    children: [
                      Container(
                        width: 88,
                        height: 88,
                        decoration: BoxDecoration(
                          color: const Color(GarraColors.surfaceRaised),
                          borderRadius: BorderRadius.circular(12),
                          image: d.localPath != null
                              ? DecorationImage(
                                  image: FileImage(File(d.localPath!)),
                                  fit: BoxFit.cover,
                                )
                              : null,
                        ),
                        child: d.state == MediaUploadState.failed
                            ? Center(
                                child: IconButton(
                                  onPressed: () => _retry(d),
                                  icon: const Icon(Icons.refresh),
                                ),
                              )
                            : d.state == MediaUploadState.uploading
                            ? Center(
                                child: CircularProgressIndicator(
                                  value: d.progress > 0 ? d.progress : null,
                                ),
                              )
                            : null,
                      ),
                      Positioned(
                        top: 0,
                        right: 0,
                        child: IconButton(
                          iconSize: 18,
                          onPressed: () => setState(() => _drafts.removeAt(i)),
                          icon: const Icon(Icons.close),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(GarraSpacing.md),
              child: Text(
                _error!,
                style: const TextStyle(color: Color(GarraColors.danger)),
              ),
            ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(GarraSpacing.md),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Foto',
                    onPressed: _drafts.length >= 4 ? null : _pickPhotos,
                    icon: const Icon(Icons.photo_outlined),
                  ),
                  Text(
                    '${_drafts.length}/4',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const Spacer(),
                  Text(
                    '${_content.text.length}/220',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
