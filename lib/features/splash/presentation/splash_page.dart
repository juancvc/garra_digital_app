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
    this.settle = const Duration(milliseconds: 280),
  });

  final FirstLaunchExperienceService? intro;
  final Future<bool> Function()? hasSession;
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
    context.go(authed ? '/home' : '/login');
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(GarraColors.background),
      body: Center(child: GarraPumaCrest(size: 96)),
    );
  }
}
