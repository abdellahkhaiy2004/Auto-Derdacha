import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'data/local/app_database.dart';
import 'presentation/pages/settings_page.dart';
import 'services/audio_cleanup_service.dart';
import 'services/notification_service.dart';

// Runs once after the provider scope is live; cleans up orphan audio files
// from previous sessions ([IP-0051]). A 5-second delay lets the first frame
// render before any background file I/O starts.
final _startupCleanupProvider = FutureProvider<void>((ref) async {
  await Future<void>.delayed(const Duration(seconds: 5));
  final db = ref.read(appDatabaseProvider);
  final paths = await db.meetingDao.getAllAudioPaths();
  await AudioCleanupService.run(paths.toSet());
});

class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router    = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);

    // Trigger orphan cleanup in background; result is intentionally ignored.
    ref.listen(_startupCleanupProvider, (_, __) {});

    // Bind the notification tap handler so OS taps deep-link into the app.
    NotificationService.instance.bindOnTap(router.go);

    return MaterialApp.router(
      title: 'Auto-Derdacha',
      debugShowCheckedModeBanner: false,
      theme:      AppTheme.light,
      darkTheme:  AppTheme.dark,
      themeMode:  themeMode,
      routerConfig: router,
    );
  }
}
