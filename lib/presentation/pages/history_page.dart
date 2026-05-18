import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../data/repositories/meeting_repository.dart';
import '../../domain/entities/meeting.dart';
import '../state/meeting_selection_controller.dart';

/// [IP-0069] Tab 2 — flat reverse-chronological list of every meeting,
/// grouped by local calendar day with inline date headers. Reuses
/// [meetingSelectionControllerProvider] from slice C for multi-select.
class HistoryPage extends ConsumerStatefulWidget {
  const HistoryPage({super.key});

  @override
  ConsumerState<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends ConsumerState<HistoryPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(meetingSelectionControllerProvider.notifier).clear();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final meetingsAsync = ref.watch(_allMeetingsProvider);
    final selection = ref.watch(meetingSelectionControllerProvider);
    final selectionCtrl =
        ref.read(meetingSelectionControllerProvider.notifier);
    final selectionActive = selection.isNotEmpty;

    return PopScope(
      canPop: !selectionActive,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && selectionActive) selectionCtrl.clear();
      },
      child: Scaffold(
        appBar: selectionActive
            ? _SelectionAppBar(
                count: selection.length,
                onCancel: selectionCtrl.clear,
                onDelete: () => _batchDelete(selection),
              )
            : AppBar(title: const Text('Historique')),
        body: meetingsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Erreur : $e')),
          data: (meetings) {
            if (meetings.isEmpty) return const _EmptyState();
            final items = _flattenWithHeaders(meetings);
            return ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: items.length,
              itemBuilder: (ctx, i) {
                final item = items[i];
                if (item is _HeaderItem) return _DayHeader(date: item.date);
                final m = (item as _MeetingItem).meeting;
                final isSel = selection.contains(m.id);
                return _HistoryTile(
                  meeting: m,
                  selected: isSel,
                  selectionMode: selectionActive,
                  onLongPress: () => selectionCtrl.toggle(m.id),
                  onTap: selectionActive
                      ? () => selectionCtrl.toggle(m.id)
                      : () => context.push(
                            '/history/meetings/${m.id}',
                          ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  // ── Day grouping ──────────────────────────────────────────────────────────

  /// Builds a flat list of [_HeaderItem, _MeetingItem, _MeetingItem, ...]
  /// preserving the input order (already DESC by createdAt). Headers are
  /// inserted whenever the local-day key changes from the previous item.
  static List<_HistoryListItem> _flattenWithHeaders(List<Meeting> meetings) {
    final out = <_HistoryListItem>[];
    DateTime? lastDay;
    for (final m in meetings) {
      final localDay = _startOfLocalDay(m.createdAt);
      if (lastDay == null || lastDay != localDay) {
        out.add(_HeaderItem(localDay));
        lastDay = localDay;
      }
      out.add(_MeetingItem(m));
    }
    return out;
  }

  static DateTime _startOfLocalDay(DateTime utc) {
    final local = utc.toLocal();
    return DateTime(local.year, local.month, local.day);
  }

  // ── Batch delete ──────────────────────────────────────────────────────────

  Future<void> _batchDelete(Set<int> meetingIds) async {
    final n = meetingIds.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Supprimer $n réunion${n > 1 ? 's' : ''} ?'),
        content: const Text(
          'Cette action est irréversible. Les fichiers audio seront aussi supprimés.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final repo = ref.read(meetingRepositoryProvider);
    for (final id in meetingIds) {
      await repo.delete(id);
    }
    ref.read(meetingSelectionControllerProvider.notifier).clear();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$n réunion${n > 1 ? 's' : ''} supprimée${n > 1 ? 's' : ''}.')),
      );
    }
  }
}

// ── Stream provider ──────────────────────────────────────────────────────────

final _allMeetingsProvider = StreamProvider.autoDispose<List<Meeting>>((ref) {
  return ref.watch(meetingRepositoryProvider).watchAll();
});

// ── Flat-list items ──────────────────────────────────────────────────────────

sealed class _HistoryListItem {
  const _HistoryListItem();
}

class _HeaderItem extends _HistoryListItem {
  const _HeaderItem(this.date);
  final DateTime date;
}

class _MeetingItem extends _HistoryListItem {
  const _MeetingItem(this.meeting);
  final Meeting meeting;
}

// ── Day header ───────────────────────────────────────────────────────────────

class _DayHeader extends StatelessWidget {
  const _DayHeader({required this.date});
  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat.yMMMMd('fr_FR');
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
      child: Text(
        fmt.format(date),
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: cs.primary,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

// ── Tile ─────────────────────────────────────────────────────────────────────

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({
    required this.meeting,
    required this.selected,
    required this.selectionMode,
    required this.onLongPress,
    required this.onTap,
  });

  final Meeting meeting;
  final bool selected;
  final bool selectionMode;
  final VoidCallback onLongPress;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dur = Duration(seconds: meeting.durationSeconds);
    final durStr =
        '${dur.inMinutes}:${(dur.inSeconds % 60).toString().padLeft(2, '0')}';
    final t = meeting.createdAt.toLocal();
    final timeStr =
        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

    return ListTile(
      tileColor: selected ? cs.primaryContainer.withAlpha(120) : null,
      leading: selectionMode
          ? Icon(
              selected
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: selected ? cs.primary : cs.outline,
            )
          : null,
      title: Text(
        meeting.title,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.bodyLarge,
      ),
      subtitle: Text(
        '$timeStr · $durStr',
        style: Theme.of(context).textTheme.bodySmall,
      ),
      onTap: onTap,
      onLongPress: onLongPress,
    );
  }
}

// ── Contextual appbar ────────────────────────────────────────────────────────

class _SelectionAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _SelectionAppBar({
    required this.count,
    required this.onCancel,
    required this.onDelete,
  });

  final int count;
  final VoidCallback onCancel;
  final VoidCallback onDelete;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.close_rounded),
        tooltip: 'Annuler',
        onPressed: onCancel,
      ),
      title: Text('$count sélectionnée${count > 1 ? 's' : ''}'),
      actions: [
        IconButton(
          icon: const Icon(Icons.delete_outline_rounded),
          tooltip: 'Supprimer',
          onPressed: onDelete,
        ),
      ],
    );
  }
}

// ── Empty state ──────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.history_rounded, size: 72, color: cs.primary.withAlpha(153)),
            const SizedBox(height: 16),
            Text(
              'Aucune réunion enregistrée',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Vos réunions apparaîtront ici dans\nl\'ordre chronologique inverse.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
