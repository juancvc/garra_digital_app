import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/garra_colors.dart';
import '../../../core/storage/secure_storage_service.dart';
import '../../../core/widgets/garra_puma_crest.dart';
import '../data/first_launch_experience_service.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({
    super.key,
    this.intro,
    this.hasSession,
    this.resolveDestination,
    this.settle = const Duration(milliseconds: 280),
  });

  final FirstLaunchExperienceService? intro;
  final Future<bool> Function()? hasSession;

  /// GARRA39.1: with a stored session, where to go (Garra profile pending ->
  /// /complete-profile, else /home). Not provided = plain Home.
  final Future<String> Function()? resolveDestination;
  final Duration settle;

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  late final FirstLaunchExperienceService _intro =
      widget.intro ?? FirstLaunchExperienceService();

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<bool> _session() {
    final lookup = widget.hasSession;
    if (lookup != null) return lookup();
    return SecureStorageService().hasToken();
  }

  Future<void> _boot() async {
    final seen = await _intro.hasSeenIntro();
    if (!mounted) return;
    if (!seen) {
      context.go('/intro');
      return;
    }
    if (widget.settle > Duration.zero) {
      await Future<void>.delayed(widget.settle);
    }
    if (!mounted) return;
    final authed = await _session();
    if (!mounted) return;
    if (!authed) {
      context.go('/welcome');
      return;
    }
    final lookup = widget.resolveDestination;
    final router = GoRouter.of(context);
    var destination = '/home';
    if (lookup != null) {
      try {
        destination = await lookup();
      } catch (_) {
        destination = '/home';
      }
      if (!mounted) return;
    }
    router.go(destination);
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(GarraColors.background),
      body: Center(child: GarraPumaCrest(size: 96)),
    );
  }
}
