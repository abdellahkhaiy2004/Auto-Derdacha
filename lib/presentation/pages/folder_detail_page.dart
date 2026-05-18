import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/animation_utils.dart';
import '../../data/repositories/folder_repository.dart';
import '../../data/repositories/meeting_repository.dart';
import '../../domain/entities/meeting.dart';
import '../state/folder_controller.dart';
import '../state/meeting_selection_controller.dart';

// ── Sort mode ──────────────────────────────────────────────────────────────────

enum _SortMode { date, duration }

// ── Page ──────────────────────────────────────────────────────────────────────

/// Lists all meetings inside a folder, with sort toggle and FAB to record.
///
/// Hero counterpart tags for MeetingDetailPage ([IP-0029]) are applied to each
/// list-row title here.
class FolderDetailPage extends ConsumerStatefulWidget {
  const FolderDetailPage({super.key, required this.folderId});
  final String folderId;

  @override
  ConsumerState<FolderDetailPage> createState() => _FolderDetailPageState();
}

class _FolderDetailPageState extends ConsumerState<FolderDetailPage> {
  _SortMode _sortMode = _SortMode.date;

  int get _folderId => int.tryParse(widget.folderId) ?? -1;

  @override
  void initState() {
    super.initState();
    // [IP-0068] start with a clean selection so we don't inherit state from
    // another surface that uses the same controller.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(meetingSelectionControllerProvider.notifier).clear();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final folderAsync = ref.watch(folderStreamProvider(_folderId));
    final meetingsAsync = ref.watch(_meetingsProvider(_folderId));
    final selection = ref.watch(meetingSelectionControllerProvider);
    final selectionCtrl =
        ref.read(meetingSelectionControllerProvider.notifier);
    final selectionActive = selection.isNotEmpty;

    return folderAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(appBar: AppBar(), body: Center(child: Text('Erreur : $e'))),
      data: (folder) {
        // Use the folder's own colorHex (set by user at creation) so the
        // detail page theme matches the folder card visually. Falls back
        // to the category color if hex parsing fails.
        final folderColor = folder != null
            ? AppColors.hexToColor(folder.colorHex)
            : AppColors.primarySeed;

        return PopScope(
          canPop: !selectionActive,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop && selectionActive) selectionCtrl.clear();
          },
          child: Scaffold(
          // ── AppBar (default vs contextual selection) ──────────────────────
          appBar: selectionActive
              ? _SelectionAppBar(
                  count: selection.length,
                  onCancel: selectionCtrl.clear,
                  onMove: () => _batchMove(selection),
                  onDelete: () => _batchDelete(selection),
                )
              : AppBar(
            title: Text(folder?.name ?? 'Dossier'),
            backgroundColor: folderColor,
            foregroundColor: AppColors.contrastOn(folderColor),
            actions: [
              // Sort toggle
              IconButton(
                icon: Icon(_sortMode == _SortMode.date
                    ? Icons.schedule_rounded
                    : Icons.timer_rounded),
                tooltip: _sortMode == _SortMode.date
                    ? 'Trier par durée'
                    : 'Trier par date',
                onPressed: () => setState(() {
                  _sortMode = _sortMode == _SortMode.date
                      ? _SortMode.duration
                      : _SortMode.date;
                }),
              ),
              // Folder actions: edit (any folder including Inbox name/colour),
              // delete (non-Inbox only). [IP-0060/G3]
              if (folder != null)
                PopupMenuButton<String>(
                  onSelected: (v) async {
                    switch (v) {
                      case 'edit':
                        context.push('/folders/${folder.id}/edit');
                      case 'delete':
                        await _deleteFolder(folder.id);
                    }
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: ListTile(
                        leading: Icon(Icons.edit_rounded),
                        title: Text('Modifier'),
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                      ),
                    ),
                    if (!folder.isInbox)
                      const PopupMenuItem(
                        value: 'delete',
                        child: ListTile(
                          leading: Icon(Icons.delete_outline_rounded,
                              color: Colors.red),
                          title: Text('Supprimer le dossier',
                              style: TextStyle(color: Colors.red)),
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                        ),
                      ),
                  ],
                ),
            ],
          ),
          body: meetingsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Erreur : $e')),
            data: (meetings) {
              final sorted = _sort(meetings);
              if (sorted.isEmpty) return _EmptyMeetings(folderId: widget.folderId);
              final animate = animationsEnabled(context) && !selectionActive;
              return ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: sorted.length,
                itemBuilder: (ctx, i) {
                  final m = sorted[i];
                  final isSel = selection.contains(m.id);
                  final tile = _MeetingTile(
                    meeting: m,
                    folderId: widget.folderId,
                    selected: isSel,
                    selectionMode: selectionActive,
                    onLongPress: () => selectionCtrl.toggle(m.id),
                    onTap: selectionActive
                        ? () => selectionCtrl.toggle(m.id)
                        : null,
                  );
                  if (!animate) return tile;
                  return tile
                      .animate(delay: Duration(milliseconds: i * 50))
                      .fadeIn(duration: const Duration(milliseconds: 250))
                      .slideX(
                        begin: -0.05,
                        end: 0,
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeOut,
                      );
                },
              );
            },
          ),
          // ── FAB → quick record into this folder (hidden during selection) ─
          floatingActionButton: selectionActive
              ? null
              : FloatingActionButton(
            heroTag: 'fab_record_folder_${widget.folderId}',
            tooltip: 'Enregistrer dans ce dossier',
            shape: const CircleBorder(),
            onPressed: () => context.go(
              '/record?folderId=${widget.folderId}',
            ),
            child: const Icon(Icons.mic_rounded),
          ),
          ),
        );
      },
    );
  }

  // ── Sort ───────────────────────────────────────────────────────────────────

  List<Meeting> _sort(List<Meeting> meetings) {
    final list = [...meetings];
    if (_sortMode == _SortMode.date) {
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    } else {
      list.sort((a, b) => b.durationSeconds.compareTo(a.durationSeconds));
    }
    return list;
  }

  // ── Actions ────────────────────────────────────────────────────────────────

  Future<void> _batchMove(Set<int> meetingIds) async {
    final folders = await ref.read(folderRepositoryProvider).watchAll().first;
    if (!mounted) return;
    final n = meetingIds.length;

    final targetId = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.85,
        expand: false,
        builder: (_, scrollCtrl) => Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(ctx).colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Déplacer $n réunion${n > 1 ? 's' : ''} vers',
              style: Theme.of(ctx).textTheme.titleMedium,
            ),
            const Divider(),
            Expanded(
              child: ListView.builder(
                controller: scrollCtrl,
                itemCount: folders.length,
                itemBuilder: (_, i) {
                  final f = folders[i];
                  final isCurrent = f.id == _folderId;
                  return ListTile(
                    leading: const Icon(Icons.folder_rounded),
                    title: Text(f.name),
                    selected: isCurrent,
                    enabled: !isCurrent,
                    onTap: isCurrent ? null : () => Navigator.of(ctx).pop(f.id),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );

    if (targetId == null || !mounted) return;
    final repo = ref.read(meetingRepositoryProvider);
    for (final id in meetingIds) {
      await repo.moveToFolder(id, targetId);
    }
    ref.read(meetingSelectionControllerProvider.notifier).clear();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$n réunion${n > 1 ? 's' : ''} déplacée${n > 1 ? 's' : ''}.')),
      );
    }
  }

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

  Future<void> _deleteFolder(int id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer ce dossier ?'),
        content: const Text(
          'Les réunions seront déplacées vers la Boîte de réception.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Annuler')),
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Supprimer',
                  style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await ref.read(folderControllerProvider.notifier).deleteFolder(id);
      if (mounted) context.pop();
    }
  }
}

// ── Stream providers ──────────────────────────────────────────────────────────

final _meetingsProvider =
    StreamProvider.autoDispose.family<List<Meeting>, int>((ref, folderId) {
  return ref.watch(meetingRepositoryProvider).watchByFolder(folderId);
});

// ── Meeting tile ───────────────────────────────────────────────────────────────

class _MeetingTile extends StatelessWidget {
  const _MeetingTile({
    required this.meeting,
    required this.folderId,
    this.selected = false,
    this.selectionMode = false,
    this.onLongPress,
    this.onTap,
  });

  final Meeting meeting;
  final String folderId;
  // [IP-0068]
  final bool selected;
  final bool selectionMode;
  final VoidCallback? onLongPress;
  // When null, the tile uses its default navigation behaviour. Pass a callback
  // (e.g. selectionCtrl.toggle) to override while in selection mode.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final dur = Duration(seconds: meeting.durationSeconds);
    final durStr =
        '${dur.inMinutes}:${(dur.inSeconds % 60).toString().padLeft(2, '0')}';
    final date = meeting.createdAt.toLocal();
    final dateStr =
        '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
    final cs = Theme.of(context).colorScheme;

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
      // Hero counterpart for MeetingDetailPage title ([IP-0029]).
      title: Hero(
        tag: 'meeting_title_${meeting.id}',
        flightShuttleBuilder: _shuttle,
        child: Material(
          color: Colors.transparent,
          child: Text(
            meeting.title,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
      ),
      subtitle: Text(dateStr,
          style: Theme.of(context).textTheme.bodySmall),
      trailing: _DurationChip(label: durStr, state: meeting.pipelineState),
      onTap: onTap ?? () => context.push(
        '/folders/$folderId/meetings/${meeting.id}',
      ),
      onLongPress: onLongPress,
    );
  }

  static Widget _shuttle(
    BuildContext _,
    Animation<double> animation,
    HeroFlightDirection direction,
    BuildContext fromCtx,
    BuildContext toCtx,
  ) =>
      FadeTransition(
        opacity: animation,
        child: direction == HeroFlightDirection.push
            ? toCtx.widget
            : fromCtx.widget,
      );
}

class _DurationChip extends StatelessWidget {
  const _DurationChip({required this.label, required this.state});
  final String label;
  final PipelineState state;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isError = state == PipelineState.failed;
    final isPending = state == PipelineState.pending ||
        state == PipelineState.transcribing ||
        state == PipelineState.summarizing;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isError
            ? colorScheme.errorContainer
            : isPending
                ? colorScheme.tertiaryContainer
                : colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        isPending ? '…' : isError ? '!' : label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: isError
                  ? colorScheme.onErrorContainer
                  : isPending
                      ? colorScheme.onTertiaryContainer
                      : colorScheme.onSecondaryContainer,
            ),
      ),
    );
  }
}

// ── Contextual appbar ────────────────────────────────────────────────────────

class _SelectionAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _SelectionAppBar({
    required this.count,
    required this.onCancel,
    required this.onMove,
    required this.onDelete,
  });

  final int count;
  final VoidCallback onCancel;
  final VoidCallback onMove;
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
          icon: const Icon(Icons.drive_file_move_outlined),
          tooltip: 'Déplacer vers…',
          onPressed: onMove,
        ),
        IconButton(
          icon: const Icon(Icons.delete_outline_rounded),
          tooltip: 'Supprimer',
          onPressed: onDelete,
        ),
      ],
    );
  }
}

// ── Empty state ────────────────────────────────────────────────────────────────

class _EmptyMeetings extends StatelessWidget {
  const _EmptyMeetings({required this.folderId});
  final String folderId;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.mic_none_rounded,
                size: 64,
                color: Theme.of(context)
                    .colorScheme
                    .primary
                    .withAlpha(153)),
            const SizedBox(height: 16),
            Text('Aucune réunion dans ce dossier',
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(
              'Appuyez sur le bouton micro pour\nenregistrer votre première réunion.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurfaceVariant,
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
