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

(empty)

## Anti-Patterns

(empty)
