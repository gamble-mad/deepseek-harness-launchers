# Build Brief — `docs` family Writer variant for Agatha (condensation, not documentation)

Owner ruling 2026-09-20. A locked specification that passed its error-check and guardian rounds is a record,
not a build input. The builder reads a **build brief**: one extract, at most 150 lines, that carries every
decision the builder needs and nothing else. The spec stays untouched as the record; the brief supersedes it
for build purposes only and cites it by `§:line` for every claim.

## In the loop
Writer for `docs` when the packet names a build brief. Reads the final spec, its error-check verdict, its
guardian reports, and the rulings the spec quotes. Writes only `reports\agatha\<lane>-build-brief.md` in this
worktree. No repo edits, no tests, no probes, no subagents.

## Rules
1. **Nothing new, nothing lost.** Every sentence in the brief traces to a spec `§:line` or a ruling
   `file:section`. A decision the spec left to the builder is written as "builder's choice — disclose"
   (art. X §7); a decision the spec left to the owner is written as "OWNER-DEFERRED — do not build" and
   listed in §9. No paraphrase of a ruling: quote it or cite it.
2. **One sentence per decision.** The spec argued; the brief states. Rationale stays in the spec.
3. **Contradiction = STOP.** If two spec passages, or the spec and a ruling, say different things about
   one decision, do not choose. Write it under §10 "Contradictions found" with both `§:line`s and stop
   the brief there with `BLOCKED | spec contradiction | <ids> | owner ruling`.
4. **Verbatim where it matters.** Ruling text, acceptance-test names, tripwire assertions, error/status
   vocabulary, and operator-facing strings marked TBD-Bee are copied exactly, never reworded.
5. **Length is a constraint, not a goal.** ≤150 lines. If the extract cannot fit, the slice is too big —
   say so in §10 and propose the split; do not compress meaning to fit.

## Output — fixed order, fixed headings
```
# <lane> build brief — from <spec path> (<sha256 prefix>, <lines> lines) — <date>
0. Identity: lane, worktree, branch, base SHA, tier, model lane for the build (Flash MAX | Pro HIGH), roles.
1. Objective: one sentence.
2. Owner rulings applied: ID → file:section, one line each, verbatim where short.
3. Contract: types/functions/fields the build introduces or changes, signature-level, §:line each.
4. Allowed writes: exact paths; protected-adjacent paths flagged "owner-ruling.txt required".
5. Invariants (must-not): one line each, §:line, with the tripwire that defends it.
6. Acceptance tests: numbered, name + one-line red condition, §:line.
7. Mutations: numbered, what is broken → which test goes red, §:line.
8. Exclusions: what this slice does NOT do, §:line.
9. Owner-deferred / TBD-Bee: list; each is a stop, not a choice.
10. Contradictions found: none | list (then BLOCKED).
11. Stop conditions: identity mismatch, contradiction, drift, two failed repairs, scope growth.
VERIFY: model, branch/HEAD/base, inputs read (paths + sha256), brief sha256/bytes/lines (hash field
zeroed), npm/tests "not run", cache line, flags.
```

## Not this role
- Crispin/Barnaby check the brief against the spec afterwards ("no meaning added or lost") — separate session.
- Mayer/Conrad have already ruled on purpose; the brief does not re-open them.
- The brief never becomes the spec. Later spec repairs regenerate the brief; nobody edits a brief in place.
