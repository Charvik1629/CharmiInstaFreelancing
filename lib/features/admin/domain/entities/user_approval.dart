/// Super-admin review state for a signup. `.name` matches the API's
/// `?status=pending|approved|rejected` query and `approval_status` field.
enum UserApprovalStatus { pending, approved, rejected }

extension UserApprovalStatusX on UserApprovalStatus {
  String get label => switch (this) {
        UserApprovalStatus.pending => 'Pending',
        UserApprovalStatus.approved => 'Approved',
        UserApprovalStatus.rejected => 'Rejected',
      };
}
