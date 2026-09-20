import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../community/data/wall_post_model.dart';
import '../../data/clan_models.dart';
import '../../data/clan_service.dart';

final clanServiceProvider = Provider<ClanService>((ref) {
  return ClanService();
});

class ClanDiscoveryQuery {
  const ClanDiscoveryQuery({
    this.search = '',
    this.city,
    this.countryCode,
  });

  final String search;
  final String? city;
  final String? countryCode;

  @override
  bool operator ==(Object other) {
    return other is ClanDiscoveryQuery &&
        other.search == search &&
        other.city == city &&
        other.countryCode == countryCode;
  }

  @override
  int get hashCode => Object.hash(search, city, countryCode);
}

final clanDiscoveryProvider = FutureProvider.autoDispose
    .family<List<ClanModel>, ClanDiscoveryQuery>((ref, query) async {
  final page = await ref.watch(clanServiceProvider).discoverClans(
        search: query.search,
        city: query.city,
        countryCode: query.countryCode,
      );
  return page.items;
});

final myClansProvider =
    FutureProvider.autoDispose<List<MyClanMembership>>((ref) {
  return ref.watch(clanServiceProvider).getMyClans();
});

final clanDetailProvider =
    FutureProvider.autoDispose.family<ClanModel, String>((ref, slug) {
  return ref.watch(clanServiceProvider).getClan(slug);
});

final clanMembersPreviewProvider = FutureProvider.autoDispose
    .family<List<ClanMemberModel>, String>((ref, slug) async {
  final page = await ref.watch(clanServiceProvider).getMembers(slug, size: 8);
  return page.items;
});

final clanJoinRequestsProvider = FutureProvider.autoDispose
    .family<List<ClanJoinRequestModel>, String>((ref, slug) {
  return ref.watch(clanServiceProvider).getJoinRequests(slug);
});

final myClanInvitationsProvider =
    FutureProvider.autoDispose<List<ClanInvitationModel>>((ref) {
  return ref.watch(clanServiceProvider).getMyInvitations();
});

final clanFeedProvider = FutureProvider.autoDispose
    .family<List<WallPostModel>, String>((ref, slug) async {
  final page = await ref.watch(clanServiceProvider).getClanPosts(slug);
  return page.items;
});

class ClanPollaParams {
  const ClanPollaParams({required this.slug, required this.matchId});

  final String slug;
  final String matchId;

  @override
  bool operator ==(Object other) {
    return other is ClanPollaParams &&
        other.slug == slug &&
        other.matchId == matchId;
  }

  @override
  int get hashCode => Object.hash(slug, matchId);
}

final clanPollaProvider = FutureProvider.autoDispose
    .family<ClanPollaMatchModel, ClanPollaParams>((ref, params) {
  return ref
      .watch(clanServiceProvider)
      .getClanPolla(params.slug, params.matchId);
});

class ClanMemberRankingParams {
  const ClanMemberRankingParams({required this.slug, this.year});

  final String slug;
  final int? year;

  @override
  bool operator ==(Object other) {
    return other is ClanMemberRankingParams &&
        other.slug == slug &&
        other.year == year;
  }

  @override
  int get hashCode => Object.hash(slug, year);
}

final clanMemberRankingProvider = FutureProvider.autoDispose
    .family<List<ClanMemberRankingEntry>, ClanMemberRankingParams>(
        (ref, params) async {
  final page = await ref.watch(clanServiceProvider).getClanMemberRanking(
        params.slug,
        year: params.year,
      );
  return page.items;
});

final globalClanRankingProvider = FutureProvider.autoDispose
    .family<List<ClanGlobalRankingEntry>, int?>((ref, year) async {
  final page =
      await ref.watch(clanServiceProvider).getGlobalClanRanking(year: year);
  return page.items;
});
