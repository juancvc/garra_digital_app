import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/design/garra_colors.dart';
import '../../../core/design/garra_spacing.dart';
import '../../../core/widgets/garra_avatar.dart';
import '../../../core/widgets/garra_card.dart';
import '../../../core/widgets/garra_states.dart';
import '../data/community_service.dart';
import '../data/wall_post_model.dart';
import 'widgets/garra_reaction_bar.dart';

class SavedPostsPage extends StatefulWidget {
  const SavedPostsPage({super.key});

  @override
  State<SavedPostsPage> createState() => _SavedPostsPageState();
}

class _SavedPostsPageState extends State<SavedPostsPage> {
  final _service = CommunityService();
  List<WallPostModel> _posts = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final posts = await _service.listSaved();
      if (!mounted) return;
      setState(() {
        _posts = posts;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'No pudimos cargar tus guardados';
        _loading = false;
      });
    }
  }

  Future<void> _unsave(String id) async {
    await _service.unsavePost(id);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(GarraColors.charcoal),
      appBar: AppBar(title: const Text('Guardados')),
      body: RefreshIndicator(
        color: const Color(GarraColors.gold),
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? ListView(children: [GarraErrorState(message: _error!, onRetry: _load)])
                : _posts.isEmpty
                    ? ListView(
                        children: [
                          const SizedBox(height: 80),
                          GarraEmptyState(
                            title: 'Sin guardados',
                            message: 'Guarda publicaciones para volver a ellas.',
                            actionLabel: 'Ir a Comunidad',
                            onAction: () => context.go('/comunidad'),
                          ),
                        ],
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(GarraSpacing.lg),
                        itemCount: _posts.length,
                        itemBuilder: (context, i) {
                          final post = _posts[i];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: GarraSpacing.md),
                            child: GarraCard(
                              onTap: () => context.push('/muro-crema/posts/${post.id}'),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      GarraAvatar(displayName: post.fullName, size: 36),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          post.fullName,
                                          style: Theme.of(context).textTheme.titleSmall,
                                        ),
                                      ),
                                      IconButton(
                                        tooltip: 'Quitar',
                                        onPressed: () => _unsave(post.id),
                                        icon: const Icon(Icons.bookmark_remove_outlined),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(post.content, maxLines: 4, overflow: TextOverflow.ellipsis),
                                  const SizedBox(height: 8),
                                  GarraReactionBar(
                                    reactionSummary: post.reactionSummary,
                                    reactionCount: post.reactionCount,
                                    commentCount: post.commentCount,
                                    myReaction: post.myReaction,
                                  ),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: IconButton(
                                      onPressed: () => Share.share('${post.fullName}: ${post.content}'),
                                      icon: const Icon(Icons.ios_share_outlined, size: 20),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
      ),
    );
  }
}
