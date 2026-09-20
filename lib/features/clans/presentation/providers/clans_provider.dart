import 'package:flutter_riverpod/flutter_riverpod.dart';

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
