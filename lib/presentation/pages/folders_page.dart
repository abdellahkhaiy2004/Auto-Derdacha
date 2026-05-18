import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../state/folder_controller.dart';
import '../state/folder_selection_controller.dart';
import '../../data/repositories/folder_repository.dart';
import '../widgets/folder_card.dart';

/// Tab 2 — grid of all folders (architecture §4, [IP-0067]).
///
/// Displays a 2-column lazy GridView fed by [foldersStreamProvider].
/// Long-press a card to enter multi-select mode: tap to add/remove, contextual
/// appbar offers batch delete. The Inbox folder is exempt from selection.
class FoldersPage extends ConsumerWidget {
  const FoldersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final foldersAsync = ref.watch(foldersStreamProvider);
    final selection = ref.watch(folderSelectionControllerProvider);
    final selectionCtrl = ref.read(folderSelectionControllerProvider.notifier);
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
                onDelete: () => _confirmAndDelete(context, ref, selection),
              )
            : AppBar(
                title: const Text('Dossiers'),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.create_new_folder_rounded),
                    tooltip: 'Nouveau dossier',
                    onPressed: () => context.push('/folders/new'),
                  ),
                ],
              ),
        body: foldersAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Erreur : $e')),
          data: (folders) {
            if (folders.isEmpty) return const _EmptyState();
            return GridView.builder(
              padding: const EdgeInsets.all(12),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 1.05,
              ),
              itemCount: folders.length,
              itemBuilder: (context, i) {
                final folder = folders[i];
                final isSelected = selection.contains(folder.id);
                return FolderCard(
                  folder: folder,
                  gridIndex: i,
                  selected: isSelected,
                  selectionMode: selectionActive,
                  onLongPress: folder.isInbox
                      ? null
                      : () => selectionCtrl.toggle(folder.id),
                  onTap: () {
                    if (selectionActive) {
                      if (!folder.isInbox) selectionCtrl.toggle(folder.id);
                    } else {
                      context.push('/folders/${folder.id}');
                    }
                  },
                );
              },
            );
          },
        ),
        floatingActionButton:
            !selectionActive && foldersAsync.valueOrNull?.isNotEmpty == true
                ? FloatingActionButton.extended(
                    heroTag: 'fab_folders',
                    icon: const Icon(Icons.create_new_folder_rounded),
                    label: const Text('Nouveau'),
                    onPressed: () => context.push('/folders/new'),
                  )
                : null,
      ),
    );
  }

  // ── Batch delete ──────────────────────────────────────────────────────────

  Future<void> _confirmAndDelete(
    BuildContext context,
    WidgetRef ref,
    Set<int> ids,
  ) async {
    final n = ids.length;
    final confirmed = await showDialog<bool>(
      context: context,
      // [P-0135] use the dialog's own context (ctx) for the Navigator.pop
      // calls — using the outer FoldersPage context here walks up to the
      // shell's root navigator and pops the entire /folders route, producing
      // a black screen.
      builder: (ctx) => AlertDialog(
        title: Text('Supprimer $n dossier${n > 1 ? 's' : ''} ?'),
        content: const Text(
          'Les réunions qu\'ils contiennent retourneront automatiquement '
          'à la boîte de réception.',
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
    if (confirmed != true) return;

    final repo = ref.read(folderRepositoryProvider);
    for (final id in ids) {
      await repo.deleteById(id);
    }
    ref.read(folderSelectionControllerProvider.notifier).clear();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$n dossier${n > 1 ? 's' : ''} supprimé${n > 1 ? 's' : ''}.')),
      );
    }
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
      title: Text('$count sélectionné${count > 1 ? 's' : ''}'),
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

// ── Empty state ────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.folder_open_rounded,
              size: 72,
              color: colorScheme.primary.withAlpha(153),
            ),
            const SizedBox(height: 16),
            Text(
              'Aucun dossier pour l\'instant',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Organisez vos réunions en créant\nvotre premier dossier.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              icon: const Icon(Icons.create_new_folder_rounded),
              label: const Text('Créer un dossier'),
              onPressed: () => context.push('/folders/new'),
            ),
          ],
        ),
      ),
    );
  }
}
