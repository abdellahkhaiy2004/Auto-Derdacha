# Student Lab — Auto-Derdacha

> Append-only pedagogical log. Each section documents *what was built, why, and how it fits the architecture*. Sections are appended as implementation progresses; nothing is rewritten.

---

### [SL-0001] 2026-05-17 — lib/ directory tree (IP-0002)

**What was created**

The full `lib/` skeleton from `architecture.md §2` — 40+ stub Dart files, each containing only a `// stub — [IP-XXXX]` comment pointing to the plan entry that will fill it. No logic yet; every file is valid Dart.

**Why stub files first**

Starting with a complete file tree prevents "file not found" import errors as individual features are built. Each stub declares its future responsibility through its filename and its `[IP-XXXX]` comment, making the codebase self-documenting from day one.

**Layer summary**

```
lib/
├── core/         — configuration, errors, theme, router, utilities (no Flutter widgets)
├── data/         — audio capture/playback wrappers, Groq HTTP clients, Drift DAOs, repositories
├── domain/       — pure Dart entities and use-cases (no framework dependencies)
├── presentation/ — Flutter pages, widgets, and Riverpod state notifiers
└── services/     — NotificationService (OS integration)
```

**Dependency direction:** `presentation` → `domain` ← `data`. The `domain` layer never imports `package:flutter`, `dio`, or `drift`.

---

### [SL-0002] 2026-05-17 — pubspec.yaml + analysis_options.yaml (IP-0001 partial, IP-0003)

**What was created**

`pubspec.yaml` declares all project dependencies with pinned minimum versions:

| Package | Role |
|---|---|
| `record ^5.1.2` | Microphone capture → `.m4a` file |
| `just_audio ^0.9.40` | Local audio playback with speed control |
| `dio ^5.4.3+1` | HTTP client for Groq API multipart + JSON calls |
| `flutter_riverpod ^2.5.1` | State management (providers, notifiers) |
| `go_router ^14.2.0` | Declarative routing with `StatefulShellRoute` |
| `flutter_markdown ^0.7.3` | Rendering the LLM-generated Markdown summary |
| `drift ^2.18.0` + `sqlite3_flutter_libs` | Typed local SQLite database |
| `table_calendar ^3.1.2` | Calendar view with custom day-cell builders |
| `flutter_local_notifications ^17.2.2` | Meeting reminders |
| `permission_handler ^11.3.1` | Mic + exact-alarm permissions at runtime |
| `google_fonts ^6.2.1` | Inter (Latin) + Cairo (Arabic/Darija) typefaces |
| `lucide_icons ^0.0.4` | Folder icon picker library |
| `flutter_animate ^4.5.0` | Declarative chained animations (floating, pulse) |
| `shared_preferences ^2.3.2` | Theme-mode persistence |

Dev-only: `drift_dev`, `build_runner`, `riverpod_generator` — generate typed Drift tables and Riverpod providers from annotations.

`analysis_options.yaml` enables `strict-casts`, `strict-inference`, `strict-raw-types` and adds lints for `prefer_const_constructors`, `avoid_print`, `unawaited_futures`, `cancel_subscriptions`. Violations are treated as errors for `missing_required_param` and `missing_return`.

**Why these choices**

- `drift` over `sqflite` directly: generates type-safe query APIs, eliminating raw SQL strings in application code.
- `go_router` over Navigator 2.0 manually: `StatefulShellRoute.indexedStack` gives each bottom-nav tab its own independent back-stack, which is required by `architecture.md §9c`.
- `flutter_animate` over hand-rolled `AnimationController`s: the declarative `.fadeIn().slideY().then()` chain is easier to audit for `MediaQuery.disableAnimations` compliance (`architecture.md §9b`).

**⚠ Action required**

Flutter SDK is not installed on this machine. Before `flutter pub get` can be run:

1. Install Flutter ≥ 3.16.0 from https://docs.flutter.dev/get-started/install.
2. Run `flutter create . --project-name auto_derdacha --org com.autoderdacha` to generate the `android/` and `ios/` platform directories.
3. Run `flutter pub get`.
4. Run `dart run build_runner build --delete-conflicting-outputs` (needed for Drift + Riverpod generators).

---

### [SL-0003] 2026-05-17 — .gitignore + .env.example (IP-0004)

**What was created**

`.gitignore` — standard Flutter ignore rules (build outputs, `.dart_tool/`, generated files, IDE configs, Android Gradle caches, iOS generated files) plus `/.env` at the bottom.

`.env.example` — the committed public template with four variables:

```
GROQ_API_KEY=          # obtain at console.groq.com/keys (free)
GROQ_BASE_URL=...      # default: https://api.groq.com/openai/v1
GROQ_STT_MODEL=...     # default: whisper-large-v3
GROQ_LLM_MODEL=...     # default: llama-3.3-70b-versatile
```

Each variable is preceded by a comment explaining where to obtain its value.

**How secrets flow into the app**

```
.env  →  flutter run --dart-define-from-file=.env  →  String.fromEnvironment(...)  →  Env class
```

`dart-define-from-file` inlines the values at **compile time** into the Dart binary. They are never stored in the app bundle as plain text files. This is the recommended approach for Flutter secrets that don't require server-side rotation.

**⚠ Action required for the owner**

```bash
cp .env.example .env
# open .env and set GROQ_API_KEY=<your key>
```

---

### [SL-0004] 2026-05-17 — lib/core/config/env.dart (IP-0005)

**What was created**

```dart
abstract final class Env {
  static const groqApiKey = String.fromEnvironment('GROQ_API_KEY');
  static const baseUrl    = String.fromEnvironment('GROQ_BASE_URL', defaultValue: '...');
  static const sttModel   = String.fromEnvironment('GROQ_STT_MODEL', defaultValue: '...');
  static const llmModel   = String.fromEnvironment('GROQ_LLM_MODEL', defaultValue: '...');

  static void validate() { /* throws StateError if groqApiKey is empty */ }
}
```

**Why `abstract final class`**

Prevents instantiation and subclassing. All members are `static const` — compiled to true constants, zero runtime overhead. `abstract` signals intent: this is not a data class, it is a namespace.

**Why `validate()` in `main()`**

Failing at startup with a clear error message (`GROQ_API_KEY is not set. Copy .env.example → .env ...`) is better than a cryptic 401 from the API 30 seconds into a recording. The validate guard is the only place that reads environment values; all other code uses `Env.*` constants.

**Where this is used**

- `data/remote/groq_client.dart` (`[IP-0018]`) — reads `Env.groqApiKey` and `Env.baseUrl` to configure the Dio client.
- `data/remote/transcription_api.dart` (`[IP-0019]`) — reads `Env.sttModel`.
- `data/remote/summary_api.dart` (`[IP-0020]`) — reads `Env.llmModel`.

---

### [SL-0005] 2026-05-17 — README.md initial content (IP-0006)

**What was created**

`README.md` with a single "How to run the project" section covering:

1. Prerequisites table (Flutter 3.16+, Dart 3.2+, Android SDK API 21+, JDK 17, Groq key).
2. Clone + env file setup (copy `.env.example` → `.env`, fill `GROQ_API_KEY`).
3. One-time `flutter create . --project-name auto_derdacha --org com.autoderdacha` to generate platform directories.
4. `flutter pub get` → `dart run build_runner build` → `flutter run --dart-define-from-file=.env`.
5. VS Code `launch.json` snippet for IDE runs.
6. Troubleshooting table (missing key, flutter not in PATH, mic permission, 401/429, notification permission).

**Governance note**

Per `instructions.md §1`, README is append-only.

---

### [SL-0006] 2026-05-17 — Palette & typography (IP-0007)

**What was created**

`lib/core/theme/app_colors.dart` — `abstract final class AppColors` with:
- Brand tokens: `primarySeed #7C3AED`, `secondary #06B6D4`, `tertiary #F59E0B`, `recording #EF4444`.
- Category tokens: `categoryWork #3B82F6`, `categorySchool #10B981`, `categoryFamily #F472B6`, `categoryPersonal #8B5CF6`.
- `darkSurface #0F172A` — base for dark-mode scaffold.
- `forCategory(String) → Color` — maps a category string key to its token.
- `contrastOn(Color) → Color` — returns black or white based on WCAG luminance (used by folder card labels).

`lib/core/theme/app_typography.dart` — `abstract final class AppTypography` with:
- `textTheme(ColorScheme)` — Inter via `google_fonts`, `displaySmall` overridden to w700.
- `cairo({...})` — Cairo font for Arabic/Darija content in transcripts and summaries.

**Why two separate fonts**

Inter is optimised for Latin character legibility at small sizes. Cairo covers the Arabic Unicode block, which Inter does not. Whenever a `Text` widget renders mixed-script content (Darija often uses Arabic script), the correct font is chosen by wrapping the widget in `DefaultTextStyle.merge(style: AppTypography.cairo())`.

---

### [SL-0007] 2026-05-17 — Light & dark ThemeData (IP-0008)

**What was created**

`lib/core/theme/app_theme.dart` — `abstract final class AppTheme` exporting `light` and `dark` getters, both produced by a single `_build(Brightness)` factory.

Key decisions:
- `ColorScheme.fromSeed(seedColor: #7C3AED)` generates the full 30-tone palette (primary, secondary, surface, error, etc.) deterministically from the brand purple. The dark variant sets `surface: AppColors.darkSurface` (#0F172A) to deepen the background beyond the auto-generated tone.
- Category colors are kept **outside** the seeded scheme (they live in `AppColors`) to prevent the tonal engine from desaturating them.
- Shape tokens: cards 16 px, FAB circle, inputs 12 px — all rounded as specified in architecture §9.
- `AppBarTheme` elevation=0, `centerTitle: false`, title w600 — gives a flat, document-like feel.
- `SnackBarTheme` floating + 12 px radius — matches the double-tap-to-exit snackbar in HomeShell.

---

### [SL-0008] 2026-05-17 — go_router + StatefulShellRoute (IP-0009)

**What was created**

`lib/core/router/app_router.dart` — a `routerProvider` (Riverpod `Provider<GoRouter>`) that wires all routes.

**Route tree**

```
StatefulShellRoute.indexedStack  ← HomeShell wraps all 4 tabs
  /record          → RecordPage
  /calendar        → CalendarPage
    /calendar/schedule → ScheduleEventPage
  /folders         → FoldersPage
    /folders/new                       → NewFolderPage
    /folders/:folderId                 → FolderDetailPage
      /folders/:folderId/meetings/:id  → MeetingDetailPage
  /settings        → SettingsPage

/processing/:draftId  ← above the shell (parentNavigatorKey: _rootNavKey)
```

**Why `StatefulShellRoute.indexedStack`**

Each branch maintains its own `Navigator` — tapping Calendar while inside a folder's meeting detail does not lose that folder's back-stack. The root shell's `PopScope` (in HomeShell) is the only place that decides what "back" means at the tab level.

**Page transition**

All routes use `_slide()`: fade + 4 % vertical slide in 280 ms (`Curves.easeOutCubic`), reversed in 200 ms (`easeInCubic`). The asymmetry makes navigation feel snappier on exit.

---

### [SL-0009] 2026-05-17 — HomeShell + tab history (IP-0010)

**What was created**

`lib/presentation/pages/home_shell.dart` — `ConsumerStatefulWidget` wrapping `StatefulNavigationShell`.

**Tab history algorithm**

```
_tabHistory: List<int>  (Riverpod StateProvider)

on tab tap(index):
  if index == currentIndex → no-op
  push currentIndex onto _tabHistory
  goBranch(index)

on back (PopScope.onPopInvokedWithResult):
  if _tabHistory non-empty → pop last, goBranch(last) → consumed
  else → double-tap-to-exit guard → SystemNavigator.pop()
```

This means Back on the Folders tab (after arriving from Calendar) returns to Calendar, not the OS home screen — matching the architecture §9c spec.

**Double-tap-to-exit guard**

A `DateTime? _lastBackPress` field tracks the first press. If a second back arrives within 2 s, `SystemNavigator.pop()` exits. Otherwise a snackbar "Appuyez encore pour quitter" is shown. `ScaffoldMessenger.clearSnackBars()` is called first to prevent stacking.

---

### [SL-0010] 2026-05-17 — Settings page + theme persistence (IP-0011)

**What was created**

`lib/presentation/pages/settings_page.dart`:
- `ThemeModeNotifier extends Notifier<ThemeMode>` — reads from `SharedPreferences` on `build()`, writes on `set(mode)`. Key: `theme_mode`. Values: `'light'`, `'dark'`, `'system'`.
- `themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>` — exposed at library level so `app.dart` can watch it.
- `SettingsPage` — three `RadioListTile` rows (Système / Clair / Sombre) plus an About tile.
- `_SectionHeader` — private helper rendering a coloured, slightly spaced label above a settings group.

**How the theme cascades**

```
SharedPreferences key "theme_mode"
  → ThemeModeNotifier (Riverpod)
  → themeModeProvider watched in App (ConsumerWidget)
  → MaterialApp.router(themeMode: ...)
  → Flutter rebuilds the entire widget tree with the new ThemeData
```

No app restart required. The `Notifier` pattern (rather than `StateNotifier`) is used because it receives the `ref` in `build()`, aligning with Riverpod 2.x best practices.

**Also wired in this step**

- `app.dart` updated: `MaterialApp` → `MaterialApp.router`, watches `routerProvider` and `themeModeProvider`, applies `AppTheme.light` / `AppTheme.dark`.
- `main.dart` updated: wrapped in `ProviderScope` (required for all Riverpod providers), calls `Env.validate()` before `runApp`.

---

### [SL-0011] 2026-05-17 — RecordingState sealed class (IP-0013)

**What was created**

`lib/data/audio/recording_state.dart` — a sealed class hierarchy that models every possible state the recorder can be in:

```
RecordingState (sealed)
├── Idle                            — nothing happening
├── Recording(elapsed, amplitude)   — mic is active; amplitude is 0.0–1.0
├── Paused(elapsed)                 — mic paused, timer frozen
└── RecordingError(message)         — something went wrong
```

**Why sealed**

Dart `sealed` classes force every `switch` expression that matches on them to be exhaustive at compile time. The UI (`RecordPage`, `_StatusLabel`, `_ElapsedTimer`) uses `switch (rs)` patterns — the compiler rejects unhandled cases. No runtime null-checks or `else` branches needed.

**Why `amplitude` is on `Recording` only**

Amplitude is only meaningful while the mic is open. Putting it on the base class would require nullable semantics everywhere. Carrying it on `Recording` keeps the type system honest.

---

### [SL-0012] 2026-05-17 — AudioRecorder wrapper (IP-0012)

**What was created**

`lib/data/audio/audio_recorder.dart` — a plain Dart class (no Flutter dependencies) wrapping `package:record`'s `AudioRecorder`.

Key decisions:
- **File path:** `<appDocs>/audio/<draftId>.m4a`. The `audio/` subdirectory is created on first use. The draft ID is provided by the caller (from `StartRecording` use-case) so the path is predictable.
- **Codec:** AAC-LC (`AudioEncoder.aacLc`), mono, 16 kHz — optimal for Whisper: speech-focused, small file size (~1 MB/min), within Groq's 25 MB limit for ~25-min meetings.
- **Amplitude stream:** exposed as a raw `Stream<pkg.Amplitude>` (throttled to 60 ms by the `record` package internally). Normalisation via `AudioRecorder.normalise(dbfs)` maps dBFS [-60, 0] linearly to [0.0, 1.0].
- **`stop()` returns `File?`:** null means the recording was empty or the file vanished — handled upstream by `StopAndProcess` use-case.

---

### [SL-0013] 2026-05-17 — StartRecording + StopAndProcess use-cases (IP-0017 partial)

**What was created**

`lib/domain/usecases/start_recording.dart` — pure Dart callable that generates a unique draft ID: `draft_<timestamp>_<4-digit-random>`. No framework, no async.

`lib/domain/usecases/stop_and_process.dart` — pure Dart callable that validates the stopped recording:
- Returns `null` if the audio file is missing or the elapsed time is < 2 s (too short for Whisper to produce meaningful output).
- Returns `RecordingResult(draftId, audioFile, duration, folderId?)` on success.

**Why validation here rather than in the controller**

Domain use-cases are the right place for business rules ("a valid recording must be at least 2 s long"). The controller handles orchestration; the use-case owns the policy.

---

### [SL-0014] 2026-05-17 — MeetingController (IP-0017)

**What was created**

`lib/presentation/state/meeting_controller.dart` — `Notifier<MeetingState>` managing the full recording lifecycle.

**State machine**

```
Idle ──startRecording()──► Recording ──pauseRecording()──► Paused
                              │                               │
                              └──stopAndProcess()──► result  └──resumeRecording()──► Recording
                              └──stopAndProcess()──► null ──► RecordingError
```

**Internal timers**

- `Timer.periodic(1s)` increments `_elapsed` and emits a new `Recording` state each second.
- `StreamSubscription<Amplitude>` from the recorder updates `amplitude` at 60 ms without blocking the timer.
- Both are cancelled on `pauseRecording()`, `stopAndProcess()`, and `ref.onDispose()`.

**`ref.keepAlive()`**

Without this, Riverpod would dispose the notifier as soon as no widget watched it (e.g., during navigation to `ProcessingPage`). `keepAlive()` pins it for the session, preventing mid-upload disposal. The audio file is safe even if navigation changes.

**`meetingControllerProvider`** is a `NotifierProvider` exported at library level so `RecordPage` and (later) `ProcessingPage` can both watch/read it.

---

### [SL-0015] 2026-05-17 — WaveformIndicator widget (IP-0015)

**What was created**

`lib/presentation/widgets/waveform_indicator.dart` — a `StatefulWidget` that maintains a rolling history of amplitude values and repaints a 24-bar waveform via `CustomPainter`.

**Rolling window pattern**

```dart
Queue<double> _history  // fixed length = barCount (24)
didUpdateWidget: _history.removeFirst(); _history.addLast(amplitude);
```

Each new amplitude value shifts the entire waveform left by one bar, creating the "scrolling" effect without any `Timer` — it repaints only when the parent passes a new `amplitude` value (driven by the controller's 60 ms stream).

**CustomPainter**

Draws `barCount` rounded rectangles. Bar height = `max(4px, amplitude × maxHeight)` — the 4 px floor keeps silent bars visible as a baseline. `shouldRepaint` compares bar list reference, so unchanged state causes zero canvas work.

---

### [SL-0016] 2026-05-17 — RecordButton widget (IP-0014)

**What was created**

`lib/presentation/widgets/record_button.dart` — composite widget with two child classes:

**`_PulseRing`** (active state)  
Uses `AnimatedBuilder` on the shared `AnimationController`. Two rings with `delay` offsets (0.0 and 0.4) create a staggered pulse. Ring radius grows from `size` to `size + 40px`; opacity fades from 0.5 → 0 over 1.2 s, looping.

**`_ButtonFace`** (always shown)  
Gradient circular container: purple→pink when idle, red→light-red when recording. `AnimatedSwitcher` cross-fades the mic ↔ stop icon. When idle and motion enabled, `flutter_animate` adds a slow scale bob (1.0 ↔ 1.04, 2.2 s, easeInOut, reversed loop). When `MediaQuery.disableAnimations` is true, all animation is skipped — the button still responds to taps, just without motion.

---

### [SL-0017] 2026-05-17 — RecordPage (IP-0016)

**What was created**

`lib/presentation/pages/record_page.dart` — the first tab of the bottom-nav shell. Accepts optional `folderId` and `eventId` query params (for folder FAB and notification deep-links from [IP-0038]/[IP-0039]).

**Layout**

```
AppBar (+ Reprendre button when paused)
├── _ErrorBanner (MaterialBanner, conditional)
└── Column (centered)
    ├── _StatusLabel   — AnimatedSwitcher between state strings
    ├── _ElapsedTimer  — tabular-figures monospaced mm:ss or h:mm:ss
    ├── RecordButton   — 88px, drives start / stop
    ├── WaveformIndicator (AnimatedOpacity, only shown while recording)
    └── Pause / hint text
```

**Permission flow**

`_ensureMicPermission()` checks `Permission.microphone.status` first (avoids re-prompting). If permanently denied, shows a dialog with an "Open Settings" action via `openAppSettings()`.

**Navigation on stop**

`context.go('/processing/${result.draftId}')` — uses `go` (not `push`) so the user cannot swipe back to an empty RecordPage while processing is in flight. The `MeetingController` holds the audio file path regardless.

**Android back (PopScope)**

`canPop: !isActive` — hardware back is blocked while `isRecording || isPaused`. A confirmation dialog ("Arrêter l'enregistrement ?") resolves the pop safely by calling `stopAndProcess()` first.

---

### [SL-0018] 2026-05-17 — Failure hierarchy + Result type (IP-0021)

**What was created**

`lib/core/errors/failures.dart` — two interrelated constructs:

**Sealed `Failure` hierarchy**

```
Failure (sealed)
├── NetworkFailure        — no connection, timeout
├── ApiFailure(status)    — non-2xx HTTP status from Groq
├── PermissionFailure     — mic / notification permission denied
├── FileTooLargeFailure   — audio > 25 MB even after chunking
├── EmptyAudioFailure     — silence or zero-length file
└── CancelledFailure      — user cancelled via ProcessingPage back-button
```

**`Result<T>` sealed monad**

```dart
sealed class Result<T>
  Ok<T>(value)    — success path
  Err<T>(failure) — typed failure, no stack-trace pollution
```

Methods: `isOk`, `isErr`, `getOrThrow()`, `map<R>()`.

**`mapDioError(DioException) → Failure`**

Central translation layer between the HTTP client and the domain. Handles cancel → `CancelledFailure`, timeouts → `NetworkFailure`, status codes → `ApiFailure` (extracts `error.message` from Groq's error JSON shape `{"error":{"message":"..."}}`), fallback → `NetworkFailure`.

**Why a sealed Result rather than throwing**

Exceptions leak through call stacks silently. A `Result<T>` forces every caller to acknowledge both paths at compile time. The `MeetingRepository` (Part 4) will return `Result<Meeting>` to the controller, which surfaces the `Failure` to the UI.

---

### [SL-0019] 2026-05-17 — GroqClient with retry interceptor (IP-0018)

**What was created**

`lib/data/remote/groq_client.dart` — a wrapper around a single `Dio` instance, shared across API classes via `groqClientProvider`.

**Configuration**

| Setting | Value | Reason |
|---|---|---|
| `baseUrl` | `Env.baseUrl` | Configurable for mirrors |
| `connectTimeout` | 30 s | Avoids hanging on poor connectivity |
| `receiveTimeout` | 120 s | Transcription of long meetings can take time |
| `Authorization` | `Bearer ${Env.groqApiKey}` | Required by Groq for every request |

**`_RetryInterceptor`**

Intercepts `onError`. Retries on `429` (rate-limited) and `5xx` (server error) up to 3 times with delays of 500 ms → 1 s → 2 s. On `429`, honours the `Retry-After` response header (clamped to [500 ms, 30 s]) before falling back to the schedule. Cancelled requests bypass retry entirely. Retry count is tracked in `requestOptions.extra['_attempt']` so it survives Dio's internal re-issue path.

**`groqClientProvider`**

`Provider<GroqClient>` — Riverpod ensures a single instance is created once and shared. `TranscriptionApi` and `SummaryApi` both watch this provider, so they share the same connection pool and interceptors.

---

### [SL-0020] 2026-05-17 — TranscriptionApi (IP-0019)

**What was created**

`lib/data/remote/transcription_api.dart` — posts a multipart audio file to Groq's `/audio/transcriptions` endpoint.

**Key decisions**

- **`language: null` by default** — Whisper auto-detects language when `language` is omitted. This is essential for Darija / FR / EN code-switching — forcing `ar` or `fr` would cause Whisper to hallucinate or ignore the other language. A `language` override is available for the Settings-page forced-language feature ([IP-0053]).
- **File size guard** — returns `Err(FileTooLargeFailure())` immediately if the file exceeds 25 MB, before making a network call. The chunking use-case ([IP-0048]) is expected to have pre-split large files before calling this API.
- **Empty transcript guard** — an empty or whitespace-only `text` in the response is treated as `EmptyAudioFailure`, not a success.
- **`CancelToken?`** — threaded through to `_client.dio.post()` so `ProcessingPage`'s back-button can abort the upload mid-flight without leaving a dangling request.

**`transcriptionApiProvider`** — `Provider<TranscriptionApi>` watches `groqClientProvider`; dependency injected, no singleton state of its own.

---

### [SL-0021] 2026-05-17 — SummaryApi with multilingual prompt (IP-0020)

**What was created**

`lib/data/remote/summary_api.dart` — posts the transcript to Groq's `/chat/completions` endpoint and returns structured Markdown.

**System prompt design**

The prompt (`_systemPrompt`) gives the model five responsibilities:
1. Detect dominant language (Darija / French / English).
2. Write entirely in that language.
3. Preserve proper nouns verbatim.
4. Emit **exactly** these five Markdown sections in order: `## Participants`, `## Décisions`, `## Action items`, `## Risques / Points ouverts`, `## Résumé global`.
5. Use "Aucun" when a section has no content.

A concrete few-shot example is embedded in the prompt so the model learns the exact output format before seeing the actual transcript. `temperature: 0.2` keeps the output deterministic and close to the transcript facts.

**`_validateSections()`**

After receiving the LLM response, the API checks that all five required headings are present. Any missing section is appended with "Aucun". This prevents `flutter_markdown` from rendering an incomplete card and protects the summary-section parser ([IP-0041]) from crashing on a missing heading.

**`_extractContent()`**

Navigates the OpenAI-compatible response shape `choices[0].message.content` with defensive null checks — avoids crashing if Groq changes its schema slightly.

**`summaryApiProvider`** — same pattern as `transcriptionApiProvider`; watches `groqClientProvider`. Future sections (screenshots, architecture summary for contributors) are appended below the existing content; the "How to run" section is never edited except to correct commands after `[IP-0055]` (final QA).

---

### [SL-0022] 2026-05-17 — Domain entities (IP-0022)

**What was created**

Five pure-Dart files under `lib/domain/entities/` — zero Flutter or Drift imports:

| File | Purpose |
|---|---|
| `category.dart` | `enum Category` with 7 values (work/education/personal/health/finance/legal/other) + French `label` getter |
| `folder.dart` | `Folder` entity with `copyWith` |
| `meeting.dart` | `PipelineState` enum (pending/transcribing/summarizing/done/failed) + `Meeting` entity with `copyWith` |
| `calendar_event.dart` | `CalendarEvent` entity with `copyWith` |
| `summary_section.dart` | `SummarySection` with `SummarySection.parse(String markdown)` static factory |

**Why pure-Dart domain entities**

The domain layer (`lib/domain/`) must never import `package:flutter`, `package:drift`, or `package:dio`. This isolation allows use-cases and business logic to be unit-tested without a widget tree or database. Drift's generated row classes (`FolderData`, `MeetingData`, `CalendarEventData`) live in `lib/data/local/` and are mapped to domain entities inside repositories — the UI never touches DB rows directly.

**`PipelineState` inline in `meeting.dart`**

Rather than a separate file, `PipelineState` lives alongside `Meeting` because it is exclusively a property of a `Meeting`. It is stored as a plain string in SQLite (`'pending'`, `'done'`, etc.) and parsed back in `MeetingRepository._parsePipelineState()`.

**`SummarySection.parse()`**

Splits the LLM Markdown on `## ` headings so each section can be rendered as a separate animated card ([IP-0041]). Avoids pulling in a Markdown parser in the domain layer — the raw string is still passed to `flutter_markdown` for rendering.

---

### [SL-0023] 2026-05-17 — Drift schema + Inbox seed (IP-0022)

**What was created**

`lib/data/local/tables.dart` — three Drift `Table` subclasses:

```
Folders           → FolderData      (avoids domain entity name collision)
Meetings          → MeetingData
CalendarEvents    → CalendarEventData
```

`lib/data/local/app_database.dart` — `@DriftDatabase`, `LazyDatabase`, migration v1.

**`@DataClassName` — avoiding name collisions**

Without this annotation, Drift generates a row class named `Folder`, `Meeting`, `CalendarEvent` — identical to the domain entities. Adding `@DataClassName('FolderData')` etc. renames the generated class so both can coexist in the same import scope.

**Migration v1 — Inbox seed**

`MigrationStrategy.onCreate` calls `m.createAll()` then inserts one row into `folders` with `isInbox = true`, name `'Boîte de réception'`, icon `'inbox'`. This ensures there is always a default destination for recordings made before the user creates any folder.

**Why `LazyDatabase` with `NativeDatabase.createInBackground`**

`LazyDatabase` defers opening the file until the first query, so app startup is not blocked. `createInBackground` opens and migrates the database on a background isolate — avoids jank on the main thread during the first launch.

**`path` package**

`p.join(dbFolder.path, 'auto_derdacha.db')` requires `package:path`. Added to `pubspec.yaml` as `path: ^1.9.0` in this same step.

**Indices**

Two index declarations on `Meetings` (`folder_id`, `created_at DESC`) and one on `CalendarEvents` (`starts_at`) speed up the most common queries: listing a folder's meetings and fetching calendar dots for a date range.

---

### [SL-0024] 2026-05-17 — DAOs (IP-0023)

**What was created**

Three `@DriftAccessor` classes:

| DAO | Key operations |
|---|---|
| `FolderDao` | `watchAll()` stream, `getInbox()`, `countMeetings(folderId)`, insert/update/delete |
| `MeetingDao` | `watchByFolder()` / `watchById()` streams, `updatePipelineState()`, `updateTranscript()`, `updateSummary()`, `moveToFolder()`, `linkEvent()` |
| `EventDao` | `watchByDateRange()` / `getByDateRange()`, `linkMeeting()`, CRUD |

**Why separate DAO per table**

Each DAO is declared with `@DriftAccessor(tables: [T])` and mixed into `AppDatabase` via the generated `_$*DaoMixin`. Keeping them separate makes each DAO independently testable and keeps the `AppDatabase` class thin.

**`updatePipelineState` / `updateTranscript` / `updateSummary`**

Three targeted partial-update methods replace a single `save(Meeting)` so the repository can update one column at a time without a read-modify-write race. `MeetingDetailPage` and `ProcessingPage` watch `watchById()` and will automatically receive each incremental update.

**`countMeetings(folderId)` in FolderDao**

Uses `selectOnly` with `meetings.id.count()` — a single SQL `COUNT(*)` query rather than loading all meeting rows. `FolderCard` calls this once per folder card to display the badge count.

---

### [SL-0025] 2026-05-17 — Repositories (IP-0024, IP-0025)

**What was created**

| Repository | Orchestrates |
|---|---|
| `MeetingRepository` | transcribe → summarize → persist pipeline; retry; watch streams |
| `FolderRepository` | CRUD + meeting-count enrichment; Inbox protection |
| `CalendarRepository` | event scheduling persistence; meeting linkage |

**`MeetingRepository.processRecording()` — the pipeline**

```
1. INSERT row (pipelineState = 'pending')  ← ProcessingPage starts watching
2. updatePipelineState('transcribing')
3. TranscriptionApi.transcribe(audioFile)  ← network
4. updateTranscript(transcript)
5. updatePipelineState('summarizing')
6. SummaryApi.summarize(transcript)        ← network
7. updateSummary(summary, detectedLang) + pipelineState = 'done'
8. return Ok(Meeting)
```

Each step writes to the DB before the network call, so `ProcessingPage` (which watches `watchById()`) shows live progress. On any failure the state flips to `'failed'` and the `Result<Err>` is returned — the UI can offer a retry without re-recording.

**`FolderRepository.deleteById()` — Inbox protection**

The method checks `row.isInbox` before calling `_dao.deleteById()`. If the caller passes the Inbox id the call is a silent no-op. The DB-level protection (`onDelete: KeyAction.setDefault` on `Meetings.folderId`) moves orphaned meetings back to folderId 1 (Inbox) on any folder deletion, maintaining referential integrity.

**`_heuristicLang()` in MeetingRepository**

A simple regex check: Arabic Unicode block → `'ar'`, French accented characters → `'fr'`, fallback `'en'`. This is a local heuristic only — Whisper's own language detection (embedded in the transcript metadata, if `response_format` were `verbose_json`) is the authoritative source for [IP-0053]'s settings override feature.

**`CalendarRepository.scheduleEvent()`**

Persists the event row and returns the new `id`. The caller (`ScheduleEventPage`) is expected to pass this id to `NotificationService.schedule()` ([IP-0038]) after inserting — keeping the repository ignorant of OS-level scheduling.

**No new env vars in Part 4** — all persistence is local SQLite; no API keys needed.

---

### [SL-0026] 2026-05-17 — AudioPlayerNotifier (IP-0026)

**What was created**

`lib/data/audio/audio_player.dart` — a thin Riverpod wrapper around `just_audio`.

**`AudioPlayerState`**

Immutable value object holding: `isPlaying`, `position`, `duration`, `speed`, `isLoading`, `hasError`, `errorMessage`, `isCompleted`. All updated via `copyWith` to avoid partial mutations.

**`AudioPlayerNotifier extends AutoDisposeNotifier<AudioPlayerState>`**

Owns a `ja.AudioPlayer` instance and three `StreamSubscription`s:
- `positionStream` → updates `position` on every tick (just_audio throttles to ~16 ms).
- `playerStateStream` → updates `isPlaying`; detects `ProcessingState.completed` and auto-seeks to `Duration.zero` so the slider resets cleanly.
- `durationStream` → updates `duration` once the file is loaded.

`ref.onDispose()` cancels subscriptions and calls `_player.dispose()` — prevents memory leaks when the detail page is popped.

**`load(String filePath)`**

Sets `isLoading = true`, calls `_player.setFilePath(path)`, captures the returned duration. On error sets `hasError` so the player bar can show an error icon instead of crashing.

**`AutoDispose` — why not `keepAlive`**

The player is only needed while `MeetingDetailPage` is mounted. AutoDispose automatically tears it down when the page is popped, freeing the audio decoder and the file handle. If the user re-opens the page, a fresh notifier is built and `load()` is called again.

---

### [SL-0027] 2026-05-17 — AudioPlayerBar widget (IP-0027)

**What was created**

`lib/presentation/widgets/audio_player_bar.dart` — sticky bottom bar for MeetingDetailPage.

**Layout**

```
Material (elevation 8, surfaceContainerHighest)
└── Column
    ├── SliderTheme > Slider          ← seek, 30 ms debounce
    ├── Row: position label / duration label
    └── Row
        ├── _SpeedSelector (0.75× / 1× / 1.5× / 2×)
        ├── _PlayPauseButton (AnimatedSwitcher)
        └── Row: replay_15 / forward_15
```

**30 ms seek debounce**

`_draggingValue` holds the slider position while the user drags. A `Timer(30ms)` fires `notifier.seek()` only after the finger pauses. Without debouncing, every pixel of drag fires a seek, flooding just_audio's event queue and causing audible stuttering.

**`_PlayPauseButton`**

Three states: loading → `CircularProgressIndicator`; error → disabled error icon; normal → `AnimatedSwitcher` swapping play↔pause icons with a 200 ms cross-fade. `IconButton.filled` uses `colorScheme.primary` automatically.

**`_SpeedSelector`**

Four small `AnimatedContainer` chips. The selected chip fills with `colorScheme.primary` (200 ms animation). Tapping calls `notifier.setSpeed(speed)` which both updates just_audio and persists the value in `AudioPlayerState`.

**Skip ±15 s**

`replay_15_rounded` / `forward_15_rounded` icons call `notifier.seek()` with position clamped to `[Duration.zero, state.duration]` — never seeks past end or before start.

---

### [SL-0028] 2026-05-17 — MeetingDetailPage (IP-0028)

**What was created**

`lib/presentation/pages/meeting_detail_page.dart` — full detail page wired to repositories, audio player, and three content tabs.

**State architecture**

```
_meetingStreamProvider(id)    ← StreamProvider.autoDispose.family
  watches MeetingRepository.watchById(id)
  drives the entire page via .when(loading/error/data)

audioPlayerProvider            ← AutoDisposeNotifierProvider
  initialized with meeting.audioPath on first frame
  drives AudioPlayerBar
```

Using a stream provider means the page reacts live to pipeline state changes — the progress banner and pipeline status label update automatically when `MeetingRepository._runPipeline()` writes to the DB from `ProcessingPage` ([IP-0058]).

**`_loadAudioOnce()`**

Guards with a `bool _audioLoaded` flag so `load()` is called exactly once even though `build()` may re-run many times as the stream emits. Uses `addPostFrameCallback` to defer the file I/O past the first paint.

**`PopScope.onPopInvokedWithResult`**

Calls `ref.read(audioPlayerProvider.notifier).pause()` before the page is removed. Prevents audio continuing in the background when the user navigates away — architecture §9c (back-button hardening).

**Tab structure**

| Tab | Content |
|---|---|
| Résumé | `Markdown` widget with `selectable: true` — full typography from palette |
| Transcript | `SelectableText` with copy-to-clipboard button |
| Infos | Info rows (language, duration, file size, pipeline state, draftId) + Re-summarize button |

**AppBar overflow menu**

Five actions: Rename (AlertDialog + TextField), Déplacer (modal bottom sheet with folder list from `folderRepositoryProvider`), Copier le résumé (clipboard), Re-résumer (calls `meetingRepositoryProvider.reSummarize()`), Supprimer (confirmation dialog → pop on success).

**`reSummarize()` added to `MeetingRepository`**

Re-runs only the summarization step using the already-stored transcript. Sets state to `'summarizing'` before the API call and `'done'` on success, so `ProcessingPage` watchers (if open) also see the update.

---

### [SL-0029] 2026-05-17 — Hero transitions (IP-0029)

**What was created**

Hero tags on the meeting title in `MeetingDetailPage`. The list-row counterpart will be added in `FolderDetailPage` ([IP-0033]).

**Tag convention**

```dart
Hero(tag: 'meeting_title_$meetingId', child: Text(meeting.title))
```

The tag is scoped to the meeting id so navigating to two different meetings simultaneously (e.g., from folder and calendar surfaces) does not produce a Hero conflict. The `flightShuttleBuilder` returns a `FadeTransition` so the text dissolves smoothly rather than using Flutter's default cropped-box animation.

**Why `Material(color: Colors.transparent)` wrapper inside Hero**

Text widgets inside a Hero flight lose their `DefaultTextStyle` context. Wrapping in a transparent `Material` reinstates the `TextStyle` inheritance chain during the flight, preventing font weight/color flickering on iOS.

**Counterpart in IP-0033**

`FolderDetailPage` (meeting list rows) will add the matching `Hero(tag: 'meeting_title_${meeting.id}')` around the title in each list tile. No code change needed in `MeetingDetailPage` — the tag is already there.

**No new env vars in Part 5** — no API keys added.

---

### [SL-0030] 2026-05-17 — AppColors extension + FolderCard widget (IP-0030)

**What was updated / created**

`lib/core/theme/app_colors.dart` — extended with:
- Full 7-token category palette: `categoryWork` (blue) / `categoryEducation` (emerald) / `categoryPersonal` (violet) / `categoryHealth` (red) / `categoryFinance` (amber) / `categoryLegal` (slate) / `categoryOther` (purple seed)
- `folderSwatches` — 12 preset `Color` values for the NewFolderPage colour picker
- `forCategoryEnum(Category)` — type-safe switch on the `Category` enum
- `hexToColor(String hex)` — converts a 6-char hex string (from DB) to `Color`
- Legacy keys `'school'` / `'family'` preserved in `forCategory(String)` for backwards-compat

`lib/presentation/widgets/folder_card.dart` — new file with:

**`FolderCard` gradient card**

```
Hero(tag: 'folder_card_$id')
└── Material (transparent, borderRadius 20)
    └── InkWell (onTap)
        └── Ink (LinearGradient topLeft→bottomRight: baseColor → baseColor@70%)
            └── Padding(16)
                ├── Icon container (white@20%, radius 10)
                ├── Spacer
                ├── Text: folder.name (bold, contrastOn textColor)
                └── Text: meeting count
```

`AppColors.hexToColor(folder.colorHex)` → `baseColor`. Text color computed with `AppColors.contrastOn(baseColor)` — automatically black on light cards, white on dark. Drop shadow uses `baseColor@30%` so the glow matches the folder colour.

**`folderIconForName(String)` top-level function**

Maps 19 icon-name strings to `IconData` (currently `Icons.*_rounded`, ready to be swapped to `LucideIcons` once the package is updated). Exported so `NewFolderPage._IconPicker` shows identical icons to the card.

**Idle bob animation deferred to IP-0040 (Part 8)** — the `FolderCard` structure is animation-ready; `flutter_animate` calls will be wrapped around the card in Part 8.

---

### [SL-0031] 2026-05-17 — FolderController + AssignMeetingToFolder (IP-0034)

**What was created**

`lib/presentation/state/folder_controller.dart`:
- `foldersStreamProvider` — `StreamProvider<List<Folder>>` watching `FolderRepository.watchAll()`; consumed by `FoldersPage` and move-to-folder sheets throughout the app
- `folderStreamProvider` — `StreamProvider.autoDispose.family<Folder?, int>` by id; consumed by `FolderDetailPage` AppBar
- `FolderController extends Notifier<void>` — mutation entry point: `createFolder`, `renameFolder`, `updateFolder`, `deleteFolder`; reads `folderRepositoryProvider` via `ref.read` (mutations, not watches)

`lib/domain/usecases/assign_meeting_to_folder.dart`:
- `AssignMeetingToFolder.call(meetingId, targetFolderId)` — validates target folder exists before calling `MeetingRepository.moveToFolder()`, returns `bool` success
- `assignMeetingToFolderProvider` — wires both repositories

**Why `Notifier<void>`**

`FolderController` does not hold UI state itself — the reactive list comes from `foldersStreamProvider` (stream). Using `Notifier<void>` keeps the controller as a pure command object without duplicating state that the stream already provides. Pages watch the stream provider; call the notifier for mutations.

---

### [SL-0032] 2026-05-17 — FoldersPage grid (IP-0031)

**What was created**

`lib/presentation/pages/folders_page.dart` — `ConsumerWidget` showing a 2-column `GridView.builder`.

**`GridView` configuration**

```dart
SliverGridDelegateWithFixedCrossAxisCount(
  crossAxisCount: 2,
  crossAxisSpacing: 12,
  mainAxisSpacing: 12,
  childAspectRatio: 0.85,   // slightly taller than square for name readability
)
```

`GridView.builder` is lazy — only builds the cards visible on screen, safe for large libraries.

**Empty state**

When `folders` is empty, `_EmptyState` renders a centred column: folder-open icon (primary@60%), headline, body text, and a `FilledButton` deep-linking to `/folders/new`. This CTA is the first-launch onboarding path.

**FAB**

Only shown when there is at least one folder (so it does not overlap the empty-state CTA). `heroTag: 'fab_folders'` prevents Hero conflicts with the FAB in `FolderDetailPage`.

---

### [SL-0033] 2026-05-17 — NewFolderPage (IP-0032)

**What was created**

`lib/presentation/pages/new_folder_page.dart` — form page, `ConsumerStatefulWidget`.

**Form fields**

| Field | Widget | Notes |
|---|---|---|
| Name | `TextFormField` | required, `TextCapitalization.sentences` |
| Category | `_CategoryPicker` (ChoiceChips) | drives `AppColors.forCategoryEnum` tint |
| Colour | `_ColorSwatches` (12 circles) | `AnimatedContainer` check mark on selection |
| Icon | `_IconPicker` (Wrap of 44×44 containers) | 19 icon names, accentColor fill when selected |

**`_PreviewCard`**

Live preview of the final card appearance — re-renders on every `setState`. Uses the same gradient and icon logic as `FolderCard` so WYSIWYG.

**Dirty-form `PopScope`**

`canPop: false` unconditionally. `onPopInvokedWithResult` computes `_isDirty` (any field differs from defaults) before showing the "Abandonner ?" bottom sheet. If the user confirms, `context.pop()` is called manually. This matches architecture §9c (back-button hardening, IP-0045/IP-0032).

**Save flow**

1. Validate form (`_formKey.currentState!.validate()`)
2. Convert `Color` → 6-char hex via `.value.toRadixString(16).substring(2)`
3. `ref.read(folderControllerProvider.notifier).createFolder(...)`
4. `context.pop()` on success

---

### [SL-0034] 2026-05-17 — FolderDetailPage + Hero counterparts (IP-0033, IP-0029)

**What was created**

`lib/presentation/pages/folder_detail_page.dart` — `ConsumerStatefulWidget`.

**Layout**

```
Scaffold
├── AppBar (folder.name, categoryColor background, sort toggle, delete overflow)
├── body: ListView.builder of _MeetingTile rows
└── FAB: mic icon → context.go('/record?folderId=...')
```

**Category colour band**

The AppBar's `backgroundColor` is set to `AppColors.forCategory(folder.category)` and `foregroundColor` to `AppColors.contrastOn(categoryColor)`. This gives each folder its own branded header without touching the global theme.

**Sort toggle**

Local `_SortMode` enum (date / duration). Button icon swaps between `schedule_rounded` and `timer_rounded`. Sort is applied in `_sort()` before the `ListView.builder` call — no re-fetch needed.

**`_MeetingTile` — Hero counterpart**

```dart
Hero(
  tag: 'meeting_title_${meeting.id}',
  child: Material(color: Colors.transparent,
    child: Text(meeting.title)),
)
```

This completes the Hero pairing with `MeetingDetailPage`'s AppBar title ([IP-0029]). The `_shuttle` builder cross-fades push↔pop.

**`_DurationChip`**

Three visual states: active pipeline (amber tertiaryContainer + "…"), failed (red errorContainer + "!"), done (secondaryContainer + "mm:ss"). The UI always conveys pipeline state even from the list view.

**Long-press → move sheet**

`onLongPress: onMove` opens the same modal bottom sheet pattern used in `MeetingDetailPage`, listing all folders from `folderRepositoryProvider.watchAll()`. The current folder's tile is shown as `selected` and `enabled: false`.

**FAB**

`context.go('/record?folderId=$folderId')` — deep-links to `RecordPage` with this folder pre-selected. `heroTag: 'fab_record_folder_$folderId'` scoped per folder to avoid Hero conflicts when navigating between folder detail pages.

**Delete folder guard**

Shown in the PopupMenu only when `!folder.isInbox`. AlertDialog confirms before calling `folderControllerProvider.notifier.deleteFolder(id)`. The Drift FK `onDelete:setDefault` automatically moves meetings to the Inbox row.

**No new env vars in Part 6** — all local UI + DB operations.

---

### [SL-0035] 2026-05-17 — NotificationService (IP-0038)

**What was created**

`lib/services/notification_service.dart` — singleton wrapping `flutter_local_notifications`.

**Initialisation path**

`main()` now calls `WidgetsFlutterBinding.ensureInitialized()` then `NotificationService.instance.init()` before `runApp`. `init()`:
1. Calls `tz_data.initializeTimeZones()` — required for `zonedSchedule`.
2. Initialises `FlutterLocalNotificationsPlugin` with Android + iOS settings.
3. Creates the Android notification channel `'meeting_reminders'` (importance: max) — must exist before any notification is shown.
4. Wires `onDidReceiveNotificationResponse` → `_onResponse` → `_onTap` callback.

**`schedule()` method**

Uses `zonedSchedule` with `AndroidScheduleMode.exactAllowWhileIdle` — fires even in Doze mode. Payload is JSON: `{"folderId": N, "eventId": N}`. On tap, `_onResponse` parses the payload and calls `_onTap('/record?folderId=N&eventId=N')`.

**Deep-link binding**

`app.dart` calls `NotificationService.instance.bindOnTap(router.go)` in `build()`. Since `build()` is re-entrant, the callback is just replaced with the same closure — no side-effect. This keeps the service ignorant of Riverpod while still allowing navigation.

**`requestExactAlarmPermission()`**

Wraps `Permission.scheduleExactAlarm` from `permission_handler` (Android 13+ exact-alarm requirement). `ScheduleEventPage` calls it before `schedule()` and shows a `SnackBar` if denied — the event is saved but no OS alarm is created.

**`timezone` package added** — `timezone: ^0.9.4` added to `pubspec.yaml`. This is a transitive requirement of `flutter_local_notifications` for `zonedSchedule`.

**`_onBackgroundResponse`** — top-level function annotated with `@pragma('vm:entry-point')`. Navigation is not possible from a background isolate; the foreground handler fires when the app is resumed.

---

### [SL-0036] 2026-05-17 — CalendarController (IP-0035 prep)

**What was created**

`lib/presentation/state/calendar_controller.dart` — `Notifier<CalendarState>`.

**`CalendarState`** holds: `focusedDay`, `selectedDay`, `events` (Map keyed by `DateTime.utc(y,m,d)`), `meetings` (same key structure), `isLoading`.

**`fetchForMonth(month)`**

Fetches calendar events and past meetings for the entire month via `CalendarRepository.getByDateRange` and `MeetingRepository.getByDateRange` in parallel. Builds two maps keyed by `_dayKey(dt) = DateTime.utc(dt.year, dt.month, dt.day)` — stripping time ensures lookups always hit regardless of the exact timestamp stored.

**Why UTC keys**

Using UTC midnight avoids DST edge cases where `DateTime.now().day` and `DateTime(y,m,d)` could differ by one hour in local time comparisons. `table_calendar` compares days with `isSameDay`, which also normalises to local date — consistent behaviour.

**Auto-fetch on `build()`**

`Future.microtask(() => fetchForMonth(...))` in `build()` triggers the first data load without blocking the initial frame. On month navigation (`setFocusedDay`), `fetchForMonth` is called again — no caching between months, but the data size is small.

---

### [SL-0037] 2026-05-17 — CalendarPage + day bottom-sheet (IP-0035, IP-0036)

**What was created**

`lib/presentation/pages/calendar_page.dart`.

**`TableCalendar` configuration**

| Option | Value | Reason |
|---|---|---|
| `locale` | `'fr_FR'` | French day/month names |
| `startingDayOfWeek` | `monday` | European week convention |
| `calendarFormat` | `month` (default), switchable | UX choice |
| `markersMaxCount` | `0` | Custom marker builder used instead |
| `calendarBuilders.markerBuilder` | `_DayMarkers` | Coloured dots per activity |

**`_DayMarkers` — coloured dots**

Meetings → `colorScheme.primary` dots; events → `colorScheme.tertiary` dots. Up to 3 dots shown; overflow written as `+N` label (8pt, `onSurfaceVariant`). `Positioned(bottom: 2)` places dots below the day number.

**Day bottom-sheet (IP-0036)**

`_showDaySheet` calls `showModalBottomSheet(useRootNavigator: false)` — architecture §9c requirement so the Android back button closes the sheet before leaving the page. `DraggableScrollableSheet(initialChildSize: 0.5)` lets users expand to 85 % for long lists.

Two sections: "Réunions passées" (tap → `MeetingDetailPage`) and "Événements à venir" (`_EventRow` with linked-meeting check mark). The sheet also has a shortcut "Planifier une réunion" button.

**`_DayPreview`** — inline list below the calendar for the selected day. Same data as the sheet but always visible, reducing the need to tap to see today's summary.

---

### [SL-0038] 2026-05-17 — ScheduleEventPage (IP-0037)

**What was created**

`lib/presentation/pages/schedule_event_page.dart`.

**Form fields**

| Field | Widget | Validation |
|---|---|---|
| Title | `TextFormField` | required |
| Folder | `DropdownButtonFormField<int>` | falls back to Inbox (id=1) |
| Start | `_DateTimeButton` → date+time pickers | first date: yesterday |
| End | `_DateTimeButton` → date+time pickers | must be after start |
| Reminder | `DropdownButtonFormField<int>` | 0/5/10/15/30/60 min |

**Past-event warning** — if `_startsAt.isBefore(DateTime.now())`, a `SnackBar` warns the user (not a blocking error — some users schedule retroactively to document past meetings).

**Save flow**

1. Validate form.
2. Generate `notificationId = DateTime.now().microsecondsSinceEpoch % 0x7FFFFFFF` — fits in a 32-bit signed int, unique enough for personal use.
3. `CalendarRepository.scheduleEvent(...)` → returns `eventId`.
4. If `fireAt.isAfter(now)`: `requestExactAlarmPermission()` → `NotificationService.schedule(...)`.
5. `calendarControllerProvider.notifier.fetchForMonth(...)` to refresh the calendar.
6. `context.pop()`.

**`_roundUp(dt, minutes)`** — rounds a `DateTime` up to the next `minutes` boundary so the default start time is always a clean 30-min slot.

**`PopScope`** mirrors `NewFolderPage` — `_isDirty` checks if the title field has been touched, shows the discard sheet on back.

---

### [SL-0039] 2026-05-17 — Meeting-event link (IP-0039)

**What was changed**

`MeetingRepository`:
- Constructor gains optional `CalendarRepository? calendarRepository`.
- `processRecording()` gains optional `int? linkedEventId`.
- After a successful pipeline run (`result.isOk && linkedEventId != null && _calRepo != null`), calls `_calRepo!.linkMeeting(linkedEventId, meetingId)` — this writes `linkedMeetingId` into the `CalendarEvents` row.
- `meetingRepositoryProvider` now injects `calendarRepositoryProvider`.

`main.dart` — `async main()` with `WidgetsFlutterBinding.ensureInitialized()` before `NotificationService.instance.init()`.

`app.dart` — `NotificationService.instance.bindOnTap(router.go)` added to `build()`.

**Why nullable `CalendarRepository`**

`MeetingRepository` is instantiated before Part 7 was written; making the dependency optional kept the provider compilable across all prior Parts. Now that `CalendarRepository` exists, it is always injected via the provider — the nullable field is purely a compile-time safety net for tests that create `MeetingRepository` without a calendar repo.

**The link flow end-to-end**

```
RecordPage(folderId, eventId)
  → user records → stopAndProcess → context.go('/processing/$draftId')
  → ProcessingPage calls MeetingRepository.processRecording(linkedEventId: eventId)
  → pipeline succeeds
  → _calRepo!.linkMeeting(eventId, meetingId)
  → CalendarEvents row: linkedMeetingId = meetingId
  → CalendarPage._EventRow shows check-mark ✓
```

**No new env vars in Part 7** — `timezone` package added to pubspec, no API keys.

---

### [SL-0044] 2026-05-17 — animation_utils.dart (IP-0044)

**What was created**

`lib/core/utils/animation_utils.dart` — two small helpers:

```dart
bool animationsEnabled(BuildContext context) =>
    !MediaQuery.disableAnimationsOf(context);

Duration animDuration(BuildContext context, Duration d) =>
    animationsEnabled(context) ? d : Duration.zero;
```

**Why this matters**

iOS "Reduce Motion" and Android "Remove animations" are OS-level accessibility settings. `MediaQuery.disableAnimationsOf` reflects them. Every custom animation in the app calls `animationsEnabled` before starting a loop or applying an `Animate` chain — if the setting is on, all motion is skipped entirely. This respects WCAG 2.3.3 (animation from interactions) without requiring per-widget boolean flags.

`animDuration` is a convenience wrapper for imperative APIs (`AnimatedSwitcher.duration`, `AnimationController.duration`) that take a `Duration` directly — returning `Duration.zero` collapses animations to instant state changes.

---

### [SL-0040] 2026-05-17 — FolderCard floating bob animation (IP-0040)

**What was changed**

`lib/presentation/widgets/folder_card.dart`:
- Added `gridIndex` parameter (default `0`).
- `build()` constructs the `Hero` card as `final card = Hero(...)`, then conditionally returns:
  - `card` when `animationsEnabled(context)` is false (Reduce Motion).
  - `card.animate(onPlay: (ctrl) => ctrl.repeat(reverse: true), delay: Duration(milliseconds: gridIndex * 220)).moveY(begin: 0, end: -5, duration: 2200ms, curve: Curves.easeInOut)` otherwise.

`lib/presentation/pages/folders_page.dart`:
- `GridView.builder` now passes `gridIndex: i` to each `FolderCard` so each card has a different stagger offset (0 ms, 220 ms, 440 ms …).

**Why repeat(reverse: true)**

The `reverse: true` flag makes the animation play forward then backward continuously, producing a smooth sine-like bob without a hard jump at the loop boundary. The −5 px vertical travel is subtle enough to be decorative without causing layout jitter.

**Why 220 ms offset per card**

With 2 columns and a 220 ms offset, adjacent cards peak at different times, giving the grid a gentle wave feel. The offset is small enough that the phase difference is visually clear even with 2 cards, and large enough that it doesn't feel random.

---

### [SL-0041] 2026-05-17 — Staggered summary section fade-in (IP-0041)

**What was changed**

`lib/presentation/pages/meeting_detail_page.dart` — `_SummaryTab` rebuilt:

**Before:** Single `Markdown` widget rendering the entire summary string.

**After:**
1. `SummarySection.parse(summary)` splits the Markdown on `## ` headings.
2. If no sections found (flat markdown with no headings), falls back to the original `Markdown` widget.
3. If sections exist, renders a `ListView.builder` of `Card` widgets, one per section. Each card contains the heading as a `titleSmall` text in `colorScheme.primary` and the body as `MarkdownBody(selectable: true)`.
4. Each card is animated: `.animate(delay: i*60ms).fadeIn(280ms).slideY(begin:0.08, curve:Curves.easeOut)`.

**Why Card-per-section rather than one big Markdown**

The LLM summary always produces 5 fixed sections (Participants, Décisions, Action items, Risques, Résumé global). Rendering each as a card makes the structure scannable at a glance — users can find "Action items" without scrolling through a wall of text. The stagger makes each section feel like it arrives in sequence, reinforcing the hierarchical reading order.

**Animate guard**

`animationsEnabled(context)` is checked before applying any `.animate()` chain. When Reduce Motion is on, the cards appear instantly.

---

### [SL-0042] 2026-05-17 — CalendarPage FAB rotate entry (IP-0042)

**What was changed**

`lib/presentation/pages/calendar_page.dart`:
- `FloatingActionButton.extended` icon switched to a conditional:
  - When `animationsEnabled(context)`: `Icon(Icons.add_rounded).animate().rotate(begin:-0.25, end:0, 350ms, easeOut)`.
  - Otherwise: plain `Icon(Icons.add_rounded)`.

**AudioPlayerBar** (`lib/presentation/widgets/audio_player_bar.dart`) already implements `AnimatedSwitcher` for the play/pause button (IP-0027) — no further change needed.

**Why −0.25 turns (−90°) start**

The + icon arriving from a counter-clockwise quarter turn gives a sense of "unfolding" that matches Material 3 FAB expand semantics. At 350 ms with `easeOut`, it lands gently without overshooting.

**flutter_animate entry animations and rebuilds**

`flutter_animate`'s `Animate` widget runs its animation once on first appearance (controlled by an internal `AnimationController` that starts in `initState`). Subsequent `build()` calls from `ref.watch` do not restart the animation, so the FAB does not spin on every calendar state update.

---

### [SL-0043] 2026-05-17 — Meeting tile stagger in FolderDetailPage (IP-0043)

**What was changed**

`lib/presentation/pages/folder_detail_page.dart`:
- `ListView.builder` itemBuilder now wraps each `_MeetingTile` with:
  ```dart
  tile
    .animate(delay: Duration(milliseconds: i * 50))
    .fadeIn(duration: 250ms)
    .slideX(begin: -0.05, end: 0, duration: 250ms, curve: Curves.easeOut)
  ```
- Guarded by `final animate = animationsEnabled(context)` — when false, the raw tile is returned without any chain.

**Why slideX from left (−0.05)**

A very small left-to-right slide (5 % of widget width) suggests the list items are "arriving" — familiar from Android Material motion. At 50 ms per item, 10 meetings stagger over 500 ms total, so the last item appears before the user can scroll past it.

**Why not AnimatedList**

`AnimatedList` is for insert/remove transitions on a live-updating list. The stagger here applies to the initial mount of all tiles (e.g., when the page first opens or the folder changes). Using `flutter_animate` on `ListView.builder` is simpler and requires no controller management.

---

### [SL-0045] 2026-05-17 — Part 9: Android back-button hardening (IP-0045, IP-0046, IP-0047, IP-0058)

**What was built**

This section covers three implementation entries that together harden the Android hardware/gesture back button across the whole app.

---

**[IP-0047] Double-tap-to-exit at shell root — already complete in IP-0010**

`lib/presentation/pages/home_shell.dart` was implemented in Part 1 ([SL-0009]) and already contains the full double-tap-to-exit guard required by architecture §9c:

```dart
PopScope(
  canPop: false,
  onPopInvokedWithResult: (didPop, _) {
    if (!didPop) _onBack();
  },
  ...
)
```

`_onBack()` checks `_tabHistoryProvider` and returns to the previous tab if history is non-empty. When the user is at the root of the first tab with no history, it arms a 2-second window and shows "Appuyez encore pour quitter" via `ScaffoldMessenger`. A second back within the window calls `SystemNavigator.pop()`. Any current snackbar is cleared first (`clearSnackBars()`). IP-0047 is satisfied by existing code; this entry documents the audit.

---

**[IP-0046] Android 14 predictive back — BLOCKED**

Enabling predictive back requires adding `android:enableOnBackInvokedCallback="true"` to `<application>` in `android/app/src/main/AndroidManifest.xml`. The `android/` directory is not yet generated (blocked on Flutter SDK installation per [P-0002]). Once the owner runs `flutter create . --project-name auto_derdacha`, this one-line change must be applied to `AndroidManifest.xml`. The flag is safe to omit on Android < 14 — it is ignored there.

---

**[IP-0045 + IP-0058] PopScope audit + ProcessingPage**

All dirty-form and in-progress pages were audited:

| Page | PopScope status |
|---|---|
| `RecordPage` | ✅ `canPop: !isActive` — blocks back while recording/paused; shows "Arrêter l'enregistrement?" dialog ([SL-0017]) |
| `NewFolderPage` | ✅ dirty-form guard — "Annuler les modifications?" sheet ([SL-0033]) |
| `ScheduleEventPage` | ✅ dirty-form guard — "Annuler les modifications?" sheet ([SL-0038]) |
| `MeetingDetailPage` | ✅ pauses audio player on pop ([SL-0028]) |
| `ProcessingPage` | ✅ implemented now — see below |

`ProcessingPage` was the only screen in the back-button table (architecture §9c) not yet fully implemented. Its stub was replaced with a full implementation:

**`lib/presentation/pages/processing_page.dart`**

1. **Pipeline trigger** — `_startPipeline()` runs in a post-frame callback so `ref.read` works correctly. It reads `MeetingState.result` (the `RecordingResult` produced by `MeetingController.stopAndProcess`) to obtain `audioFile`, `durationSeconds`, and `folderId`. `folderId` (a `String?` from the router query param) is converted to `int` via `_resolveFolder()`, which falls back to the Inbox folder if the value is absent or non-numeric.

2. **Fire-and-forget** — `MeetingRepository.processRecording()` is launched with `unawaited()`. The repository inserts a DB row in `pending` state immediately, then runs the transcription → summarization pipeline, updating `pipelineState` in the DB after each step. The page does not `await` the Future directly; instead it observes pipeline progress through a Drift stream.

3. **Live stream** — A `StreamProvider.autoDispose.family<Meeting?, String>` keyed by `draftId` delegates to `MeetingRepository.watchByDraftId(draftId)`. The new repository method polls `getByDraftId` every 100 ms until the row appears (within milliseconds of `processRecording()` starting), then yields a continuous `watchById` stream. This gives the UI live `pipelineState` updates without coupling the page to the Future.

4. **Phase rows** — Three `_PhaseRow` widgets display Transcription / Résumé / Sauvegarde. Each shows one of four states (`idle`, `active`, `done`, `failed`) derived from the current `PipelineState` and whether a transcript is present (to distinguish transcription failure from summarization failure). The active row's icon shows a repeating shimmer animation via `flutter_animate`, guarded by `animationsEnabled(context)` ([IP-0044]).

5. **Navigation on success** — `ref.listen` fires when `pipelineState == done`. It calls `context.go('/folders/\${m.folderId}/meetings/\${m.id}')`, which *replaces* the route so the user cannot navigate back to `ProcessingPage`.

6. **Error & retry** — When the `processRecording()` Future resolves with `Err`, the error message is stored in `_errorMessage` and displayed via `_ErrorCard`. A "Réessayer" button calls `MeetingRepository.retryPipeline(meetingId)` using the same `CancelToken`. `CancelledFailure` is silently ignored (the user explicitly cancelled).

7. **PopScope** — `canPop: isFailed` (true only when the pipeline is in a final error state, not during active processing). While the pipeline runs, `canPop: false` prevents back navigation. `onPopInvokedWithResult` shows "Annuler le traitement?" dialog; on confirm it calls `_cancelToken.cancel()` and navigates to `/record` via `context.go`. The `dispose()` override also cancels the token in case the page is disposed by the router without explicit back navigation.

8. **CancelToken lifecycle** — `CancelToken` is created at construction time. It is cancelled in `dispose()` as a safety net. `MeetingRepository.processRecording()` and `retryPipeline()` thread the token into `TranscriptionApi` and `SummaryApi` ([IP-0019], [IP-0020]) which pass it to Dio. When cancelled, Dio throws a `DioException(type: cancel)`, which `mapDioError` converts to `CancelledFailure`. The page's `.then()` callback ignores `CancelledFailure`, so no error card appears after an intentional cancel.

**Why `watchByDraftId` polls instead of using a Drift stream directly**

The Drift `watchById(id)` stream requires the DB row's integer `id`, which is not known until `processRecording()` executes its first `INSERT`. At the time the page mounts, only the `draftId` string (a UUID) is available. A 100 ms polling loop on `getByDraftId(draftId)` runs for at most one iteration before the row appears (the INSERT completes in < 10 ms on local SQLite), then permanently delegates to the efficient `watchById` reactive stream. There is no continuous polling after the row is found.

**No new env vars in Part 8** — all UI/animation changes; no API calls added.

---

### [SL-0046] 2026-05-17 — Audio chunking + silent audio detection (IP-0048, IP-0050)

**What was built**

`lib/core/utils/audio_chunker.dart` — a pure-Dart utility that splits any audio file into byte-boundary chunks.

```dart
final chunks = await AudioChunker.chunk(audioFile); // returns [source] if ≤ 20 MB
```

The method opens the source file as a read stream (`openRead(offset, end)`) and pipes each 20 MB slice into a temp file, avoiding loading the whole file into memory. `AudioChunker.cleanup()` deletes the temp files after use. If the source fits within the 20 MB limit, it is returned as-is — no temp files are created.

**Why byte boundaries, not silence boundaries**

Silence detection requires reading decoded PCM samples, which in Dart requires FFI or a native plugin. Byte-boundary cutting produces chunks that may include partial AAC frames, but Whisper is robust to this in practice (it transcribes each chunk independently). The "silence boundary" note in the architecture is documented as a future improvement.

**Integration in MeetingRepository._runPipeline() (IP-0048)**

`_runPipeline()` now calls `AudioChunker.chunk(audioFile)` before the transcription step. When `chunks.length > 1`, it loops through each chunk, collects transcripts, joins them with `\n`, then sends the concatenated string to the summarization API. Temp chunks are deleted immediately after the transcription loop, whether it succeeded or failed.

**Silent audio detection (IP-0050)**

Added as a pre-check at the top of `_runPipeline()`, guarded by `!forceSend`:

```
heuristic: AAC-LC 16 kHz mono ≈ 4 KB/s normal; threshold: 1 KB/s
if duration > 5s AND fileSize < duration × 1000 bytes → EmptyAudioFailure
```

The threshold is very conservative (1 KB/s vs normal 4+ KB/s) to avoid false positives on quiet but audible meetings. `retryPipeline()` always passes `forceSend: true`, so pressing "Réessayer" in the UI always bypasses the silence check — this is the "Envoyer quand même" override described in the architecture.

**No schema change** — the `pipelineState = 'failed'` path already existed from [IP-0022]. No migration needed.

---

### [SL-0047] 2026-05-17 — Retry banner in MeetingDetailPage (IP-0049)

**What was built**

`lib/presentation/pages/meeting_detail_page.dart`:

1. **`_RetryBanner` widget** — a `MaterialBanner` shown when `meeting.pipelineState == PipelineState.failed`. Uses `cs.errorContainer` background. When `retrying`, shows a 18 dp `CircularProgressIndicator`. When idle, shows a "Réessayer" button that calls `_retryProcessing()`.

2. **`_retryProcessing()` method** — sets `_retrying = true`, calls `ref.read(meetingRepositoryProvider).retryPipeline(_id)`, resets `_retrying` on return.

3. **`_fileSize()` fixed** — now uses `dart:io File(path).lengthSync()` instead of a placeholder computation. Returns human-readable B / KB / MB.

**Why MaterialBanner (not SnackBar or Card)**

`MaterialBanner` persists until dismissed or the condition changes — appropriate for an error state that requires explicit user action. `SnackBar` auto-dismisses (wrong for a retryable failure). A plain `Card` would be hidden inside a tab content area; the banner appears above the tab bar so it is always visible.

**DB schema note** — IP-0049 originally planned a schema migration v2. The `pipelineState` column was already added in schema v1 ([IP-0022]), so no migration is required. The retry banner simply reads the existing column.

---

### [SL-0048] 2026-05-17 — Orphan audio cleanup (IP-0051)

**What was built**

`lib/services/audio_cleanup_service.dart` — a static utility class with a single `run(Set<String> referencedPaths)` method:

1. Resolves `<docs>/audio/` using `getApplicationDocumentsDirectory()`.
2. Lists all `File` entries in that directory.
3. Skips any file whose path is in `referencedPaths` (active meeting audio).
4. For remaining files, reads `stat().modified` and deletes those older than 24 hours.
5. Returns the count of deleted files (logged implicitly via the provider).

`lib/data/local/meeting_dao.dart` — added `getAllAudioPaths()`: a `selectOnly` query returning only the `audioPath` column from all meeting rows. This avoids loading full `MeetingData` objects for a path-set operation.

`lib/app.dart` — added `_startupCleanupProvider` (a `FutureProvider<void>`):

```dart
final _startupCleanupProvider = FutureProvider<void>((ref) async {
  await Future<void>.delayed(const Duration(seconds: 5));
  final db = ref.read(appDatabaseProvider);
  final paths = await db.meetingDao.getAllAudioPaths();
  await AudioCleanupService.run(paths.toSet());
});
```

Triggered in `App.build()` via `ref.listen(_startupCleanupProvider, (_, __) {})` — this subscribes to the provider once, which starts the background computation. The result is intentionally discarded; the cleanup is best-effort.

**Why the 5-second delay**

The cleanup starts after app startup completes (first frame renders) so it does not compete with the DB's `LazyDatabase` initialization or the notification service. A 5-second delay is conservative but ensures smooth startup on slow devices.

**Why the 24-hour age guard**

A recording that was just started generates an audio file path before the DB row is inserted (the path is known at `start()` time, before `stopAndProcess()` is called). The 24-hour guard ensures that a file created moments ago (active or very recently abandoned recording) is never deleted even if its meeting row has not yet been inserted.
