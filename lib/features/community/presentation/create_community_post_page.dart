import 'dart:io';

import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/design/garra_colors.dart';
import '../../../core/design/garra_spacing.dart';
import '../../../core/theme/garra_semantic_colors.dart';
import '../../../core/media/media_upload_service.dart';
import '../../../core/network/offline_action_guard.dart';
import '../data/community_service.dart';
import '../data/create_wall_post_request.dart';

/// Social composer V3 — Cancelar / Nueva publicación / Publicar + photo toolbar.
class CreateCommunityPostPage extends ConsumerStatefulWidget {
  const CreateCommunityPostPage({
    super.key,
    this.matchId,
    this.media,
    this.communityService,
  });

  final String? matchId;
  final MediaUploadService? media;
  final CommunityService? communityService;

  @override
  ConsumerState<CreateCommunityPostPage> createState() =>
      _CreateCommunityPostPageState();
}

class _CreateCommunityPostPageState
    extends ConsumerState<CreateCommunityPostPage> {
  final _content = TextEditingController();
  late final MediaUploadService _media = widget.media ?? MediaUploadService();
  late final CommunityService _community =
      widget.communityService ?? CommunityService();

  final List<MediaDraft> _drafts = [];
  final CancelToken _uploadCancelToken = CancelToken();
  bool _publishing = false;
  String? _error;

  bool get _isMatchScoped =>
      widget.matchId != null && widget.matchId!.isNotEmpty;

  int get _photoLimit =>
      _isMatchScoped ? 1 : MediaUploadService.communityPhotoLimit;

  @override
  void dispose() {
    _uploadCancelToken.cancel();
    _content.dispose();
    super.dispose();
  }

  Future<void> _pickPhotos(ImageSource source) async {
    if (_drafts.length >= _photoLimit) return;
    setState(() => _error = null);
    try {
      final remaining = _photoLimit - _drafts.length;
      final files = source == ImageSource.camera
          ? <XFile>[?await _media.pickCamera()]
          : _isMatchScoped
          ? <XFile>[?await _media.pickImage()]
          : await _media.pickMultiImage(max: remaining);
      for (var index = 0; index < files.length; index++) {
        if (_drafts.length >= _photoLimit) break;
        if (!mounted) return;
        if (!allowNetworkAction(context)) {
          setState(() {
            for (final selected in files.skip(index)) {
              if (_drafts.length >= _photoLimit) break;
              _drafts.add(
                MediaDraft(
                  localId: selected.path,
                  localPath: selected.path,
                  state: MediaUploadState.failed,
                ),
              );
            }
          });
          return;
        }
        final file = files[index];
        late MediaDraft draft;
        draft = await _media.uploadFile(
          file: file,
          purpose: MediaUploadPurpose.communityPost,
          canStartRemote: () => mounted && allowNetworkAction(context),
          cancelToken: _uploadCancelToken,
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

  Future<void> _choosePhotoSource() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Elegir de galería'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Tomar foto'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    await _pickPhotos(source);
  }

  Future<void> _retry(MediaDraft draft) async {
    if (!allowNetworkAction(context)) return;
    if (draft.localPath == null) return;
    final uploaded = await _media.uploadFile(
      file: XFile(draft.localPath!),
      purpose: MediaUploadPurpose.communityPost,
      canStartRemote: () => mounted && allowNetworkAction(context),
      cancelToken: _uploadCancelToken,
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
    if (!allowNetworkAction(context)) return;
    final text = _content.text.trim();
    if (text.isEmpty) {
      setState(() => _error = 'Escribe algo para compartir');
      return;
    }
    if (_drafts.any((d) => d.state == MediaUploadState.signing || d.state == MediaUploadState.uploading || d.state == MediaUploadState.confirming)) {
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
        final result = await _community.createPost(
          CreateWallPostRequest(
            matchId: widget.matchId!,
            content: text,
            locationTag: 'HOME',
            mediaAssetId: readyIds.isEmpty ? null : readyIds.first,
          ),
        );
        if (!result.success) {
          throw Exception(result.message);
        }
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
              height: 104,
              child: ReorderableListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: GarraSpacing.lg,
                ),
                itemCount: _drafts.length,
                onReorder: (oldIndex, newIndex) {
                  setState(() {
                    if (newIndex > oldIndex) newIndex -= 1;
                    final item = _drafts.removeAt(oldIndex);
                    _drafts.insert(newIndex, item);
                  });
                },
                itemBuilder: (context, i) {
                  final d = _drafts[i];
                  return Padding(
                    key: ValueKey(d.localId),
                    padding: const EdgeInsets.only(right: 8),
                    child: Stack(
                      children: [
                        Container(
                          width: 88,
                          height: 88,
                          decoration: BoxDecoration(
                            color: context.garraColors.surfaceRaised,
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
                            tooltip: 'Quitar foto',
                            iconSize: 18,
                            onPressed: () =>
                                setState(() => _drafts.removeAt(i)),
                            icon: const Icon(Icons.close),
                          ),
                        ),
                      ],
                    ),
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
              padding: const EdgeInsets.fromLTRB(
                GarraSpacing.md,
                GarraSpacing.sm,
                GarraSpacing.md,
                GarraSpacing.md,
              ),
              child: Row(
                children: [
                  TextButton(
                    key: const ValueKey('add-photos'),
                    onPressed: _drafts.length >= _photoLimit
                        ? null
                        : _choosePhotoSource,
                    child: Text(
                      _isMatchScoped ? 'Agregar foto' : 'Agregar fotos',
                    ),
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
