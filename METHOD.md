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

### A check that cannot fail for the defect in question is not evidence

Two greps in a row called the repository clean of hardcoded paths while one sat
in scripts/e2e.ps1, because the pattern was wrong rather than the tree. Later a
test asserted a serialised file by listing keys that had to be present, which
can only notice a key that went missing and never one that turned up uninvited,
so a property that serialised out and could not be read back sat in a
hand-edited config for a day looking exactly like the setting it was not. Both
passed. Neither could have failed.

Before believing a green result, ask what defect it would have caught, and show
it catching one. A pattern gets tried against a case that must hit; an assertion
gets written so the shape is exact rather than merely included.

### Check the obstacle is real before designing around it

Valorant went unbraked, and the obvious reading was that a kernel anti-cheat had
put it out of reach. The change on the table was to loosen full-path matching to
a file name, a permanent widening of what the tool can hit wrong. Measuring first
showed PROCESS_TERMINATE was granted for both game binaries, so the only real
obstacle was that WMI would not report a path, and a lower-privilege call
returned it intact. The assumption survived untouched.

A workaround bought before the obstacle is measured is paid for forever. Measure
the thing said to be impossible; it is often a different, smaller thing.

### When something appears to do nothing, watch it rather than reason about it

Three separate reports of the tool doing nothing had three unrelated causes: an
application added while it was already running, a launcher resident since login
and exempt by design, and a game whose path WMI refused to give. Every one was
found by instrumenting what the product actually observed and reading it back.
None would have been reached by reasoning, and the second and third both had a
plausible wrong explanation ready to hand.

Make the thing say what it saw. A log of observations settles in one run what
argument does not settle at all.

## Anti-Patterns

(empty)
