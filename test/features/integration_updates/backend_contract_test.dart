import 'package:flutter_test/flutter_test.dart';
import 'package:charmi_insta_freelancing/core/models/user.dart';
import 'package:charmi_insta_freelancing/core/models/load.dart';
import 'package:charmi_insta_freelancing/core/models/post_location.dart';
import 'package:charmi_insta_freelancing/core/router/session_gate.dart';
import 'package:charmi_insta_freelancing/core/router/app_routes.dart';
import 'package:charmi_insta_freelancing/features/chat/domain/entities/conversation.dart';
import 'package:charmi_insta_freelancing/features/chat/domain/entities/shared_content.dart';

void main() {
  User pending({bool complete = false}) => User.fromJson({
    'id': 42,
    'name': 'Example',
    'approval_status': 'pending',
    'business_details_complete': complete,
    'business_details_required_fields': ['name', 'address'],
    'business_details_missing': complete ? [] : ['address'],
    'company_type': 'Transporter',
    'address': 'Warehouse Road',
    'capabilities': {
      'can_browse': true,
      'can_chat': true,
      'can_ask': true,
      'can_offer': true,
      'can_update_business': true,
      'can_create_post': false,
    },
  });
  test('pending capabilities and business metadata survive caching/copy', () {
    final user = User.fromJson(pending().toJson()).copyWith(name: 'Updated');
    expect(user.canBrowse && user.canUpdateBusiness, isTrue);
    expect(user.canChat || user.canAsk || user.canOffer, isFalse);
    expect(user.canPost, isFalse);
    expect(user.needsBusinessDetails, isTrue);
    expect(user.businessDetailsMissing, ['address']);
    expect(user.businessDetails['company_type'], 'Transporter');
    expect(user.businessDetailsRequiredFields, ['name', 'address']);
  });
  test(
    'business gate persists across routes and releases after server completion',
    () {
      expect(sessionGate(pending(), AppRoutes.feed), AppRoutes.businessDetails);
      expect(
        sessionGate(pending(), AppRoutes.chatThread),
        AppRoutes.businessDetails,
      );
      expect(sessionGate(pending(), AppRoutes.businessDetails), isNull);
      expect(sessionGate(pending(complete: true), AppRoutes.feed), isNull);
      expect(
        sessionGate(pending(complete: true), AppRoutes.chatThread),
        AppRoutes.feed,
      );
      expect(
        sessionGate(pending(complete: true), AppRoutes.createPost),
        AppRoutes.feed,
      );
      for (final route in [AppRoutes.contactInfo, AppRoutes.groups, AppRoutes.createGroup,
          AppRoutes.broadcastsList, AppRoutes.createBroadcast, AppRoutes.contactSync, AppRoutes.offers]) {
        expect(sessionGate(pending(complete: true), route), AppRoutes.feed);
      }
      final approved = pending(complete: true).copyWith(
        approvalStatus: 'approved',
        capabilities: {'can_create_post': true},
      );
      expect(approved.canPost, isTrue);
      expect(sessionGate(approved, AppRoutes.createPost), isNull);
    },
  );
  test(
    'rejected account stays blocked despite permissive capability payload',
    () {
      final user = pending(complete: true).copyWith(approvalStatus: 'rejected');
      expect(user.canChat, isFalse);
      expect(sessionGate(user, AppRoutes.feed), AppRoutes.pendingApproval);
      expect(sessionGate(user, AppRoutes.pendingApproval), isNull);
    },
  );
  test('self-chat start envelope and list parsing suppress unread count', () {
    final conversation = Conversation.fromStartChatJson({
      'conversation_id': 99,
      'is_self': true,
      'conversation': {
        'id': 99,
        'type': 'direct',
        'unread_count': 12,
        'peer': {'id': 42, 'name': 'Example', 'business_name': 'Steel Co'},
      },
    });
    expect(conversation.isSelf, isTrue);
    expect(conversation.id, 99);
    expect(conversation.peerId, 42);
    expect(conversation.subtitle, 'Steel Co');
    expect(conversation.unreadCount, 0);
  });
  test('location zero coordinates parse and survive Load copy', () {
    final load = Load.fromJson({
      'id': 1,
      'title': 'Post',
      'location_lat': '0',
      'location_lng': 0,
      'location_label': 'Warehouse',
    });
    expect(load.location, const PostLocation(0, 0, label: 'Warehouse'));
    expect(load.copyWith(status: 'inactive').location, load.location);
    expect(
      PostLocation.fromJson({'location_lat': 91, 'location_lng': 0}),
      isNull,
    );
  });
  test('shared endpoint totals are independent of first page size', () {
    final result = SharedContent.fromResponse({
      'data': {
        'media_count': 140,
        'links_count': 62,
        'documents_count': 24,
        'items': [
          {'id': 55, 'body': 'www.example.com', 'attachments': []},
        ],
      },
      'meta': {'current_page': 1, 'last_page': 7, 'total': 140, 'per_page': 20},
    });
    expect(result.mediaCount, 140);
    expect(result.linksCount, 62);
    expect(result.documentsCount, 24);
    expect(result.items.length, 1);
    expect(result.meta.hasMore, isTrue);
  });
}
