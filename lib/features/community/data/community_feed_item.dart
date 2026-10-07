import '../../locations/data/crema_business_offer_models.dart';
import 'wall_post_model.dart';

/// Backend CommunityFeedItemResponse itemType values.
abstract final class CommunityFeedItemTypes {
  static const communityPost = 'COMMUNITY_POST';
  static const businessOffer = 'BUSINESS_OFFER';
}

sealed class CommunityFeedItem {
  const CommunityFeedItem();
}

final class CommunityPostFeedItem extends CommunityFeedItem {
  const CommunityPostFeedItem(this.post);
  final WallPostModel post;
}

final class BusinessOfferFeedItem extends CommunityFeedItem {
  const BusinessOfferFeedItem(this.offer);
  final CremaBusinessOffer offer;
}

/// Parses one `/community/feed/page` item (CommunityFeedItemResponse).
///
/// Returns null for items this client cannot render safely (malformed payload or
/// an itemType it does not know) so one bad item never blanks the whole page.
/// A flat legacy WallPostResponse (no `itemType`) is still accepted.
CommunityFeedItem? parseCommunityFeedItem(Map<String, dynamic> json) {
  final wrapped = json.containsKey('itemType');
  final type = (json['itemType']?.toString() ?? '').toUpperCase();
  if (type == CommunityFeedItemTypes.businessOffer) {
    final raw = json['businessOffer'];
    if (raw is! Map) return null;
    final offer = CremaBusinessOffer.fromJson(Map<String, dynamic>.from(raw));
    // Without both ids the card cannot open its business page.
    if (offer.id.isEmpty || offer.cremaPointId.isEmpty) return null;
    return BusinessOfferFeedItem(offer);
  }
  final postRaw = json['post'];
  if (postRaw is Map) {
    final post = WallPostModel.fromJson(Map<String, dynamic>.from(postRaw));
    return post.id.isEmpty ? null : CommunityPostFeedItem(post);
  }
  if (wrapped) return null;
  final legacy = WallPostModel.fromJson(json);
  return legacy.id.isEmpty ? null : CommunityPostFeedItem(legacy);
}