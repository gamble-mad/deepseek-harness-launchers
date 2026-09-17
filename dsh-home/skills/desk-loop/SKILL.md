---
name: desk-loop
description: The Trade Desk build loop for this lane — a lead Writer builds, a Refactor / error-check specialist tidies, a continuity-of-purpose Guardian checks for drift, then a VERIFY block. Use for every Desk task, every time.
---

# desk-loop

Three roles, fixed order, bounded rounds. The model supplies work; it never alters the loop. Owner ruling
2026-09-15: every run above T0 names all three roles; silence from the guardian is not a pass.

## Inputs (from the dispatch packet, always after the fixed head)

- family: `build` | `fix` | `refactor` | `draft` | `docs` | `audit`
- branch, base SHA, worktree, window
- spec text, files in scope, done criteria
- tier: T0 (read-only or one-file, no tests changed) · T1 (bounded change with tests) · T2 (multi-file, schema or IPC)
- guardian override, if the packet names one (see routing)

## Lane identity — read `lanes.md` first; the model id you declare is the first line of the report

## Role routing — persona text in `personas/`, read before the role starts

| family   | Writer                    | Refactor / error-check              | Guardian (default → override)          |
|----------|---------------------------|-------------------------------------|----------------------------------------|
| build    | `writer.md` (Archibald)   | `refactor.md` + `barnaby.md` checklist | `mayer.md` → `conrad.md` on sizing/exit/capital/account paths; `bee.md` on a visible surface |
| fix      | `barnaby.md`              | `refactor.md` (structure of the fix only) | `mayer.md` → same overrides            |
| refactor | `refactor.md` (Crispin)   | `barnaby.md` checklist              | `mayer.md` → same overrides            |
| draft    | `percival.md`             | none — Percival's own five-part check | `mayer.md` → `conrad.md` / `bee.md` as above |
| docs     | `agatha.md`               | none                                | `mayer.md` (rule 5 only: no implied review) |
| audit    | `mayer.md` as Writer (findings table, no edits) | none          | `conrad.md` or `bee.md` if the audit is on their axis, else none |

Both overrides can apply at once (a renderer change on the AAR exit column = Conrad and Bee). The Writer for UI
work reads `bee.md` before the first edit regardless of who the guardian is.

## Round structure — maximum three rounds, then stop as `blocked`

### 1. Writer
- `build`: builds exactly the spec. Runs `npm run typecheck` and `npm test` (targeted, then full). Commits once.
- `fix`: root cause first, failing test first, one fix, mutation pair. Commits once.
- `refactor`: structure only, P6 sweep first, no behaviour change. Commits once.
- `draft` / `docs`: writes the named document only. No repo edits outside the named path. No tests run.
- `audit`: reads only. Findings table `path:line | what | rule | severity`. No edits.
- Output: a bounded handoff — what was done, what was found, what is uncertain.

### 2. Refactor / error-check — `build`, `fix`, `refactor` families
- Second read of the finished diff. Structure, naming, duplication, placement, comment accuracy, plus the
  Barnaby checklist (unscoped query, null coerced to number, stale-as-fresh, missing IPC leg, P6).
- Amends nothing silently — a second commit if anything changed; "no change" is a valid result.
- Re-runs typecheck ×3 and the suite.

### 3. Guardian — every family
- Read-only. Compares the result to the spec, the five rules, and the persona's own checklist. Returns:
  `{ drift: none | minor | major, findings: [ {path, line, what, rule} ], verdict: string }`
- `major` = round again from Writer with the findings prepended. `minor` = note in flags, continue.
- Third `major` = stop, status `blocked`, report exactly what kept drifting.

### 4. VERIFY block
Produce the block from the fixed head, numbers copied from output. Write the report to
`reports\<skill>\<date>_<task>.md` inside the worktree, where `<skill>` is the Writer's name: `archibald`
(build), `barnaby` (fix), `crispin` (refactor), `percival` (draft), `agatha` (docs), `mayer` (audit).

## Separate minds — how the roles actually run in this harness

The subagent runtime in this harness fails ("subagent run failed"). Do not call it. Roles run as follows and the
report says which applied — never imply a separate read that did not happen (rule 5):

- **Refactor / error-check:** the same session, after the Writer's commit, as a fresh read of `git diff
  <base>..HEAD` with `refactor.md` and `barnaby.md` open. Label it "Refactor: inline pass".
- **Guardian:** NOT played by the session that wrote the diff. The report ends with one posed guardian
  question, unanswered, and names which persona should hold the seat. Opus runs the guardian round outside the
  harness, or the owner opens a new session in this window with only the guardian persona and the diff.
- When the packet says `roles: separate sessions`, each role is a new session: Writer commits; Refactor session
  reads the diff and commits; Guardian session reads the diff and returns the verdict. Each session's report
  names its own role only.

## Drift, defined (the guardian's minimum list; each persona adds its own)

- A file touched that the packet did not name, without a flag.
- A test edited so that it passes.
- An identifier, column, API, or file that does not exist in the repo at the base SHA.
- Behaviour added under a "refactor" label. Behaviour removed under a "fix" label.
- A number rendered where the value is absent, stale rendered as fresh, a review implied that did not happen.
- Any output that gates, caps, throttles, or refuses an exit or a sizing decision.
- Position, account, or holdings context introduced where the packet did not supply it.
- Resolving an ambiguity of meaning instead of flagging it.

## What the loop never does

Push. Merge. Delete branches. Touch governance. Run `npm run dev`. Rebuild better-sqlite3. Read credentials.
Compact the session mid-task. Change this skill, the personas, or `AGENTS.md`.
