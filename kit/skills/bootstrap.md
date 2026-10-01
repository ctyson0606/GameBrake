---
name: bootstrap
description: The one-time opening pass, run only while METHOD.md and STATE.md
             are both still empty shells.
---

# Bootstrap

Runs only when METHOD.md and STATE.md are both still empty shells. Runs once.

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
