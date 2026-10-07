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

CommunityFeedItem parseCommunityFeedItem(Map<String, dynamic> json) {
  final type = (json['itemType']?.toString() ?? '').toUpperCase();
  if (type == CommunityFeedItemTypes.businessOffer) {
    final raw = json['businessOffer'];
    if (raw is Map) {
      return BusinessOfferFeedItem(
        CremaBusinessOffer.fromJson(Map<String, dynamic>.from(raw)),
      );
    }
  }
  // COMMUNITY_POST (wrapped) or legacy flat WallPostResponse.
  final postRaw = json['post'];
  if (postRaw is Map) {
    return CommunityPostFeedItem(
      WallPostModel.fromJson(Map<String, dynamic>.from(postRaw)),
    );
  }
  return CommunityPostFeedItem(WallPostModel.fromJson(json));
}