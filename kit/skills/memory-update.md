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

Memory is updated on request only. The trigger is the user asking for it. There
are no automatic writes from the main conversation.

On trigger:

1. Read the current METHOD.md and STATE.md.
2. Classify the session's context using the classification in METHOD.md.
3. Apply the updates: accumulate and refine in METHOD.md, overwrite STATE.md.
4. Stamp `Last updated` in STATE.md.
5. Report back what changed and where.

<!-- source: METHOD.md 26-38 -->

### A delegated run writes memory when it finishes; the main conversation waits for the trigger.  `[T0]` `[2026-08-12]`

The exception turns on the run being *delegated*, not on an agent definition
being *visible*. Supplying an agent definition as context to the main
conversation supplies its principles and nothing more — the main thread still
waits for the trigger. Only a genuinely spawned subagent writes on its own.

> Rationale: a delegated run holds context the main thread never sees, so
> deferring the write until the user asks would lose it.

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

### Correcting a claim your own change falsified is not optional and does not wait for a trigger.  `[T0]`  `[2026-08-12]`

A memory update that adds a new claim can wait to be asked for; the reader
loses nothing but completeness. A statement the just-landed change made false
cannot wait, because it will be believed. Delete or correct it in the same step
that falsified it. Adding to the record is a request; keeping the record true
is part of the work.

> Evidence: In an earlier project a line asserting that work was not committed
> and not deployed stood for two days after both had happened, because updates
> only ran when asked for. In this project a line asserting fourteen invariants
> survived the change that split them into thirteen plus two, and was caught
> only because the agent raised the question.

<!-- source: none; first recorded in this project -->
