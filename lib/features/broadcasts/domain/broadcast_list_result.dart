import '../../../core/network/api_response.dart';
import '../../chat/domain/entities/broadcast_quota.dart';
import 'broadcast_detail.dart';

/// Result of GET /broadcasts: the broadcast lists, their pagination meta, and
/// (when the server includes it) the caller's `meta.broadcast_list_quota` — how
/// many broadcast lists may still be created this window.
class BroadcastListResult {
  const BroadcastListResult({
    required this.items,
    required this.meta,
    this.quota,
  });

  final List<BroadcastDetail> items;
  final PaginationMeta meta;
  final BroadcastQuota? quota;
}
