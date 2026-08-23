# METHOD

Durable rules this project has earned. Facts that stay true across tasks
belong here; anything that expires when the current task closes belongs in
STATE.md.

## Classification (apply in order)

1. Useful again in a future task?              -> METHOD.md
2. Meaningless once this task closes?          -> STATE.md
3. A decision?                                 -> principle to METHOD,
                                                  specific choice and its
                                                  situational reason to STATE
4. Already recorded by the repo (code layout,
   git history, config files)?                 -> record nothing
5. A rejected approach with a reason?          -> METHOD -> Anti-Patterns
6. Tied to a specific library or tool version? -> GOTCHAS.md

## Update semantics

METHOD.md   accumulates. Correct a rule in place rather than appending a
            contradicting one. Deleting requires a stated reason.
STATE.md    is replaced. Drop anything no longer true. git holds history.
GOTCHAS.md  entries may be deleted freely, no reason required.

A memory update re-reads the whole file, not only the sections the current
task touched. The stale entry is never in those sections.

---

## Conventions

### Write Windows paths with forward slashes in scripts

PowerShell and .NET accept them, and a path written with \ has to survive
every layer between where it is typed and where it lands. One such layer eats a
level of escaping, which turned \bin into a backspace character inside a
committed script. Forward slashes remove the whole class of problem rather than
requiring each crossing to be got right. See GOTCHAS.md for the specific trap.

### A scan that reports nothing has to be shown it can report something

Two greps in a row called the repository clean of hardcoded paths while one sat
in scripts/e2e.ps1, because the pattern was wrong rather than the tree. A clean
result from a filter nobody has seen match is not evidence of absence. Check the
pattern against a case that must hit before believing a run that does not.

## Anti-Patterns

(empty)
