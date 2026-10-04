---
name: spec-gate
description: What has to be settled before implementation starts, at a depth
             set by MODE.
---

# Spec gate

Depth is set by MODE in AGENTS.md.

## MODE: project

Every new feature goes through three steps.

1. Restate the requirement as a *problem*, not as a solution.
2. Ask only blocking questions. Where an assumption is reasonable and safe,
   record it instead of asking.
3. Produce: goals, non-goals, acceptance criteria, and the data and API
   contract. Then stop and wait for human approval.

Write the spec in this shape, so that the progress page can tell the whole
project, not only the feature in hand:

    ## Milestones
    - M1: v1 — <one-line title>
    - M2: v2 — <title>
    ## Goals
    - G1 (M1): ...
    ## Acceptance criteria
    - AC1 (G1): <the criterion>
      - Means: <plain language: what this gives the user>
      - Try: <how a person sees it work for themselves>
    ## Components
    - C1: <name> (`<path>`) — <responsibility>; uses C2, C3

Milestones are listed in the order they will be built. A planned milestone is
one line with no goals; the gate adds its goals and criteria when work on it
starts. A goal names its milestone, a criterion the goals it serves, and Try may
be repeated: together the Try lines are the project's usage guide. Whether a
milestone is planned, in progress or done is worked out from the evidence and
never written. A component is one line: its path (a file or directory, relative
to the project root) and, optionally, the components it uses.
A goal with no milestone, a criterion with no goal, Means or Try, and a path that
is not on disk are listed as gaps.

## MODE: sprint

Once, at the start, producing one page:

- The one flow that will be demonstrated, in a single sentence.
- What is explicitly not being built — at least three items.
- The smallest contract that lets several people work in parallel: data
  shapes, API shapes.

## Where it goes

What a person approves is written into SPEC.md, under the section it belongs
to, and nowhere else. SPEC.md accumulates: a later run adds its milestone's goals
and criteria beside the finished ones, which stay as the project's contract, and
rewrites in place only what its feature changes about existing behaviour, never
appending a second spec for the same thing. STATE.md only points at the part
being built now: it is replaced as work moves, and a contract kept there either
goes with it or keeps the file from ever being cleared.

## Mandatory triggers

Regardless of MODE, the gate must be run for any change that touches:

- authentication
- authorisation
- payments
- secrets
- database migrations
- more than one service

Everywhere else the gate is not mandatory. Stop and ask when the scope changes.
