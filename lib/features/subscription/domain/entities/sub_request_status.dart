/// Filter for the admin subscription-requests queue. `.name` matches the API's
/// `?status=pending|approved|rejected`.
enum SubRequestStatus { pending, approved, rejected }

extension SubRequestStatusX on SubRequestStatus {
  String get label => switch (this) {
        SubRequestStatus.pending => 'Pending',
        SubRequestStatus.approved => 'Approved',
        SubRequestStatus.rejected => 'Rejected',
      };
}
