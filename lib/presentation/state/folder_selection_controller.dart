import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Multi-selection set for folder cards on FoldersPage ([IP-0067]).
/// Empty set ≡ selection mode is OFF. Non-empty ≡ contextual appbar appears.
class FolderSelectionController extends Notifier<Set<int>> {
  @override
  Set<int> build() => const {};

  void toggle(int id) {
    final next = {...state};
    if (!next.add(id)) next.remove(id);
    state = next;
  }

  void clear() => state = const {};

  bool contains(int id) => state.contains(id);

  bool get isActive => state.isNotEmpty;
}

final folderSelectionControllerProvider =
    NotifierProvider<FolderSelectionController, Set<int>>(
  FolderSelectionController.new,
);
