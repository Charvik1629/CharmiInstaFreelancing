part of 'create_group_cubit.dart';

enum CreateStatus { idle, submitting, success, failure }

class CreateGroupState extends Equatable {
  const CreateGroupState({
    this.name = '',
    this.description = '',
    this.results = const [],
    this.selected = const [],
    this.searching = false,
    this.status = CreateStatus.idle,
    this.errorMessage,
    this.created,
  });

  final String name;
  final String description;
  final List<User> results;
  final List<User> selected;
  final bool searching;
  final CreateStatus status;
  final String? errorMessage;
  final Group? created;

  bool get isSubmitting => status == CreateStatus.submitting;

  /// Members are optional (they can be added later), so a name is enough.
  bool get canSubmit => name.trim().isNotEmpty && !isSubmitting;

  CreateGroupState copyWith({
    String? name,
    String? description,
    List<User>? results,
    List<User>? selected,
    bool? searching,
    CreateStatus? status,
    String? errorMessage,
    bool clearError = false,
    Group? created,
  }) {
    return CreateGroupState(
      name: name ?? this.name,
      description: description ?? this.description,
      results: results ?? this.results,
      selected: selected ?? this.selected,
      searching: searching ?? this.searching,
      status: status ?? this.status,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
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
        created,
      ];
}
