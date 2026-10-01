---
name: memory-update
description: When memory is written, by whom, and what an update has to re-read
             before it writes.
---

# Memory update

Classification and update semantics live in METHOD.md. Read them there. They
are deliberately not restated here: the rule belongs where the decision is
made, and a second copy would drift.

This file states the trigger, the procedure, and the rules that govern them.
The procedure carries no label because it is an instruction rather than a claim
about the world. The rules that follow carry one, in the grammar defined in
kit/skills/verification.md.

## Trigger and procedure

Memory is written as you go. Write the moment state changes — a step is
finished, a decision is made, something is found, the next step moves, a trap
is hit — and never save it for the end of the session. A session can stop at
any point without warning: a quota runs out, a tool fails, the user closes it
or switches to another agent. Whatever was learned and not yet written is lost,
and the next session starts from what is on disk.

Being asked is still a trigger. When the user asks, bring every memory file up
to date at once.

This section decides when to write, not what. The classification in METHOD.md
decides what, and much of what changes in a session is already recorded by the
repository and belongs in no memory file. SPEC.md is not memory and is never
written as you go: it changes only through the spec gate, with a person's
approval.

On each write:

1. Read the current METHOD.md, STATE.md and GOTCHAS.md from disk. The copies
   loaded at the start of the session are stale after the first write.
2. Classify what changed, using the classification in METHOD.md.
3. Apply the updates: accumulate and refine in METHOD.md, overwrite STATE.md,
   add or delete in GOTCHAS.md.
4. Stamp `Last updated` in STATE.md.
5. Say in one line what changed and where.

<!-- source: METHOD.md 26-38 -->

### A delegated run writes memory before it returns.  `[T0]` `[2026-08-12]`

A spawned subagent's context is discarded when it returns, and the main thread
never sees most of it. What it learned has to be on disk before it hands back,
not reported for the main thread to write later.

> Rationale: a delegated run holds context the main thread never sees, so
> leaving the write to the main thread would lose it.

<!-- source: METHOD.md 40-50 -->

### A memory update re-reads the whole file, not only the sections the current task touched.  `[T1]` `[2026-08-12]`

The stale entry is never in the sections the current task touched, which is
exactly why re-reading only those sections leaves it standing.

> Evidence: A claim about the repository's own publication state was written
> into STATE.md, committed alongside the work it described, and was false a
> second later. Two subsequent memory updates edited the sections covering the
> new work and left the stale line untouched, so the file spent two days
> telling its reader to do something that had already been done.

<!-- source: METHOD.md 573-584 -->

### Correcting a claim your own change falsified happens in the same step as the change.  `[T0]`  `[2026-08-12]`

Writing as you go records a new claim once there is something to record. A
statement the just-landed change made false is held to more than that: correct
or delete it in the same step that falsified it, before moving on, because
until then it will be believed. Keeping the record true is part of the work,
not a separate write.

> Evidence: In an earlier project a line asserting that work was not committed
> and not deployed stood for two days after both had happened, because updates
> only ran when asked for. In this project a line asserting fourteen invariants
> survived the change that split them into thirteen plus two, and was caught
> only because the agent raised the question.

<!-- source: none; first recorded in this project -->

### What the session opened with is a snapshot; read the current value when you act on it.  `[T0]`  `[2026-10-01]`

The memory files, the git state and the time a session starts with describe
the moment it started. Commits land, other sessions write, this session writes,
and the clock moves; the copy in context does not. Before stating anything
about the memory files or the repository, or acting on it, open the file or run
the command. Every date or time written into a file comes from the clock at the
moment of writing. The cost is one read. The failure is telling someone
something false about their own repository with the confidence of something
just looked at.

> Evidence: Two projects. In one, the METHOD.md, STATE.md and git log supplied
> as opening context were behind: HEAD was three commits further on, STATE.md
> on disk several revisions newer, and an answer given from the snapshot
> claimed the state file's test counts were stale when the file already
> carried the right numbers. In the other, a handoff file was stamped 23:40
> when it was written at 23:05, because the time had not been read at the
> moment of writing.

<!-- source: two consuming projects; recorded 2026-10-01 -->
