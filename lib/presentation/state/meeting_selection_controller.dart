import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Multi-selection set for meeting tiles ([IP-0068]). Shared across every
/// surface that lists meetings (FolderDetailPage, future HistoryPage, …).
/// Pages should call [clear] in their initState to start with a clean slate
/// and avoid leaking selection state across surfaces.
class MeetingSelectionController extends Notifier<Set<int>> {
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

final meetingSelectionControllerProvider =
    NotifierProvider<MeetingSelectionController, Set<int>>(
  MeetingSelectionController.new,
);
