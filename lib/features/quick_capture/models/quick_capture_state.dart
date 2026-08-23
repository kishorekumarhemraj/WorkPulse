import 'package:equatable/equatable.dart';

class QuickCaptureState extends Equatable {
  final String query;
  final int selectedIndex;
  final String? selectedProjectId;
  final String? selectedCategoryId;
  final List<String> selectedTagIds;
  final List<String> selectedPeopleIds;

  const QuickCaptureState({
    this.query = '',
    this.selectedIndex = 0,
    this.selectedProjectId,
    this.selectedCategoryId,
    this.selectedTagIds = const [],
    this.selectedPeopleIds = const [],
  });

  QuickCaptureState copyWith({
    String? query,
    int? selectedIndex,
    String? selectedProjectId,
    bool clearProjectId = false,
    String? selectedCategoryId,
    bool clearCategoryId = false,
    List<String>? selectedTagIds,
    List<String>? selectedPeopleIds,
  }) {
    return QuickCaptureState(
      query: query ?? this.query,
      selectedIndex: selectedIndex ?? this.selectedIndex,
      selectedProjectId:
          clearProjectId ? null : (selectedProjectId ?? this.selectedProjectId),
      selectedCategoryId: clearCategoryId
          ? null
          : (selectedCategoryId ?? this.selectedCategoryId),
      selectedTagIds: selectedTagIds ?? this.selectedTagIds,
      selectedPeopleIds: selectedPeopleIds ?? this.selectedPeopleIds,
    );
  }

  @override
  List<Object?> get props => [
        query,
        selectedIndex,
        selectedProjectId,
        selectedCategoryId,
        selectedTagIds,
        selectedPeopleIds,
      ];
}
