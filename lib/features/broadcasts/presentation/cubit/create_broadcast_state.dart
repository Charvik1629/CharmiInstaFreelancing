part of 'create_broadcast_cubit.dart';

enum CreateStatus { idle, submitting, success, failure }

class CreateBroadcastState extends Equatable {
  const CreateBroadcastState({
    this.name = '',
    this.results = const [],
    this.selected = const [],
    this.searching = false,
    this.status = CreateStatus.idle,
    this.errorMessage,
    this.created,
  });

  final String name;
  final List<User> results;
  final List<User> selected;
  final bool searching;
  final CreateStatus status;
  final String? errorMessage;
  final BroadcastDetail? created;

  bool get isSubmitting => status == CreateStatus.submitting;
  bool get canSubmit =>
      name.trim().isNotEmpty && selected.isNotEmpty && !isSubmitting;

  CreateBroadcastState copyWith({
    String? name,
    List<User>? results,
    List<User>? selected,
    bool? searching,
    CreateStatus? status,
    String? errorMessage,
    bool clearError = false,
    BroadcastDetail? created,
  }) {
    return CreateBroadcastState(
      name: name ?? this.name,
      results: results ?? this.results,
      selected: selected ?? this.selected,
      searching: searching ?? this.searching,
      status: status ?? this.status,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      created: created ?? this.created,
    );
  }

  @override
  List<Object?> get props =>
      [name, results, selected, searching, status, errorMessage, created];
}
