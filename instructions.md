# Instructions — Operating Rulebook for Derdacha-Builder

These rules are **binding**. The agent (see `personas.md`) must obey them every turn. They govern *how* implementation proceeds, *where* it is logged, and *what is forbidden*.

> **⚠ Attention.** Most failures on this project come from skipping the logging discipline or mutating files that must stay append-only. Re-read §2 and §3 before every action.

---

## 1. Source-of-truth files

| File | Purpose | Mutation rule |
| --- | --- | --- |
| `architecture.md` | Approved design contract | Read-only for the agent. Owner edits only. |
| `personas.md` | Agent identity | Read-only for the agent. |
| `instructions.md` (this file) | Operating rules | Read-only for the agent. |
| `UML.md` | Diagram contract | **Append-only with versioned blocks.** Never edit existing `@startuml … @enduml` blocks. |
| `implementation_plan.md` | Plan of record | **Append-only.** New entries go at the bottom under a new heading. |
| `progress.md` | Activity log | **Append-only.** One line per action. Newest entries at the bottom. |
| `student_lab.md` | Pedagogical implementation log | **Append-only.** New sections appended, never rewritten. |
| `README.md` | How to run the project | **Append-only for instructions changes.** Sections may grow but never lose information. |
| `.env` | Local secrets | **Never committed.** Mirror new keys to `.env.example` with a sourcing comment. |
| `.env.example` | Public secrets template | Append new keys with a one-line comment explaining how to obtain each. |

Anything not in this table is normal code — edit freely as the work requires.

---

## 2. The append-only governance discipline

### 2.1 Definition of append-only
- **Allowed:** add a new line, a new section, a new code block at the **end** of the file.
- **Forbidden:** delete an existing line, reorder existing lines, rewrite an existing line, edit existing wording.
- **Corrections:** if a previous line is wrong, append a *new* line that says so. Example:

  ```
  - [P-0042] 2026-05-17T14:12+01 — Implemented dark theme toggle.
  - [P-0043] 2026-05-17T14:35+01 — Correction of [P-0042]: toggle bound to wrong provider, fixed in commit abc1234.
  ```

### 2.2 UML versioning rule
- The first set of diagrams in `UML.md` is **v1** (already present).
- Any change to a diagram → **append a new full `@startuml … @enduml` block** with the same name suffixed `_vN+1`, e.g. `AutoDerdacha_Class_v2`.
- Above the new block, append a heading: `### Class diagram — v2 (YYYY-MM-DDThh:mm — reason)`.
- **Never delete or edit v1.** The historical evolution must stay visible.
- Always link the new diagram version to a `progress.md` entry and an `implementation_plan.md` change-request entry sharing the same label ID.

### 2.3 Label IDs
Every appended entry across `progress.md`, `implementation_plan.md`, `student_lab.md`, and `UML.md` carries a **label ID** of the form `[X-NNNN]` where:

| Prefix | Domain |
| --- | --- |
| `P-` | progress entry |
| `IP-` | implementation_plan entry |
| `SL-` | student_lab section |
| `UML-` | UML diagram version bump |

`NNNN` is a 4-digit zero-padded counter, monotonically increasing **per prefix**, never reused. To find the next ID, scan the file for the highest existing `[X-NNNN]` and add 1.

Cross-link related entries by quoting each other's IDs in the body (e.g. `relates to [IP-0007], emits [UML-0003]`).

---

## 3. The work loop

Every unit of work follows this exact sequence:

1. **Announce.** Append one line to `progress.md`:
   ```
   - [P-NNNN] YYYY-MM-DDThh:mm±zz — start: <short description of what is about to be done>
   ```
2. **Plan (if non-trivial).** If the work changes the design or adds a feature, append a section to `implementation_plan.md` under a new heading:
   ```
   ## [IP-NNNN] YYYY-MM-DD — <title>
   Context: …
   Steps: …
   Risk: …
   Linked: [P-NNNN]
   ```
3. **Act.** Make the code change. Keep it small (≤ ~150 LoC of meaningful change, app still compiles).
4. **Update student_lab.** Append a new section to `student_lab.md` explaining, in pedagogical prose, *what was added, why, and how it fits into the architecture*. Include the relevant snippets and reference architecture sections.
   ```
   ### [SL-NNNN] YYYY-MM-DD — <title>
   ```
5. **Update UML if structure changed.** Append a new versioned PlantUML block in `UML.md` per §2.2 with `[UML-NNNN]` in the heading.
6. **Update README if run/setup changed.** Append (never rewrite) to `README.md`.
7. **Mirror secrets.** If a new env var was introduced, append it to `.env.example` with a comment, and remind the owner to add the real value to `.env`.
8. **Close.** Append one line to `progress.md`:
   ```
   - [P-NNNN+1] YYYY-MM-DDThh:mm±zz — done: <what was achieved>; files: <list>; linked: [IP-…], [SL-…], [UML-…]
   ```

> Steps 1 and 8 are **mandatory** for every action, no matter how small. If steps 2, 4, 5, 6, 7 do not apply, say so in the closing line (e.g. `no UML change`).

---

## 4. Progress entry format

One line per entry. Use:

```
- [P-NNNN] YYYY-MM-DDThh:mm±zz — <verb>: <single-line description with details>
```

Rules:
- ISO-8601 timestamp with timezone offset. Local time is fine.
- `<verb>`: `start`, `done`, `note`, `block`, `unblock`, `fix`, `revert-note` (never *revert* the line itself — see §2.1).
- Description: ≤ 200 chars. Include file paths, the commit hash if any, and the linked IDs.
- Newest entries at the **bottom** of the file.

Example block:
```
- [P-0001] 2026-05-17T10:00+01 — start: scaffold Flutter project per architecture.md §2
- [P-0002] 2026-05-17T10:42+01 — done: created lib/ tree; pubspec deps added (record, dio, riverpod); commit a1b2c3d; linked [SL-0001]
```

---

## 5. `.env` and secrets

- **Never** put real keys in any tracked file.
- The agent maintains two files:
  - `.env` — local only, `.gitignore`'d.
  - `.env.example` — committed template, one var per line, each preceded by a comment explaining **where to obtain the value**.
- Template example:
  ```env
  # Groq API key — create at https://console.groq.com/keys (free tier).
  GROQ_API_KEY=

  # Base URL for Groq's OpenAI-compatible endpoint. Keep default unless mirroring.
  GROQ_BASE_URL=https://api.groq.com/openai/v1

  # Whisper model identifier. See https://console.groq.com/docs/models for current options.
  GROQ_STT_MODEL=whisper-large-v3

  # LLM used for summarization.
  GROQ_LLM_MODEL=llama-3.3-70b-versatile
  ```
- The Flutter app loads `.env` via `--dart-define-from-file=.env` at build/run time, surfaced in `lib/core/config/env.dart` (see `architecture.md` §8).
- When the agent adds a new variable to the code, it **must** append it to `.env.example` in the same commit and post a `progress.md` line reminding the owner to fill the real `.env`.

---

## 6. Safety rails — STOP and ask the owner before

- Dropping or migrating the local DB schema in a way that loses data.
- Force-pushing, rebasing public history, or rewriting any tracked file's history.
- Bumping Flutter SDK major or any package major version.
- Adding a new external service or paid endpoint.
- Deleting or renaming more than 5 files in one step.
- Introducing platform-specific code (iOS/macOS/Web) not described in `architecture.md`.
- Anything that would silently make a governed file non-append-only.

When in doubt: stop, append a `[P-NNNN] note:` line describing the dilemma, and wait for owner input.

---

## 7. Coding conventions

- Follow `architecture.md` §2 layering strictly. `domain/` stays pure Dart.
- State via Riverpod. Routing via `go_router`. HTTP via Dio.
- Theme via `core/theme/app_theme.dart`; no hard-coded colors outside that file.
- Animations centralized through `flutter_animate`; respect `MediaQuery.disableAnimations` (architecture §9b).
- Android back button handled with `PopScope` on every dirty / in-progress screen (architecture §9c).
- No comments unless the *why* is non-obvious. No emojis in code or governance files.
- One concern per file; one feature per commit.

---

## 8. Commits & branches

- One conventional commit per work unit: `feat:`, `fix:`, `chore:`, `docs:`, `refactor:`, `test:`.
- Commit message body cites the label IDs touched: `Refs: [P-0042], [IP-0007], [SL-0011]`.
- Never `--amend` a pushed commit. Never use `--no-verify`.
- Branch naming: `feat/<slug>`, `fix/<slug>`. Merge into `main` only after the work loop is complete and governance files are updated.

---

## 9. Daily startup checklist

Before doing any work in a session:

1. Read the **last 20 lines** of `progress.md` to see where things stand.
2. Read the **latest version** of each diagram in `UML.md` (highest `_vN`).
3. Read the **last appended section** of `implementation_plan.md`.
4. Compute the next available label ID per prefix (§2.3).
5. Confirm `.env` exists locally and matches `.env.example` keys.
6. Then — and only then — start the §3 work loop.

---

## 10. ⚠ Attention reminders

- **Append. Never rewrite.** Governed files keep history.
- **Log first, code second.** Open a `[P-…] start:` line *before* touching code.
- **One commit = one closed `[P-…] done:` line.**
- **Diagram changed? New version. Old one stays.**
- **New env var? Mirror to `.env.example` with sourcing comment.**
- **Unsure or risky? Ask the owner. Do not improvise.**
