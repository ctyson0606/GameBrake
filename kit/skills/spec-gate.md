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

## MODE: sprint

Once, at the start, producing one page:

- The one flow that will be demonstrated, in a single sentence.
- What is explicitly not being built — at least three items.
- The smallest contract that lets several people work in parallel: data
  shapes, API shapes.

## Mandatory triggers

Regardless of MODE, the gate must be run for any change that touches:

- authentication
- authorisation
- payments
- secrets
- database migrations
- more than one service

Everywhere else the gate is not mandatory. Stop and ask when the scope changes.
