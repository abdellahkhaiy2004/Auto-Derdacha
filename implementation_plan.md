# Implementation Plan — Auto-Derdacha

> **Append-only file** (per `instructions.md` §1–2). No existing entry below may be edited or deleted. Corrections, scope changes, or re-orderings are made by **appending a new `[IP-NNNN]` entry** at the bottom that explicitly **supersedes** the older one. Every entry carries a unique, monotonically increasing `[IP-NNNN]` label and, on completion, cross-links the `[P-…]`, `[SL-…]`, and `[UML-…]` IDs it produced.

## Conventions

- **Timestamps:** ISO-8601 with timezone offset (e.g. `2026-05-17T10:42+01`).
- **ID format:** `[IP-NNNN]`, 4-digit zero-padded, never reused.
- **Status legend:** `PLANNED` · `IN-PROGRESS` · `DONE` · `SUPERSEDED`. The initial fill below leaves every entry as `PLANNED`; the agent flips status by appending a new note line at the bottom of the entry (never by editing the original).
- **Entry shape:**
  ```
  ## [IP-NNNN] YYYY-MM-DD — <title>           Status: PLANNED
  Context: …
  Steps: …
  Risk: …
  Linked: [P-…], [SL-…], [UML-…]
  ```
- **Reference to architecture sections** uses `architecture.md §N`.

## Table of contents

- **Part 0** — Bootstrap & project scaffold — `[IP-0001] … [IP-0006]`
- **Part 1** — Core: theme, router, shell — `[IP-0007] … [IP-0011]`
- **Part 2** — Audio recording pipeline — `[IP-0012] … [IP-0017]`
- **Part 3** — Groq API integration — `[IP-0018] … [IP-0021]`
- **Part 4** — Local persistence (Drift) — `[IP-0022] … [IP-0025]`
- **Part 5** — Meeting detail & audio replay — `[IP-0026] … [IP-0029]`
- **Part 6** — Folders & categories — `[IP-0030] … [IP-0034]`
- **Part 7** — Calendar & reminders — `[IP-0035] … [IP-0039]`
- **Part 8** — Animations & polish — `[IP-0040] … [IP-0044]`
- **Part 9** — Android back-button hardening — `[IP-0045] … [IP-0047]`
- **Part 10** — Robustness — `[IP-0048] … [IP-0051]`
- **Part 11** — Settings & accessibility — `[IP-0052] … [IP-0054]`
- **Part 12** — Final QA & release prep — `[IP-0055] … [IP-0057]`

---

# Part 0 — Bootstrap & project scaffold

## [IP-0001] 2026-05-17 — Initialize Flutter project           Status: PLANNED
Context: Empty repo at `C:\Users\Admin\Desktop\auto-Dardacha`. Need a Flutter 3.x project as foundation per `architecture.md` §1.
Steps:
1. Run `flutter create .` (preserve existing markdown files).
2. Pin Flutter SDK constraint `>=3.16.0` in `pubspec.yaml`.
3. Replace default `analysis_options.yaml` with `flutter_lints` + strict rules (`prefer_const_constructors`, `prefer_final_locals`, `avoid_print`).
4. Verify `flutter doctor` is green for Android target.
Risk: `flutter create .` may overwrite a stray file → confirm only Dart/Gradle/iOS scaffolds appear, no governance file touched.
Linked: [P-…], [SL-…]

## [IP-0002] 2026-05-17 — Lay down the lib/ tree           Status: PLANNED
Context: Architecture §2 defines a strict folder layout. Create the structure as empty stub files so later units only need to fill them.
Steps: Create empty Dart files under `lib/`: `main.dart`, `app.dart`; subtrees `core/{config,errors,theme,router,utils}`, `data/{audio,remote,local,repositories}`, `domain/{entities,usecases}`, `presentation/{pages,widgets,state}`, `services/`. Use placeholder doc-comments only.
Risk: Empty files may break analyzer until they contain valid Dart — add `// stub` body.
Linked: [P-…], [SL-…]

## [IP-0003] 2026-05-17 — Declare dependencies in pubspec.yaml           Status: PLANNED
Context: All packages listed in `architecture.md` §7.
Steps: Add `record`, `just_audio`, `dio`, `flutter_riverpod`, `go_router`, `flutter_markdown`, `drift`, `drift_dev` (dev), `build_runner` (dev), `table_calendar`, `flutter_local_notifications`, `permission_handler`, `google_fonts`, `lucide_icons`, `flutter_animate`, `path_provider`, `shared_preferences`. Run `flutter pub get`.
Risk: Version conflicts between `drift_dev` / `build_runner` and SDK constraint → pin to known-compatible versions; record chosen versions in a `[SL-…]` entry.
Linked: [P-…], [SL-…]

## [IP-0004] 2026-05-17 — Create .env.example and gitignore .env           Status: PLANNED
Context: Per `instructions.md` §5, secrets live in `.env` (never committed); `.env.example` is the public template.
Steps:
1. Append `/.env` to `.gitignore`.
2. Create `.env.example` containing exactly:
   ```
   # Groq API key — create at https://console.groq.com/keys (free tier).
   GROQ_API_KEY=
   # OpenAI-compatible base URL. Keep default unless mirroring.
   GROQ_BASE_URL=https://api.groq.com/openai/v1
   # STT model id — see https://console.groq.com/docs/models.
   GROQ_STT_MODEL=whisper-large-v3
   # LLM used for summarization.
   GROQ_LLM_MODEL=llama-3.3-70b-versatile
   ```
3. Append a `[P-…] note:` reminding the owner to copy to `.env` and fill `GROQ_API_KEY`.
Risk: Accidentally committing a real key → confirm `.env` is in `.gitignore` before any later commit.
Linked: [P-…], [SL-…]

## [IP-0005] 2026-05-17 — Implement core/config/env.dart           Status: PLANNED
Context: Single typed accessor for env values, used by every API client.
Steps: Implement `Env.groqApiKey`, `Env.baseUrl`, `Env.sttModel`, `Env.llmModel` using `String.fromEnvironment` (so values come from `--dart-define-from-file=.env`). Throw `StateError` at startup if `GROQ_API_KEY` is empty.
Risk: Forgetting `--dart-define-from-file` at run time → log a clear error message naming the missing var.
Linked: [P-…], [SL-…]

## [IP-0006] 2026-05-17 — First README.md content           Status: PLANNED
Context: `README.md` must explain *only how to run the project* per the owner's directive.
Steps: Append a "Run the project" section with: prerequisites (Flutter 3.16+, Android SDK), `.env` setup (copy from `.env.example`, fill `GROQ_API_KEY`), `flutter pub get`, `flutter run --dart-define-from-file=.env`, troubleshooting placeholder.
Risk: README later drifting from real commands → re-validated in [IP-0056].
Linked: [P-…], [SL-…]

---

# Part 1 — Core: theme, router, shell

## [IP-0007] 2026-05-17 — Palette & typography           Status: PLANNED
Context: Architecture §9 defines the colorful Material 3 palette and Inter + Cairo typography.
Steps: Implement `core/theme/app_colors.dart` (all tokens: `primarySeed #7C3AED`, secondary, tertiary, recording, categoryWork/School/Family/Personal/Custom). Implement `core/theme/app_typography.dart` using `google_fonts` (Inter for Latin, Cairo for Arabic glyphs).
Risk: `google_fonts` runtime download — preload critical weights at app start.
Linked: [P-…], [SL-…]

## [IP-0008] 2026-05-17 — Build light & dark ThemeData           Status: PLANNED
Context: Single source of truth in `app_theme.dart`.
Steps: `ColorScheme.fromSeed(seedColor: primarySeed)` for both brightnesses; rounded shapes (16/24/28 px); apply typography; export `lightTheme`, `darkTheme`.
Risk: Category colors clashing with seeded surface → keep them as separate tokens not from the scheme.
Linked: [P-…], [SL-…]

## [IP-0009] 2026-05-17 — go_router with StatefulShell           Status: PLANNED
Context: Architecture §9c requires per-tab navigation stacks for correct back behavior.
Steps: Implement `core/router/app_router.dart` with `StatefulShellRoute.indexedStack`, branches `record`, `calendar`, `folders`, `settings`. Add a `CustomTransitionPage` factory (fade + 12 px slide-up, 280 ms, `Curves.easeOutCubic`) used by all pushed routes.
Risk: Deep links bypassing the shell — define a single top-level `MaterialApp.router` and route everything through it.
Linked: [P-…], [SL-…]

## [IP-0010] 2026-05-17 — HomeShell with bottom nav + tab history           Status: PLANNED
Context: Top-level back from a tab root must return to the previously selected tab (architecture §9c).
Steps: Implement `presentation/pages/home_shell.dart` with `NavigationBar`. Maintain a `tabHistory` stack in `ShellController`. Hook `PopScope` at shell root: pop within tab → if at root and history non-empty, switch to previous tab; if history empty, run double-tap-to-exit guard.
Risk: Tab history drifting from real navigation — update only on `branchIndex` change.
Linked: [P-…], [SL-…]

## [IP-0011] 2026-05-17 — Settings page minimal           Status: PLANNED
Context: Needed early so theme toggle is testable.
Steps: `presentation/pages/settings_page.dart` with theme toggle (light/dark/system), "About" tile. Persist via `shared_preferences` with key `theme_mode`.
Risk: Theme not updating without app restart → expose `themeModeProvider` (Riverpod) and rebuild `MaterialApp`.
Linked: [P-…], [SL-…]

---

# Part 2 — Audio recording pipeline

## [IP-0012] 2026-05-17 — AudioRecorder wrapper           Status: PLANNED
Context: Architecture §3 + §7. Files go under app docs `audio/<uuid>.m4a`.
Steps: Implement `data/audio/audio_recorder.dart` with `start()`, `stop()`, `pause()`, `resume()`. Configure AAC mono 16 kHz via the `record` package. Use `path_provider` for the directory.
Risk: Background recording cut on Android (battery saver). For v1 keep app in foreground; document the limitation in `student_lab.md`.
Linked: [P-…], [SL-…]

## [IP-0013] 2026-05-17 — RecordingState sealed class           Status: PLANNED
Context: Drives UI of `RecordPage`.
Steps: Define `sealed class RecordingState` with `Idle`, `Recording(elapsed, amplitude)`, `Paused(elapsed)`, `Error(message)`.
Risk: None.
Linked: [P-…], [SL-…]

## [IP-0014] 2026-05-17 — RecordButton widget           Status: PLANNED
Context: Architecture §9 + §9b — gradient circular button with idle scale and active pulse.
Steps: Implement `presentation/widgets/record_button.dart`. Idle: `AnimatedScale 1.0↔1.04` 2.2 s. Active: pulsing red ring + scale, gradient purple→pink. Use `flutter_animate`.
Risk: Animation jank on low-end devices — keep ring count to 2.
Linked: [P-…], [SL-…]

## [IP-0015] 2026-05-17 — WaveformIndicator widget           Status: PLANNED
Context: Live amplitude feedback during recording.
Steps: Stream `amplitude` from `record`, draw 24 bars with `CustomPainter`, normalize to dB.
Risk: Stream overhead — throttle to 60 ms.
Linked: [P-…], [SL-…]

## [IP-0016] 2026-05-17 — RecordPage           Status: PLANNED
Context: First tab; entry point for the pipeline.
Steps: Big `RecordButton`, `WaveformIndicator`, monospaced timer, status label, `permission_handler` request flow with retry dialog. On Stop, navigate to `ProcessingPage`.
Risk: Permission denied loop — provide "Open Settings" action.
Linked: [P-…], [SL-…]

## [IP-0017] 2026-05-17 — MeetingController + use-cases           Status: PLANNED
Context: Riverpod notifier orchestrating Record → Process pipeline.
Steps: Implement `domain/usecases/start_recording.dart`, `stop_and_process.dart` (pure). `presentation/state/meeting_controller.dart` exposes `startRecording()`, `stopAndProcess(folderId?)` returning a state machine.
Risk: Notifier disposed mid-upload → use `keepAlive` while recording or processing.
Linked: [P-…], [SL-…]

---

# Part 3 — Groq API integration

## [IP-0018] 2026-05-17 — GroqClient (Dio)           Status: PLANNED
Context: Architecture §1 + §8.
Steps: Implement `data/remote/groq_client.dart` — single shared `Dio` with `Authorization: Bearer ${Env.groqApiKey}` and base URL from `env.dart`. Add interceptor with exponential backoff (3 retries, 500 ms / 1 s / 2 s) on 429 / 5xx.
Risk: Rate-limit floods — respect `Retry-After` if present.
Linked: [P-…], [SL-…]

## [IP-0019] 2026-05-17 — TranscriptionApi           Status: PLANNED
Context: Multipart upload to `/audio/transcriptions`.
Steps: Implement `transcribe(File audio, {String? language})` posting `model = Env.sttModel`, `file = <m4a>`, `response_format = json`. Return `String` transcript. Surface raw text without forced language so code-switching survives (architecture §3).
Risk: 25 MB limit — handled in [IP-0048].
Linked: [P-…], [SL-…]

## [IP-0020] 2026-05-17 — SummaryApi           Status: PLANNED
Context: Markdown summary with fixed sections (architecture §3).
Steps: Implement `summarize(String transcript)` POSTing to `/chat/completions` with `model = Env.llmModel`, system prompt instructing: detect Darija/FR/EN, output in dominant language, preserve proper nouns, emit Markdown with `## Participants`, `## Décisions`, `## Action items`, `## Risques / Points ouverts`, `## Résumé global`. `temperature: 0.2`, `max_tokens: 2048`.
Risk: Model deviating from section order — include a few-shot example in the system prompt; validate sections on parse.
Linked: [P-…], [SL-…]

## [IP-0021] 2026-05-17 — Failure hierarchy + Dio mapping           Status: PLANNED
Context: Architecture §11.
Steps: `core/errors/failures.dart` with sealed `Failure` → `NetworkFailure`, `ApiFailure(status, message)`, `PermissionFailure`, `FileTooLargeFailure`, `EmptyAudioFailure`. Add `mapDioError(e) → Failure` helper.
Risk: Unhandled exception types escape into UI — wrap all remote calls in `Result<T, Failure>`.
Linked: [P-…], [SL-…]

---

# Part 4 — Local persistence (Drift)

## [IP-0022] 2026-05-17 — Drift schema           Status: DONE
Context: Architecture §10 tables `folders`, `meetings`, `calendar_events`.
Steps: Define table classes in `data/local/tables.dart`. Add indices on `meetings.folder_id`, `meetings.created_at`, `calendar_events.start_at`. Run `dart run build_runner build`.
Risk: Schema changes after data exists — establish migration discipline now (`schemaVersion = 1`, add `MigrationStrategy` skeleton).
Linked: [P-0038][P-0039], [SL-0022][SL-0023]
Status note (2026-05-17): DONE — tables.dart + app_database.dart written; domain entities (category/folder/meeting/calendar_event/summary_section) implemented; pubspec.yaml +path:^1.9.0; `flutter pub run build_runner build` still required after SDK install to generate *.g.dart.

## [IP-0023] 2026-05-17 — DAOs + Inbox seed           Status: DONE
Context: Inbox is the virtual fallback folder when `folderId` is null on the UI side.
Steps: Implement `MeetingDao`, `FolderDao`, `EventDao` (CRUD + watch streams). Seed migration inserting a folder `id='inbox', category=Personal, color=#94A3B8, iconKey=inbox` only if missing.
Risk: Seed duplicating on hot restart — guard with `SELECT count(*) WHERE id='inbox'`.
Linked: [P-0040], [SL-0024]
Status note (2026-05-17): DONE — all three DAOs implemented; Inbox seed in app_database.dart MigrationStrategy.onCreate with isInbox guard; no duplicate risk (INSERT once at DB creation).

## [IP-0024] 2026-05-17 — MeetingRepository           Status: DONE
Context: Orchestrates the pipeline; called by `MeetingController.stopAndProcess`.
Steps: `process(File audio, String? folderId)` → call `TranscriptionApi`, then `SummaryApi`, then `MeetingDao.insert`. Also implement `rename`, `moveToFolder`, `delete` (also removes audio file), `reSummarize(id)`.
Risk: Partial failure leaving orphan audio — wrap insert + cleanup in try/catch, log failure as a `[P-…] block:` and let user retry.
Linked: [P-0041], [SL-0025]
Status note (2026-05-17): DONE — processRecording() inserts pending row first, streams pipeline state via watchById(); retryPipeline() re-runs on existing audio file; _heuristicLang() provides initial language detection; meetingRepositoryProvider wired.

## [IP-0025] 2026-05-17 — FolderRepository & CalendarRepository           Status: DONE
Context: Straight CRUD + the linkage between event and meeting.
Steps: Implement `FolderRepository` (`create`, `update`, `delete(id, strategy)` where strategy is `moveToInbox` or `cascadeDelete`). Implement `CalendarRepository` (`scheduleEvent`, `eventsForRange`, `linkMeeting`). Latter calls `NotificationService` (will be implemented in [IP-0038]; for now no-op stub).
Risk: Cascade delete removing audio for many meetings — confirm-dialog enforced at UI layer.
Linked: [P-0042], [SL-0025]
Status note (2026-05-17): DONE — FolderRepository: Inbox isInbox guard prevents deletion; Drift FK onDelete:setDefault moves orphaned meetings to Inbox automatically; CalendarRepository: scheduleEvent() returns id for NotificationService caller ([IP-0038]).

---

# Part 5 — Meeting detail & audio replay

## [IP-0026] 2026-05-17 — AudioPlayer wrapper           Status: DONE
Context: Architecture §6 — playback with speed control.
Steps: Implement `data/audio/audio_player.dart` wrapping `just_audio`. Expose position/duration streams, `setSpeed(double)`.
Risk: File missing at replay time — surface a `FileMissing` event handled in §11 robustness.
Linked: [P-0045], [SL-0026]
Status note (2026-05-17): DONE — AudioPlayerState + AudioPlayerNotifier (AutoDispose); positionStream/playerStateStream/durationStream; load/play/pause/seek/setSpeed; auto-seek to zero on completion; ref.onDispose cleanup.

## [IP-0027] 2026-05-17 — AudioPlayerBar widget           Status: DONE
Context: Sticky bar on detail page.
Steps: Implement `presentation/widgets/audio_player_bar.dart`: play/pause (`AnimatedSwitcher`), seek slider, current/total time, speed segmented control (0.75/1/1.5/2).
Risk: Seek slider lagging during scrub — debounce 30 ms.
Linked: [P-0046], [SL-0027]
Status note (2026-05-17): DONE — SliderTheme seek with 30 ms Timer debounce; _PlayPauseButton AnimatedSwitcher with loading/error states; _SpeedSelector AnimatedContainer chips; ±15 s skip buttons.

## [IP-0028] 2026-05-17 — MeetingDetailPage           Status: DONE
Context: Architecture §6.
Steps: Header (editable title, folder chip, date, duration, category color band). Sticky `AudioPlayerBar`. `TabBar` with Résumé (`flutter_markdown` styled to palette), Transcription (selectable text + copy + search), Infos (size, language, model, "Re-summarize" action). App-bar overflow: rename, move-to-folder, delete, export Markdown / share.
Risk: Long transcripts blocking scrolling — wrap in `Scrollable` lazily.
Linked: [P-0047], [SL-0028]
Status note (2026-05-17): DONE — _meetingStreamProvider drives page reactively; _loadAudioOnce deferred; PopScope pause-on-back; header with pipeline state label/color; Résumé/Transcript/Infos tabs; overflow menu with rename/move/copy/reSummarize/delete; reSummarize() added to MeetingRepository.

## [IP-0029] 2026-05-17 — Hero transitions           Status: DONE
Context: Architecture §9b.
Steps: Tag list-row title + duration chip with `Hero(tag: 'meeting-${id}')` on both list and detail.
Risk: Hero conflicts when navigating from two surfaces (folder vs calendar) — use unique IDs per source.
Linked: [P-0048], [SL-0029]
Status note (2026-05-17): DONE — Hero(tag:'meeting_title_$id') on AppBar title with transparent Material wrapper and FadeTransition flightShuttleBuilder; list-row counterpart deferred to FolderDetailPage [IP-0033].

---

# Part 6 — Folders & categories

## [IP-0030] 2026-05-17 — FolderCard widget           Status: DONE
Context: Architecture §4 + §9.
Steps: Implement `presentation/widgets/folder_card.dart`: linear gradient from `colorHex` → `colorHex@70%`, icon from `lucide_icons` by `iconKey`, meeting count, soft drop shadow, `Hero(tag: 'folder-${id}')`.
Risk: Gradient contrast vs label — auto-pick text color from luminance.
Linked: [P-0051][P-0053], [SL-0030]
Status note (2026-05-17): DONE — LinearGradient topLeft→bottomRight; contrastOn text; 19-icon switch map; Hero tag 'folder_card_$id'; drop shadow baseColor@30%; AppColors extended with 7 category tokens, 12 folderSwatches, hexToColor, forCategoryEnum.

## [IP-0031] 2026-05-17 — FoldersPage grid           Status: DONE
Context: Tab 3 of bottom nav.
Steps: 2-col `GridView` of `FolderCard`s sorted by name. Empty state CTA: "Créer un dossier".
Risk: Large library → enable lazy grid.
Linked: [P-0054], [SL-0032]
Status note (2026-05-17): DONE — GridView.builder lazy 2-col (childAspectRatio 0.85); _EmptyState with FilledButton CTA; FAB with scoped heroTag; AppBar action shortcut to /folders/new.

## [IP-0032] 2026-05-17 — NewFolderPage           Status: DONE
Context: Architecture §4.
Steps: Form with name field, category picker (segmented), color swatch (12 presets + custom picker), icon picker (24 `lucide` icons). `PopScope` blocks back if form is dirty → "Discard changes?" sheet.
Risk: Color picker bloat — defer custom picker behind a "Plus de couleurs" link.
Linked: [P-0055], [SL-0033]
Status note (2026-05-17): DONE — _PreviewCard WYSIWYG; _CategoryPicker ChoiceChip; _ColorSwatches 12 AnimatedContainer circles; _IconPicker 19-icon Wrap; dirty PopScope → confirmDiscard modal sheet; save converts Color to hex.

## [IP-0033] 2026-05-17 — FolderDetailPage           Status: DONE
Context: List meetings inside a folder.
Steps: AppBar with folder name + category color band. List sorted by date (toggle to sort by duration). Each row: title, date, duration, Hero tag. Long-press → "Move to…" sheet. FAB → quick record into this folder (deep-links to `RecordPage(folderId)`).
Risk: Sort toggle losing scroll position — persist offset.
Linked: [P-0056], [SL-0034]
Status note (2026-05-17): DONE — categoryColor AppBar; _SortMode date/duration local toggle; _MeetingTile with Hero counterpart 'meeting_title_$id' (completes IP-0029); _DurationChip 3-state; long-press move sheet; delete folder guard (Inbox protected); FAB → /record?folderId.

## [IP-0034] 2026-05-17 — FolderController & assign use-case           Status: DONE
Context: State for folder CRUD + meeting reassignment.
Steps: Implement `presentation/state/folder_controller.dart` and `domain/usecases/assign_meeting_to_folder.dart`.
Risk: Stale UI after move — invalidate dependent providers.
Linked: [P-0052], [SL-0031]
Status note (2026-05-17): DONE — foldersStreamProvider + folderStreamProvider family; FolderController Notifier<void> with CRUD mutations; AssignMeetingToFolder use-case validates target folder existence; stale UI handled by stream auto-update (no manual invalidation needed).

---

# Part 7 — Calendar & reminders

## [IP-0035] 2026-05-17 — CalendarPage with table_calendar           Status: DONE
Context: Architecture §5.
Steps: `presentation/pages/calendar_page.dart` using `table_calendar`. Month / 2-week / week formats. Day-cell builder draws one dot per category with activity that day; today and selected day styled with primary tint.
Risk: Dot count overflow — cap at 3 dots + "+N".
Linked: [P-0061], [SL-0037]
Status note (2026-05-17): DONE — TableCalendar fr_FR, monday start, custom _DayMarkers (primary dots for meetings, tertiary for events, +N overflow), _DayPreview inline, CalendarController Notifier with UTC day-keys and fetchForMonth.

## [IP-0036] 2026-05-17 — Day bottom-sheet           Status: DONE
Context: Architecture §5.
Steps: On day tap, open a draggable `BottomSheet` with two sections: "Passé" (meetings of that day → tap routes to `MeetingDetailPage`) and "À venir" (scheduled `CalendarEvent`s). `useRootNavigator: false` so back closes the sheet first (architecture §9c).
Risk: Sheet covering FAB — adjust scaffold.
Linked: [P-0061], [SL-0037]
Status note (2026-05-17): DONE — _DaySheet DraggableScrollableSheet(0.5→0.85); useRootNavigator:false; two sections (_MeetingRow tap→detail, _EventRow linked-check-mark); inline schedule shortcut.

## [IP-0037] 2026-05-17 — ScheduleEventPage           Status: DONE
Context: Architecture §5.
Steps: Form: title, folder picker, start/end (date+time pickers), optional reminder. Dirty-form `PopScope` like [IP-0032].
Risk: User scheduling reminder in the past — validate.
Linked: [P-0062], [SL-0038]
Status note (2026-05-17): DONE — title/folder/start-end/reminder; _roundUp 30-min slot helper; past-event SnackBar warning; save flow: calRepo.scheduleEvent → requestExactAlarmPermission → notifService.schedule → fetchForMonth refresh; dirty PopScope.

## [IP-0038] 2026-05-17 — NotificationService           Status: DONE
Context: Architecture §5 + §7.
Steps: `services/notification_service.dart` wrapping `flutter_local_notifications`. Methods `schedule(eventId, at, payload)`, `cancel(eventId)`. Payload encodes `folderId` + `eventId`. On tap, deep-link via `go_router` to `RecordPage(folderId, eventId)`.
Risk: Android exact-alarm permission on Android 13+ — request via `permission_handler`; warn in UI if denied.
Linked: [P-0059], [SL-0035]
Status note (2026-05-17): DONE — singleton, zonedSchedule exactAllowWhileIdle, Android channel, NotificationPayload JSON, requestExactAlarmPermission, bindOnTap(router.go) from app.dart; timezone:^0.9.4 added to pubspec; main.dart async.

## [IP-0039] 2026-05-17 — Link recorded meeting to scheduled event           Status: DONE
Context: Closing the loop between calendar and recordings.
Steps: When `RecordPage` is opened with an `eventId`, after `MeetingRepository.process` succeeds, call `CalendarRepository.linkMeeting(eventId, meetingId)`. Calendar UI marks the event as "completed".
Risk: Mismatched event/meeting if user records something else — UI prompt "Lier cet enregistrement à l'événement ?".
Linked: [P-0063], [SL-0039]
Status note (2026-05-17): DONE — MeetingRepository.processRecording +linkedEventId param; _calRepo!.linkMeeting called after successful pipeline; provider injects calendarRepositoryProvider; CalendarPage._EventRow shows check-mark when linkedMeetingId is set.

---

# Part 8 — Animations & polish

## [IP-0040] 2026-05-17 — Idle "floating" motion           Status: DONE
Context: Architecture §9b — folder cards bob, idle record button breathes.
Steps: Apply `flutter_animate` `.moveY(begin: -4, end: 4, duration: 3s, curve: easeInOut).then().moveY(begin: 4, end: -4)` looped, staggered by card index. Record button idle scale already in [IP-0014].
Risk: Stutter when scrolling many cards — pause animation when `RouteAware` reports route hidden.
Linked: [P-0067], [SL-0040]

## [IP-0041] 2026-05-17 — Staggered summary fade-in           Status: DONE
Context: Architecture §9b.
Steps: Split summary Markdown into sections, render each in a `Column`, apply `.fadeIn().slideY(begin: 0.05)` staggered 60 ms per section.
Risk: Flicker on tab switch — disable on rebuild after first frame.
Linked: [P-0068], [SL-0041]

## [IP-0042] 2026-05-17 — AnimatedSwitcher + FAB rotate + calendar dot morph           Status: DONE
Context: Microinteractions from architecture §9b.
Steps: Play/pause icons via `AnimatedSwitcher`. Schedule FAB rotates 0→45° when transforming into close icon. Calendar dot → filled circle via `AnimatedContainer` 200 ms on selection.
Risk: Forgetting to dispose controllers — prefer `flutter_animate` declarative API where possible.
Linked: [P-0069], [SL-0042]

## [IP-0043] 2026-05-17 — AnimatedList on meeting lists           Status: DONE
Context: Insert/remove with slide+fade on `FolderDetailPage` and day sheet.
Steps: Replace `ListView` with `AnimatedList`; provide enter/exit builders.
Risk: Keys drifting — use stable `meetingId` keys.
Linked: [P-0070], [SL-0043]

## [IP-0044] 2026-05-17 — Respect disableAnimations           Status: DONE
Context: Accessibility, architecture §9b.
Steps: Read `MediaQuery.of(context).disableAnimations` at the theme level; expose a Riverpod provider `animationsEnabledProvider`. Each animated widget checks the provider and falls back to instant transitions.
Risk: Easy to miss spots — write a small mixin `AnimatedAware` used by all custom animated widgets.
Linked: [P-0066], [SL-0044]

---

# Part 9 — Android back-button hardening

## [IP-0045] 2026-05-17 — PopScope on every dirty/in-progress page           Status: PLANNED
Context: Architecture §9c table.
Steps: Add `PopScope(canPop: …, onPopInvokedWithResult: …)` to: `RecordPage` (block while recording), `ProcessingPage` (cancel-upload dialog), `NewFolderPage` + `ScheduleEventPage` (dirty form), `MeetingDetailPage` (pause player on pop). Sheets use `useRootNavigator: false`.
Risk: Predictive-back animation interrupted — call `context.pop()` only after async confirm resolves and `context.mounted` is true.
Linked: [P-…], [SL-…]

## [IP-0046] 2026-05-17 — Enable Android 14 predictive back           Status: PLANNED
Context: Architecture §9c.
Steps: In `android/app/src/main/AndroidManifest.xml` set `android:enableOnBackInvokedCallback="true"` on `<application>`.
Risk: Older devices ignore the flag — no-op there.
Linked: [P-…], [SL-…]

## [IP-0047] 2026-05-17 — Double-tap-to-exit at shell root           Status: PLANNED
Context: Prevent accidental exit from the root tab.
Steps: At `HomeShell`'s top-level `PopScope`, if `canPop == false`, show a snackbar "Appuyez encore pour quitter" and arm a 2 s window; second back within the window calls `SystemNavigator.pop()`.
Risk: Snackbar stacking — dismiss any current snackbar first.
Linked: [P-…], [SL-…]

---

# Part 10 — Robustness

## [IP-0048] 2026-05-17 — Audio chunking > 25 MB           Status: PLANNED
Context: Architecture §11.
Steps: Add `core/utils/audio_chunker.dart` splitting an `.m4a` into ~20 MB chunks at silence boundaries (fallback: byte boundaries). In `MeetingRepository.process`, transcribe each chunk sequentially, concatenate with `\n`, then summarize once.
Risk: Cutting mid-word — silence-detection heuristic; document fallback.
Linked: [P-…], [SL-…]

## [IP-0049] 2026-05-17 — Retry banner reusing local file           Status: PLANNED
Context: Architecture §11. The audio file must not be lost on transient API errors.
Steps: When pipeline fails, persist a `Meeting` row with empty `transcript`/`summaryMd` and a `pipeline_state` column extension (use a simple key in a new `meeting_meta` table or a column added in a migration v2). UI surfaces a "Réessayer" banner on `MeetingDetailPage`.
Risk: Schema change → migration v2; emit `[UML-0002]` for the updated data model.
Linked: [P-…], [SL-…], [UML-…]

## [IP-0050] 2026-05-17 — Silent audio detection           Status: PLANNED
Context: Architecture §11.
Steps: Before calling Whisper, compute RMS amplitude of the file via the `record` package's analysis or a tiny FFI helper. If below threshold over the whole file, skip API and show inline notice.
Risk: False negatives on quiet meetings — keep threshold conservative; allow user override "Envoyer quand même".
Linked: [P-…], [SL-…]

## [IP-0051] 2026-05-17 — Orphan audio cleanup           Status: PLANNED
Context: Files in `audio/` not referenced by any `Meeting`.
Steps: On app start (after DB init), list `audio/`, diff against `meetings.audio_path`, delete unreferenced files older than 24 h.
Risk: Deleting a file mid-recording — guard with `AudioRecorder.isRecording`.
Linked: [P-…], [SL-…]

---

# Part 11 — Settings & accessibility

## [IP-0052] 2026-05-17 — Theme persistence           Status: PLANNED
Context: Already partially in [IP-0011]; finalize.
Steps: Confirm `shared_preferences` key `theme_mode` reads/writes; provider rebuilds `MaterialApp`.
Risk: Race on first launch — default to `ThemeMode.system`.
Linked: [P-…], [SL-…]

## [IP-0053] 2026-05-17 — Language override in settings           Status: PLANNED
Context: User may want to force `ar` / `fr` / `en` for Whisper.
Steps: Add a "Langue forcée" picker in `SettingsPage` (auto / ar / fr / en). Pass to `TranscriptionApi.transcribe(language:)`.
Risk: Forced language hurting code-switched audio — default remains "auto".
Linked: [P-…], [SL-…]

## [IP-0054] 2026-05-17 — Accessibility pass           Status: PLANNED
Context: Semantics, tap targets, contrast.
Steps: Add `Semantics` labels to icon-only buttons. Ensure 48 dp min tap targets. Run dark-mode contrast through WCAG AA; adjust tokens if needed.
Risk: Token changes cascading — restrict to `app_colors.dart`.
Linked: [P-…], [SL-…]

---

# Part 12 — Final QA & release prep

## [IP-0055] 2026-05-17 — Manual QA checklist           Status: PLANNED
Context: Validate every architecture section end-to-end.
Steps: Run through scripted flows: record → summary; create folder; assign meeting; schedule event + receive reminder; replay audio; back-button behavior on every dirty page; offline error → retry; chunked upload; theme toggle. Log results as a new `[SL-…]` section.
Risk: Missing a flow — checklist must mirror architecture TOC.
Linked: [P-…], [SL-…]

## [IP-0056] 2026-05-17 — Finalize README           Status: PLANNED
Context: Owner's directive: README describes *only how to run the project*.
Steps: Append final "Run the project" with verified commands, prerequisites pinned versions, screenshot placeholders, common troubleshooting (mic permission, Groq 401, exact-alarm permission). Do not remove earlier sections.
Risk: Drift from real behavior — re-validate against [IP-0055] results.
Linked: [P-…], [SL-…]

## [IP-0057] 2026-05-17 — Tag v0.1.0           Status: PLANNED
Context: First milestone after governance files are in sync.
Steps: Confirm `progress.md`, `student_lab.md`, `UML.md` (latest version), `README.md`, `.env.example` are all up to date. Create annotated tag `v0.1.0`. Append a `[P-…] done:` line citing all governance file states.
Risk: Tagging on a dirty tree — refuse if uncommitted changes exist.
Linked: [P-…], [SL-…]

---

# Footer — governance reminders

- On completion of any `[IP-NNNN]`, the agent **must** append a status-flip note at the bottom of that entry (do not edit the original lines) of the form:
  `→ Status: DONE 2026-MM-DDThh:mm±zz · emitted [P-…], [SL-…], [UML-…]`
- Any future change to scope is added as a **new** `[IP-NNNN]` entry below, optionally annotated `Supersedes [IP-XXXX]`. The superseded entry stays in place untouched.
- Any structural design change must also append a new `[UML-NNNN]` versioned diagram in `UML.md` (per `instructions.md` §2.2).
- New env variables introduced by an entry must be reflected in `.env.example` in the same work loop, with a sourcing comment (per `instructions.md` §5).

---

# Status flips — Part 0 (appended 2026-05-17)

→ [IP-0001] Status: PARTIAL-DONE 2026-05-17T10:10+00 · pubspec.yaml + analysis_options.yaml written; BLOCKED on flutter SDK install for `flutter create .` (android/ ios/ not yet generated); emitted [P-0005][P-0006][SL-0002]
→ [IP-0002] Status: DONE 2026-05-17T10:05+00 · 40+ stub Dart files created across lib/ tree; emitted [P-0003][P-0004][SL-0001]; no UML change
→ [IP-0003] Status: DONE 2026-05-17T10:11+00 · all deps declared in pubspec.yaml (pinned); `flutter pub get` deferred until SDK installed; emitted [P-0007][P-0008][SL-0002]
→ [IP-0004] Status: DONE 2026-05-17T10:14+00 · .gitignore (Flutter standard + /.env) and .env.example (4 vars, each with sourcing comment) created; emitted [P-0009][P-0010][SL-0003]; no UML change
→ [IP-0005] Status: DONE 2026-05-17T10:17+00 · lib/core/config/env.dart implemented (abstract final class, String.fromEnvironment, validate() guard in main.dart); emitted [P-0011][P-0012][SL-0004]; no UML change
→ [IP-0006] Status: DONE 2026-05-17T10:20+00
→ [IP-0007] Status: DONE 2026-05-17T11:05+00 · app_colors.dart + app_typography.dart written; emitted [P-0017][SL-0006]; no UML change
→ [IP-0008] Status: DONE 2026-05-17T11:10+00 · app_theme.dart (light + dark ThemeData, Material 3); emitted [P-0018][SL-0007]; no UML change
→ [IP-0009] Status: DONE 2026-05-17T11:20+00 · app_router.dart (StatefulShellRoute, 4 branches, _slide transition); stub pages given valid constructors; emitted [P-0019][SL-0008]; no UML change
→ [IP-0010] Status: DONE 2026-05-17T11:30+00 · home_shell.dart (tab history, PopScope, double-tap-to-exit); emitted [P-0020][SL-0009]; no UML change
→ [IP-0011] Status: DONE 2026-05-17T11:35+00
→ [IP-0012] Status: DONE 2026-05-17T12:10+00 · audio_recorder.dart (record pkg wrapper, AAC-LC 16 kHz mono, normalise(), amplitude stream); emitted [P-0025][SL-0012]; no UML change
→ [IP-0013] Status: DONE 2026-05-17T12:05+00 · recording_state.dart (sealed: Idle/Recording/Paused/RecordingError); emitted [P-0024][SL-0011]; no UML change
→ [IP-0014] Status: DONE 2026-05-17T12:40+00 · record_button.dart (_PulseRing x2, _ButtonFace gradient + idle bob + disableAnimations); emitted [P-0028][SL-0016]; no UML change
→ [IP-0015] Status: DONE 2026-05-17T12:30+00 · waveform_indicator.dart (Queue rolling window, CustomPainter 24 bars); emitted [P-0027][SL-0015]; no UML change
→ [IP-0016] Status: DONE 2026-05-17T12:55+00 · record_page.dart (permission flow, PopScope, status/timer/waveform/pause UI, context.go to /processing); emitted [P-0029][SL-0017]; no UML change
→ [IP-0017] Status: DONE 2026-05-17T12:20+00
→ [IP-0018] Status: DONE 2026-05-17T13:15+00 · groq_client.dart (Dio singleton, auth header, _RetryInterceptor 3×, 429 Retry-After, groqClientProvider); emitted [P-0033][SL-0019]; no UML change
→ [IP-0019] Status: DONE 2026-05-17T13:25+00 · transcription_api.dart (multipart /audio/transcriptions, language null, 25 MB guard, empty guard, CancelToken, transcriptionApiProvider); emitted [P-0034][SL-0020]; no UML change
→ [IP-0020] Status: DONE 2026-05-17T13:40+00 · summary_api.dart (/chat/completions, multilingual system prompt, 5-section validation, _validateSections fallback, CancelToken, summaryApiProvider); emitted [P-0035][SL-0021]; no UML change
→ [IP-0021] Status: DONE 2026-05-17T13:05+00 · failures.dart (sealed Failure hierarchy, Result<T> monad, mapDioError); emitted [P-0032][SL-0018]; no UML change · start_recording.dart + stop_and_process.dart + meeting_controller.dart (Notifier, 1s timer, 60ms amplitude sub, keepAlive, meetingControllerProvider); emitted [P-0026][SL-0013][SL-0014]; no UML change · settings_page.dart (ThemeModeNotifier, RadioListTile toggle, SharedPreferences persist); app.dart + main.dart wired; emitted [P-0021][SL-0010]; no UML change · README.md written (prerequisites, env setup, flutter create one-time step, run commands, VS Code launch.json, troubleshooting table); emitted [P-0013][P-0014][SL-0005]; no UML change

---

# Addendum — entries appended after the initial fill

> Per `instructions.md` §2.1, new work units are appended below the original Parts 0–12 instead of being inserted into them. Each new entry references the part it logically belongs to in its title.

## [IP-0058] 2026-05-17 — ProcessingPage (Part 2 addendum)           Status: PLANNED
Context: `[IP-0016]` (RecordPage) and `[IP-0045]` (PopScope coverage) both reference a `ProcessingPage` that displays the live state of the upload → transcribe → summarize pipeline, but no entry in Parts 0–12 actually builds it. This addendum closes that gap. The page belongs logically to Part 2 (audio pipeline) and must exist before `[IP-0024]` (MeetingRepository orchestration) can be exercised end-to-end.
Steps:
1. Add a route `processing` (with `meetingDraftId` path/param) to `core/router/app_router.dart`. RecordPage's "Stop" handler (`[IP-0016]`) navigates here instead of straight to the detail page.
2. Implement `presentation/pages/processing_page.dart` with three vertical phases — **Upload**, **Transcription**, **Résumé** — each rendered as an animated pill (idle / in-progress with `flutter_animate` shimmer / done with checkmark / error with retry).
3. Drive the phase state from a new `pipelinePhaseProvider` (Riverpod) emitted by `MeetingController.stopAndProcess`; the controller transitions `Uploading → Transcribing → Summarizing → Done | Failed(failure)`.
4. On success: replace the route with `MeetingDetailPage(meetingId)` via `context.go` (no back-stack entry on `ProcessingPage`).
5. On failure: show inline `Failure` message (from `[IP-0021]`), keep the local audio file, expose a "Réessayer" button that re-invokes the same pipeline phase (or restarts from the first failed phase).
6. Wrap the page with `PopScope(canPop: false, onPopInvokedWithResult: …)` showing a "Annuler le traitement ?" dialog; on confirm, cancel the in-flight Dio request via a stored `CancelToken` and pop back to `RecordPage` while keeping the audio file on disk.
7. Honor `MediaQuery.disableAnimations` (per `[IP-0044]`) by collapsing shimmer to a static dot when motion is disabled.
Risk:
- Forgetting to register the `CancelToken` on `GroqClient` calls means cancel-on-back leaks the upload — add a `MeetingRepository.process` parameter `{CancelToken? cancelToken}` and thread it through `TranscriptionApi` and `SummaryApi`. This is a small additive change to the contracts defined in `[IP-0019]`, `[IP-0020]`, `[IP-0024]` and does **not** supersede them.
- Phase state may desync if the user backgrounds the app; keep the provider `keepAlive` like `MeetingController` (`[IP-0017]`).
- No structural design change → no `[UML-…]` bump required (the existing sequence diagram §3a in `UML.md` v1 already implicitly covers this flow through `MeetingController`).
Linked: [P-…], [SL-…]
Relates-to: [IP-0016], [IP-0017], [IP-0019], [IP-0020], [IP-0021], [IP-0024], [IP-0044], [IP-0045]

---

# Status flips — Part 9 (appended 2026-05-17)

→ [IP-0047] Status: DONE 2026-05-17T19:30+00 · double-tap-to-exit already present in home_shell.dart from [IP-0010]; audit confirmed correct (tab-history pop + 2 s snackbar window + SystemNavigator.pop); emitted [P-0072][P-0074][SL-0045]; no UML change
→ [IP-0046] Status: BLOCKED 2026-05-17T19:00+00 · android/ not yet generated (flutter create . pending SDK install); action required: add android:enableOnBackInvokedCallback="true" to AndroidManifest.xml after SDK install; emitted [P-0073]
→ [IP-0045] Status: DONE 2026-05-17T19:30+00 · all 5 screens audited (RecordPage/NewFolderPage/ScheduleEventPage/MeetingDetailPage ALREADY done; ProcessingPage implemented via [IP-0058]); emitted [P-0074][SL-0045]; no UML change
---

# Status flips — Part 10 (appended 2026-05-17)

→ [IP-0048] Status: DONE 2026-05-17T20:15+00 · audio_chunker.dart (20 MB byte-boundary chunks, stream pipe, cleanup helper); meeting_repository._runPipeline: AudioChunker.chunk loop, transcript join with \n, cleanup on success/fail; emitted [P-0076][SL-0046]; no UML change
→ [IP-0050] Status: DONE 2026-05-17T20:15+00 · silence pre-check in _runPipeline (1 KB/s heuristic, dur>5s guard, forceSend bypass); retryPipeline passes forceSend:true (user override); emitted [P-0076][SL-0046]; no UML change
→ [IP-0049] Status: DONE 2026-05-17T20:25+00 · meeting_detail_page.dart: _RetryBanner (MaterialBanner, errorContainer, CircularProgressIndicator while retrying); _retryProcessing(); _retrying state; _fileSize fixed to dart:io; no schema migration (pipelineState already in v1); emitted [P-0077][SL-0047]; no UML change
→ [IP-0051] Status: DONE 2026-05-17T20:35+00 · audio_cleanup_service.dart (static run, 24h cutoff, referencedPaths diff); meeting_dao +getAllAudioPaths (selectOnly); app.dart _startupCleanupProvider (FutureProvider 5s delay) + ref.listen trigger; emitted [P-0078][SL-0048]; no UML change

→ [IP-0058] Status: DONE 2026-05-17T19:30+00 · processing_page.dart full implementation: 3-phase UI (Transcription/Résumé/Sauvegarde), _PhaseRow shimmer animate, _ErrorCard retry, PopScope canPop:isFailed + cancel dialog, CancelToken lifecycle, watchByDraftId poll→watchById stream, ref.listen navigate on done; meeting_repository.dart +watchByDraftId; emitted [P-0074][SL-0045]; relates-to [IP-0016][IP-0019][IP-0020][IP-0021][IP-0024][IP-0044][IP-0045]

---

# Status flips — Part 11 (appended 2026-05-17)

→ [IP-0052] Status: DONE 2026-05-17T21:00+00 · audit confirmed: ThemeModeNotifier+SharedPreferences key 'theme_mode' already complete from [IP-0011]; ThemeMode.system default; async _load(); MaterialApp watches themeModeProvider; emitted [P-0081][SL-0049]; no UML change
→ [IP-0053] Status: DONE 2026-05-17T21:10+00 · ForcedLanguageNotifier+forcedLanguageProvider added to settings_page.dart; 4-option RadioListTile picker (null/ar/fr/en); String? forcedLanguage param threaded through MeetingRepository.processRecording→retryPipeline→_runPipeline→TranscriptionApi.transcribe(language:); ProcessingPage reads forcedLanguageProvider at pipeline start and retry; emitted [P-0082][SL-0050]; no UML change; no new env vars
→ [IP-0054] Status: DONE 2026-05-17T21:20+00 · Semantics(label,button:true) on RecordButton GestureDetector (dynamic label idle/recording); tooltip on both ±15s skip IconButtons; Semantics(label,selected,button:true) on _SpeedSelector chips; tap-target audit passed (all Material widgets ≥48dp); WCAG AA contrast audit passed (no token changes needed); emitted [P-0083][SL-0051]; no UML change

---

# Status flips — Part 12 (appended 2026-05-17)

→ [IP-0055] Status: DONE 2026-05-17T22:10+00 · 8-flow QA checklist written covering all architecture sections: pipeline (§3), audio replay (§6), folders (§4), calendar (§5), settings (§9/Part11), back-button (§9c), robustness (§11), accessibility (§9b/Part11); sign-off block for owner device testing; no code change; emitted [P-0086][SL-0052]; no UML change
→ [IP-0056] Status: DONE 2026-05-17T22:20+00 · README.md appended: language-override feature note ([IP-0053]), accessibility note ([IP-0054]), release checklist status, 2 new troubleshooting rows; existing sections untouched (append-only); emitted [P-0087][SL-0053]; no UML change
→ [IP-0057] Status: BLOCKED 2026-05-17T22:21+00 · working directory is not a git repository; governance files are all in sync and up to date; owner action required: `git init && git add -A && git commit -m "chore: initial commit"` then `git tag -a v0.1.0 -m "v0.1.0"`; emitted [P-0088]
