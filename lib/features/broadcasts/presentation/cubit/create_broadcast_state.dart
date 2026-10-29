part of 'create_broadcast_cubit.dart';

enum CreateStatus { idle, submitting, success, failure }

class CreateBroadcastState extends Equatable {
  const CreateBroadcastState({
    this.name = '',
    this.description = '',
    this.results = const [],
    this.selected = const [],
    this.searching = false,
    this.status = CreateStatus.idle,
    this.errorMessage,
    this.insufficientCredits = false,
    this.created,
  });

  final String name;
  final String description;
  final List<User> results;
  final List<User> selected;
  final bool searching;
  final CreateStatus status;
  final String? errorMessage;

  /// True when the last submit failed with a 402 (free-list limit reached /
  /// not enough credits) — the page shows the overage prompt.
  final bool insufficientCredits;
  final BroadcastDetail? created;

  bool get isSubmitting => status == CreateStatus.submitting;

  /// Members are optional at creation (they can be added later), so the group
  /// only needs a name before it can be created.
  bool get canSubmit => name.trim().isNotEmpty && !isSubmitting;

  CreateBroadcastState copyWith({
    String? name,
    String? description,
    List<User>? results,
    List<User>? selected,
    bool? searching,
    CreateStatus? status,
    String? errorMessage,
    bool clearError = false,
    bool insufficientCredits = false,
    BroadcastDetail? created,
  }) {
    return CreateBroadcastState(
      name: name ?? this.name,
      description: description ?? this.description,
      results: results ?? this.results,
      selected: selected ?? this.selected,
      searching: searching ?? this.searching,
      status: status ?? this.status,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      insufficientCredits: insufficientCredits,
      created: created ?? this.created,
    );
  }

  @override
  List<Object?> get props => [
        name,
        description,
        results,
        selected,
        searching,
        status,
        errorMessage,
        insufficientCredits,
        created,
      ];
}
