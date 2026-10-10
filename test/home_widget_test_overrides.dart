import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:garra_digital_app/features/football/data/garra_football_models.dart';
import 'package:garra_digital_app/features/home/presentation/home_matchday_poll_card.dart';
import 'package:garra_digital_app/features/home/presentation/providers/home_provider.dart';

/// Resolves [homeFeaturedProvider] without network and without an indeterminate
/// header progress bar (04C featured block).
const homeFeaturedStableResult = FootballFeaturedResult(unavailable: true);

homeFeaturedStableOverrides() => [
      homeFeaturedProvider.overrideWith((ref) async => homeFeaturedStableResult),
      homeMatchdayPollProvider.overrideWith((ref, key) async => null),
    ];
