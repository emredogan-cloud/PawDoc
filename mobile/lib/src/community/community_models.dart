import '../core/geohash.dart';
import '../walks/places_service.dart' show haversineMeters;

/// Paw Community models (Next Evolution Phase 6). A profile row IS the
/// opt-in; the only location-shaped field is a 5-char geohash cell.
class CommunityProfile {
  const CommunityProfile({
    required this.userId,
    required this.displayName,
    this.bio,
    this.speciesTags = const [],
    this.geohash,
    this.isDiscoverable = true,
    this.allowRequests = true,
  });

  final String userId;
  final String displayName;
  final String? bio;
  final List<String> speciesTags;
  final String? geohash;
  final bool isDiscoverable;
  final bool allowRequests;

  factory CommunityProfile.fromJson(Map<String, dynamic> json) =>
      CommunityProfile(
        userId: json['user_id'] as String,
        displayName: json['display_name'] as String,
        bio: json['bio'] as String?,
        speciesTags:
            ((json['species_tags'] as List?) ?? const []).cast<String>(),
        geohash: json['geohash'] as String?,
        isDiscoverable: json['is_discoverable'] as bool? ?? true,
        allowRequests: json['allow_requests'] as bool? ?? true,
      );

  Map<String, dynamic> toColumns() => {
        'display_name': displayName,
        'bio': bio,
        'species_tags': speciesTags,
        'geohash': geohash,
        'is_discoverable': isDiscoverable,
        'allow_requests': allowRequests,
      };
}

enum ConnectionStatus { pending, accepted, declined, blocked }

ConnectionStatus connectionStatusFrom(String raw) => switch (raw) {
      'accepted' => ConnectionStatus.accepted,
      'declined' => ConnectionStatus.declined,
      'blocked' => ConnectionStatus.blocked,
      _ => ConnectionStatus.pending,
    };

class CommunityConnection {
  const CommunityConnection({
    required this.id,
    required this.requesterId,
    required this.addresseeId,
    required this.status,
    this.createdAt,
  });

  final String id;
  final String requesterId;
  final String addresseeId;
  final ConnectionStatus status;
  final DateTime? createdAt;

  factory CommunityConnection.fromJson(Map<String, dynamic> json) =>
      CommunityConnection(
        id: json['id'] as String,
        requesterId: json['requester_id'] as String,
        addresseeId: json['addressee_id'] as String,
        status: connectionStatusFrom(json['status'] as String),
        createdAt: json['created_at'] == null
            ? null
            : DateTime.parse(json['created_at'] as String),
      );

  bool involves(String userId) =>
      requesterId == userId || addresseeId == userId;

  String otherParty(String userId) =>
      requesterId == userId ? addresseeId : requesterId;

  bool isIncomingFor(String userId) =>
      addresseeId == userId && status == ConnectionStatus.pending;

  bool isOutgoingFor(String userId) =>
      requesterId == userId && status == ConnectionStatus.pending;
}

class CommunityMessage {
  const CommunityMessage({
    this.id,
    required this.connectionId,
    required this.senderId,
    required this.content,
    this.createdAt,
  });

  final String? id;
  final String connectionId;
  final String senderId;
  final String content;
  final DateTime? createdAt;

  factory CommunityMessage.fromJson(Map<String, dynamic> json) =>
      CommunityMessage(
        id: json['id'] as String?,
        connectionId: json['connection_id'] as String,
        senderId: json['sender_id'] as String,
        content: json['content'] as String,
        createdAt: json['created_at'] == null
            ? null
            : DateTime.parse(json['created_at'] as String),
      );
}

enum ProposalStatus { pending, accepted, declined }

class WalkProposal {
  const WalkProposal({
    this.id,
    required this.connectionId,
    required this.proposerId,
    required this.placeName,
    this.note,
    required this.proposedAt,
    this.status = ProposalStatus.pending,
    this.createdAt,
  });

  final String? id;
  final String connectionId;
  final String proposerId;
  final String placeName;
  final String? note;
  final DateTime proposedAt;
  final ProposalStatus status;
  final DateTime? createdAt;

  factory WalkProposal.fromJson(Map<String, dynamic> json) => WalkProposal(
        id: json['id'] as String?,
        connectionId: json['connection_id'] as String,
        proposerId: json['proposer_id'] as String,
        placeName: json['place_name'] as String,
        note: json['note'] as String?,
        proposedAt: DateTime.parse(json['proposed_at'] as String),
        status: switch (json['status'] as String? ?? 'pending') {
          'accepted' => ProposalStatus.accepted,
          'declined' => ProposalStatus.declined,
          _ => ProposalStatus.pending,
        },
        createdAt: json['created_at'] == null
            ? null
            : DateTime.parse(json['created_at'] as String),
      );
}

const List<String> kReportReasons = [
  'spam',
  'harassment',
  'inappropriate',
  'other',
];

/// Approximate distance between two geohash CELLS ("~2 km" honesty: we never
/// have real positions, only cell centers). Pure.
String approxDistanceLabel(String? mine, String? theirs) {
  if (mine == null || theirs == null) return '';
  if (mine == theirs) return 'Very close by';
  try {
    final (lat1, lon1) = geohashDecodeCenter(mine);
    final (lat2, lon2) = geohashDecodeCenter(theirs);
    final km = haversineMeters(lat1, lon1, lat2, lon2) / 1000;
    if (km < 1.5) return 'Under ~2 km';
    return '~${km.round()} km away';
  } catch (_) {
    return '';
  }
}

/// One row in the merged chat timeline (messages + walk proposals by time).
sealed class ChatTimelineItem {
  const ChatTimelineItem(this.at);
  final DateTime at;
}

class MessageItem extends ChatTimelineItem {
  MessageItem(this.message) : super(message.createdAt ?? DateTime.now());
  final CommunityMessage message;
}

class ProposalItem extends ChatTimelineItem {
  ProposalItem(this.proposal) : super(proposal.createdAt ?? DateTime.now());
  final WalkProposal proposal;
}

/// Merge messages + proposals chronologically (oldest first). Pure.
List<ChatTimelineItem> mergeTimeline(
  List<CommunityMessage> messages,
  List<WalkProposal> proposals,
) {
  final items = <ChatTimelineItem>[
    for (final m in messages) MessageItem(m),
    for (final p in proposals) ProposalItem(p),
  ]..sort((a, b) => a.at.compareTo(b.at));
  return items;
}
