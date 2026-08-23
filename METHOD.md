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

### A bypass paid once is not the bypass N7 accepts

N7 says the tool can be closed and that closing it is itself the pause being
sold. That argument holds only for bypasses paid every time. The single-instance
mutex could be taken by anything in the session, after which every later start
exited without a word: set up once, silent from then on, and indistinguishable
from a tool nobody had launched. The same outcome as Task Manager at an entirely
different price.

When judging whether something falls under N7, ask what it costs the second time
and whether anything is left to notice. Recurring and visible is the bargain.
One-off and silent is not, however much it costs the first time.

### The watcher sees every process start and must keep none of it

The WMI subscription is machine-wide. Every process start arrives with its full
path, protected or not, and a start WMI declines to name is asked about
directly. None of it is written down: paths are matched once in memory and
dropped, state.json holds only ids and deadlines, and there is no log.

Worth stating because nothing enforces it. One diagnostic line written to a file
would turn this tool into a complete record of which applications are launched
and when. Instrument it while chasing something — the convention above says to
do exactly that — but take the instrumentation out again.

### Read memory and git state from disk before acting on it

The METHOD.md, STATE.md and git log supplied as opening context are a snapshot,
and the snapshot can be several commits old. It was here: HEAD was three commits
further on than it said, and STATE.md on disk was several revisions newer.
Answering from the snapshot produced a confident and false claim that STATE.md's
test counts were stale, when the file on disk already carried the right numbers.

Open the file. The cost is one command, and the failure mode is telling someone
something untrue about their own repository.

## Anti-Patterns

### Namespacing the single-instance mutex instead of verifying what holds it

Rejected. A `Local\` or `Global\` prefix, or a longer and less guessable name,
changes which namespace the object lives in and nothing else. A named object
still has no owner, and anything in the session can still take it first. The
change would have looked like a fix while leaving the bypass exactly where it
was. The name was never the question; whether a second copy is actually running
is, and that can be asked directly.
