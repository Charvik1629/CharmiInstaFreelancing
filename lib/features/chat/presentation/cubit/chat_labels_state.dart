part of 'chat_labels_cubit.dart';

enum LabelsStatus { initial, loading, loaded, empty, error }

class ChatLabelsState extends Equatable {
  const ChatLabelsState({
    this.status = LabelsStatus.initial,
    this.labels = const [],
    this.errorMessage,
  });

  final LabelsStatus status;
  final List<ChatLabel> labels;
  final String? errorMessage;

  ChatLabelsState copyWith({
    LabelsStatus? status,
    List<ChatLabel>? labels,
    String? errorMessage,
  }) {
    return ChatLabelsState(
      status: status ?? this.status,
      labels: labels ?? this.labels,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, labels, errorMessage];
}
