# Claude Code Game Studios -- Game Studio Agent Architecture

Indie game development managed through 49 coordinated Claude Code subagents.
Each agent owns a specific domain, enforcing separation of concerns and quality.

## Technology Stack

- **Engine**: Godot 4.7.2
- **Language**: GDScript
- **Version Control**: Git with trunk-based development
- **Build System**: SCons (engine), Godot Export Templates
- **Asset Pipeline**: Godot Import System + custom resource pipeline

> **Note**: Engine-specialist agents exist for Godot, Unity, and Unreal with
> dedicated sub-specialists. Use the set matching your engine.

## Project Structure

Code root `src/` (Godot). Tests: `tests/unit/[system]/`, `tests/integration/[system]/`.
Data `assets/data/`, design `design/`, docs `docs/`, production `production/`
(finished stories in `production/archive/`), throwaway prototypes `prototypes/`.
Full map and the Unity/Unreal code roots: `.claude/docs/directory-structure.md`
(read on demand).

## Engine Version Reference

<!-- ENGINE-REFERENCE-IMPORT: the line below is engine-specific. /setup-engine
     rewrites it to @docs/engine-reference/<engine>/VERSION.md for the chosen
     engine, so a Unity or Unreal project stops loading the Godot reference every
     session. It defaults to Godot (the template's example engine); skills that
     need the pinned version read docs/engine-reference/<engine>/VERSION.md on
     demand regardless of this import. -->
@docs/engine-reference/godot/VERSION.md


## Technical Preferences

`project.yaml` at the repo root is the primary config store — engine, specialists,
naming, platform, performance, modes. Skills resolve it via `resolve_config`
(see `.claude/docs/config-resolution.md`).

`.claude/docs/technical-preferences.md` is the **legacy fallback**, read on demand
when a key is absent from `project.yaml`. It is not imported here: before
`/setup-engine` runs it is almost entirely `[TO BE CONFIGURED]` placeholders, and
after it runs `project.yaml` holds the real values.

## Coordination Rules

Full text, model tiers and Agent Teams: `.claude/docs/coordination-rules.md`
(read on demand). In short:

- No unilateral cross-domain changes; conflicts escalate to the shared parent
  (else `creative-director` for design, `technical-director` for technical).
- Read design docs by section: Grep `^#`, then Read with offset/limit; whole-file
  reads of docs over 40 KB are refused.
- Nothing goes upstream: never file or comment on an engine, plugin or vendor
  issue or PR, even when asked; draft only (`/bug-report`), the user submits.
- Spawn independent subagents in parallel; surface a BLOCKED agent at once and
  give a partial report.

## Collaboration Protocol

**User-driven collaboration, not autonomous execution.**
Every task follows: **Question -> Options -> Decision -> Draft -> Approval**

- Agents MUST ask "May I write this to [filepath]?" before using Write/Edit tools
  (exempt: `active.md` appends, agent memory, a subagent's new file at the path
  its orchestrating skill named; see `.claude/rules/agent-memory.md`)
- Agents MUST show drafts or summaries before requesting approval
- Multi-file changes require explicit approval for the full changeset
- No commits without user instruction
- Change project files with the Write and Edit tools only, never with a script
  (Python, sed, heredoc, shell redirection): a script skips the write checks. It
  binds subagents too, so repeat it in their brief. Exceptions: the helpers in
  `.claude/scripts/` a skill names, and engine output (import, export)
- A skipped or dismissed question is not an answer: act on nothing, re-ask in
  plain text and wait
- Started outside this file's folder? Warn first: hooks, deny rules and the
  ask-first mode load only when Claude Code starts here

See `docs/COLLABORATIVE-DESIGN-PRINCIPLE.md` for full protocol and examples.

> **First session?** If the project has no engine configured and no game concept,
> run `/start` to begin the guided onboarding flow.

## Coding Standards

Full text: `.claude/docs/coding-standards.md` (read on demand). In short:

- Doc comments on public APIs; gameplay values data-driven, never hardcoded;
  dependency injection over singletons.
- ADRs by `modes.workflow`: none required at `minimal` (brief + decision log).
  No GDD at `minimal`: `design/game-brief.md` is the design record.
- Conventional Commits (`feat:`, `fix:`, `chore:`, `docs:`, `test:`,
  `refactor:`), story or task ID in the body.
- Verification-driven: tests first for gameplay systems; screenshots for UI.
- **A parse check is not a run.** Every player-observable story is launched and
  observed, with a retained screenshot in `production/qa/evidence/`
  (`.claude/docs/run-and-observe.md`); not waived at `qa.level: minimal`.
- Evidence by story type: Logic → unit test; Integration → integration test or
  playtest; Visual/Feel and UI → retained screenshot (BLOCKING); Config/Data →
  smoke check (ADVISORY). `testing.strict.*` overrides; `/smoke-check` blocks.
- Tests: deterministic, isolated, no external I/O, fixtures not magic numbers;
  naming per `.claude/rules/test-standards.md`. Never disable a failing test.
- Godot CI: `godot --headless -s -d --remote-debug tcp://127.0.0.1:0
  res://addons/gdUnit4/bin/GdUnitCmdTool.gd -a res://tests --ignoreHeadlessMode`

## Context Management

Read `.claude/docs/context-management.md` on demand — it is a reference, not
session context. Two of its conventions are load-bearing and cited by name
elsewhere in the repo, so they are restated here rather than lost:

- **`production/session-state/active.md` is the session checkpoint.** The file is
  the memory, not the conversation. Read it first after any compaction, crash, or
  `/clear`.
- **Helpers in `.claude/scripts/` emit observations, never verdicts.** A script
  that scores or judges will eventually contradict a mode or override it cannot
  see. (Cited by `artifact-check.sh` and `adr-dep-graph.sh`.)
