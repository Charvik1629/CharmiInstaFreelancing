part of 'create_post_cubit.dart';

enum LoadStatus { initial, loading, loaded, error }

enum SubmitStatus { idle, submitting, success, failure }

class CreatePostState extends Equatable {
  const CreatePostState({
    this.categoriesStatus = LoadStatus.initial,
    this.categories = const [],
    this.title = '',
    this.body = '',
    this.selectedTypeId,
    this.imagePaths = const [],
    this.selectedTags = const [],
    this.submitStatus = SubmitStatus.idle,
    this.errorMessage,
    this.fieldErrors = const {},
    this.editing = false,
    this.created,
  });

  final LoadStatus categoriesStatus;
  final List<PostType> categories;

  final String title;
  final String body;
  final int? selectedTypeId;

  /// Ordered list of local image paths (design: reorderable strip). The API
  /// currently accepts only one image, so the first is the cover that gets
  /// uploaded — see [coverImagePath].
  final List<String> imagePaths;

  /// Tags the user attached (from GET /tags).
  final List<Tag> selectedTags;

  final SubmitStatus submitStatus;
  final String? errorMessage;
  final Map<String, String> fieldErrors;

  /// True when the composer is editing an existing post (vs creating new).
  final bool editing;

  /// The created post, available once [submitStatus] is success.
  final Load? created;

  bool get isSubmitting => submitStatus == SubmitStatus.submitting;
  bool get hasImage => imagePaths.isNotEmpty;

  /// The single image actually uploaded today (first in the strip).
  String? get coverImagePath => imagePaths.isEmpty ? null : imagePaths.first;

  /// True while the strip holds more than the one image the API can accept.
  bool get hasExtraImages => imagePaths.length > 1;

  /// A title with real content is the only hard requirement to post.
  bool get canSubmit => title.trim().isNotEmpty && !isSubmitting;

  CreatePostState copyWith({
    LoadStatus? categoriesStatus,
    List<PostType>? categories,
    String? title,
    String? body,
    int? selectedTypeId,
    List<String>? imagePaths,
    List<Tag>? selectedTags,
    SubmitStatus? submitStatus,
    String? errorMessage,
    bool clearError = false,
    Map<String, String>? fieldErrors,
    bool? editing,
    Load? created,
  }) {
    return CreatePostState(
      categoriesStatus: categoriesStatus ?? this.categoriesStatus,
      categories: categories ?? this.categories,
      title: title ?? this.title,
      body: body ?? this.body,
      selectedTypeId: selectedTypeId ?? this.selectedTypeId,
      imagePaths: imagePaths ?? this.imagePaths,
      selectedTags: selectedTags ?? this.selectedTags,
      submitStatus: submitStatus ?? this.submitStatus,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      fieldErrors: clearError ? const {} : (fieldErrors ?? this.fieldErrors),
      editing: editing ?? this.editing,
      created: created ?? this.created,
    );
  }

  @override
  List<Object?> get props => [
        categoriesStatus,
        categories,
        title,
        body,
        selectedTypeId,
        imagePaths,
        selectedTags,
        submitStatus,
        errorMessage,
        fieldErrors,
        editing,
        created,
      ];
}
