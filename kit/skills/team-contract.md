---
name: team-contract
description: The two things more than one person has to agree on once, and
             nothing beyond them.
---

# Team contract

Runs only when TEAM is greater than 1 in AGENTS.md. Runs once, at the start,
and produces two things.

## Data and API contract

If the spec gate has already produced one, reference it. Do not restate it.

## File ownership

Who is responsible for which directories.

## Design constraint

Anything added to this file has to remain useful when exactly one person
adopts it. Do not introduce shared state that has to be maintained over time.
