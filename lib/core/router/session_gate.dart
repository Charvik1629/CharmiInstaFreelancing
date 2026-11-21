import '../models/user.dart';
import 'app_routes.dart';

/// Session restrictions apply on login, deep links, resume and profile updates.
String? sessionGate(
  User? user,
  String location, {
  bool editingAllowed = false,
}) {
  if (user?.isRejected == true) {
    return location == AppRoutes.pendingApproval
        ? null
        : AppRoutes.pendingApproval;
  }
  if (user?.needsBusinessDetails == true &&
      location != AppRoutes.businessDetails) {
    return AppRoutes.businessDetails;
  }
  if (location == AppRoutes.createPost &&
      !(user?.canPost ?? false) &&
      !editingAllowed) {
    return AppRoutes.feed;
  }
  const communicationRoutes = {
    AppRoutes.chatThread, AppRoutes.contactInfo, AppRoutes.enterPin,
    AppRoutes.manageLabels, AppRoutes.starredMessages, AppRoutes.groups,
    AppRoutes.createGroup, AppRoutes.groupDetail, AppRoutes.broadcastsList,
    AppRoutes.createBroadcast, AppRoutes.broadcastDetail, AppRoutes.contactSync,
  };
  if (communicationRoutes.contains(location) && user?.canChat == false) {
    return AppRoutes.feed;
  }
  if (location == AppRoutes.offers && user?.canOffer == false) {
    return AppRoutes.feed;
  }

  return null;
}
