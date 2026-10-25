---
name: bootstrap
description: The one-time opening pass, run while SPEC.md is still an empty
             shell — where the code lives, MODE and TEAM, the Environment facts,
             and the first spec.
---

# Bootstrap

Runs once, while SPEC.md is still an empty shell: its headings and nothing
under them. Memory written during the first conversation does not end it.
STATE.md and GOTCHAS.md fill as you go from the first message, so a test on
them would be false before the opening pass ever ran.

## Before step 1: where the code lives

Every step below writes into a git repository, so settle which one first.

- **This folder is a git repository** (`git rev-parse --is-inside-work-tree`
  prints `true`): go on to step 1.
- **It is not, and the project starts here**: say so and run `git init` once
  the user agrees, then go on.
- **It is not, and the code lives in a repository elsewhere** (a teammate's,
  a remote one): stop and ask. The framework belongs inside that repository,
  next to its code, so it is cloned and the framework copied into it, not the
  other way round. Do not write the spec into a folder the code will never
  reach.
- **The repository already has an AGENTS.md that is not this framework's**:
  stop and ask. Whose rules govern, and how the two files combine, is the
  user's decision and possibly their team's; do not merge or overwrite it.

## Steps

1. Put the scripts into the index carrying the executable bit:

       git add -A
       git add --chmod=+x -- 'scripts/*.sh' 'kit/scripts/*.sh'

   The mode in the working tree is not the mode anyone else receives. On a
   platform that does not carry the bit, a script committed at 100644 looks
   correct here and is unrunnable on every machine that clones it, with no
   symptom on the one that produced it. scripts/check.sh reads the index
   rather than the tree, so it is what confirms this landed.
2. Ask for MODE and TEAM. Write them into AGENTS.md.
3. Ask for or infer the Environment facts and fill them in one by one,
   following the comment beneath that block in AGENTS.md.
4. Run the spec gate at the depth MODE selects.
5. Write what the spec gate produced into SPEC.md, and point Current Focus in
   STATE.md at the part being built first.
6. Leave METHOD.md empty.

Step 6 is a hard rule. METHOD.md grows from the traps this project actually
hits, not from guesses made before it has hit any. Do not put anything in it
because it looks empty.

<!-- source: none; the entry condition and the step before 1 come from a
     project whose first conversation wrote STATE.md before bootstrap was
     reached, in a folder that was not a repository while the team's code
     lived in another one; recorded 2026-10-25 -->
