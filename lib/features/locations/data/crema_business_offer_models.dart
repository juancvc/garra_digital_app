import 'package:flutter/foundation.dart';

/// Backend [CremaBusinessOfferStatus] — do not invent values.
enum CremaBusinessOfferStatus {
  draft,
  active,
  expired,
  cancelled;

  static CremaBusinessOfferStatus fromApi(String? raw) {
    switch ((raw ?? '').toUpperCase()) {
      case 'ACTIVE':
        return CremaBusinessOfferStatus.active;
      case 'EXPIRED':
        return CremaBusinessOfferStatus.expired;
      case 'CANCELLED':
        return CremaBusinessOfferStatus.cancelled;
      case 'DRAFT':
      default:
        return CremaBusinessOfferStatus.draft;
    }
  }

  String get apiValue => switch (this) {
        CremaBusinessOfferStatus.draft => 'DRAFT',
        CremaBusinessOfferStatus.active => 'ACTIVE',
        CremaBusinessOfferStatus.expired => 'EXPIRED',
        CremaBusinessOfferStatus.cancelled => 'CANCELLED',
      };

  /// Human chip label for supported states only.
  String get label => switch (this) {
        CremaBusinessOfferStatus.draft => 'Borrador',
        CremaBusinessOfferStatus.active => 'Activa',
        CremaBusinessOfferStatus.expired => 'Vencida',
        CremaBusinessOfferStatus.cancelled => 'Cancelada',
      };
}

@immutable
class CremaBusinessOffer {
  const CremaBusinessOffer({
    required this.id,
    required this.cremaPointId,
    required this.title,
    required this.description,
    required this.status,
    this.cremaPointName,
    this.startsAt,
    this.endsAt,
    this.imageUrl,
    this.publishedAt,
    this.createdAt,
    this.following = false,
  });

  final String id;
  final String cremaPointId;
  final String? cremaPointName;
  final String title;
  final String description;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final CremaBusinessOfferStatus status;
  final String? imageUrl;
  final DateTime? publishedAt;
  final DateTime? createdAt;
  final bool following;

  bool get isDraft => status == CremaBusinessOfferStatus.draft;
  bool get isActive => status == CremaBusinessOfferStatus.active;
  bool get isCancelled => status == CremaBusinessOfferStatus.cancelled;

  /// Derived UI hint when ACTIVE but endsAt is in the past (BE may still say ACTIVE).
  bool get vigenciaTerminada {
    if (endsAt == null) return false;
    return endsAt!.isBefore(DateTime.now().toUtc());
  }

  bool get isScheduled {
    if (!isActive || startsAt == null) return false;
    return startsAt!.isAfter(DateTime.now().toUtc());
  }

  String get statusChipLabel {
    if (isActive && vigenciaTerminada) return 'Vigencia terminada';
    if (isScheduled) return 'Programada';
    return status.label;
  }

  factory CremaBusinessOffer.fromJson(Map<String, dynamic> json) {
    DateTime? parse(dynamic v) {
      if (v == null) return null;
      return DateTime.tryParse(v.toString())?.toUtc();
    }

    final image = json['imageUrl']?.toString().trim();
    return CremaBusinessOffer(
      id: json['id']?.toString() ?? '',
      cremaPointId: json['cremaPointId']?.toString() ?? '',
      cremaPointName: json['cremaPointName']?.toString(),
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      startsAt: parse(json['startsAt']),
      endsAt: parse(json['endsAt']),
      status: CremaBusinessOfferStatus.fromApi(json['status']?.toString()),
      imageUrl: (image == null || image.isEmpty) ? null : image,
      publishedAt: parse(json['publishedAt']),
      createdAt: parse(json['createdAt']),
      following: json['following'] == true,
    );
  }
}
