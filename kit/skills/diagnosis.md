---
name: diagnosis
description: Chasing a failure to its cause — reproduction, rates, confounds,
             and what a measurement means before it is attributed to anything.
---

# Diagnosis

Rules for investigating a failure that has already appeared. Whether a result
constitutes evidence at all is kit/skills/verification.md, which also defines
the tier tag and label grammars used here.

Rules are ordered as they appear in the source they were extracted from.

### Widening a window proves nothing if the observer is blocked until it closes.  `[T1]` `[2026-08-12]`

Before widening a window to reproduce a race, ask who is awake while it is
open. If every watcher is waiting on the operation that holds the window open,
none of them can look inside it. Reproducing it needs a third party that
observes from outside the operation under test.

> Evidence: A delay inserted between two writes inside one request left the
> failure rate roughly where it was instead of making it certain. The delay was
> real and the reasoning was right; every watcher was awaiting the very request
> holding the window open. Firing the write without awaiting it, sleeping into
> the middle and reading from a separate caller made it fail every time, and
> never once the fix was in.

<!-- source: METHOD.md 102-111 -->

### When a probe fails, capture enough state to tell the candidate explanations apart.  `[T1]` `[2026-08-12]`

A failure message carrying only the value that was asserted on is usually
consistent with every hypothesis you hold. Print the neighbouring state at the
moment of failure, chosen so that the live explanations disagree about it.

> Evidence: A probe had two live explanations — two stores disagreeing, or a
> stale response overwriting a newer one — and its message carried only the
> number it asserted on, which fits both. Printing the readout *and* the
> underlying list at the moment of failure separated them in a single run.

<!-- source: METHOD.md 113-118 -->

### Check that the harness is not the thing that failed before reading anything into a control.  `[T0]` `[2026-08-12]`

A run can die on the project's own defences — rate limits, quotas, guards —
rather than on the behaviour under test. That looks exactly like a sabotage
working. Establish where the run actually stopped before concluding anything
from it.

> Evidence: Three control runs aborted at resource creation instead of reaching
> the assertion, because repeated probing had exhausted a rate limit.

<!-- source: METHOD.md 120-125 -->

### An intermittent failure has a rate, and one run does not measure it.  `[T2]` `[2026-08-12]`

Anything that does not fail every time needs a count before and after the
change — several runs each side. The comparison is between rates, not between
outcomes.

> Evidence: A probe that failed, then passed once a candidate fix was in, was
> very nearly written down as fixed. A handful more runs put it back at roughly
> one failure in two, with the "fix" still in place and irrelevant.

<!-- source: METHOD.md 154-159 -->

### A flake that surfaces next to your change is not evidence your change made it.  `[T2]` `[2026-08-12]`

Stash the edit and measure the untouched tree at the same sample size. Without
that measurement the honest options are to blame your own change or to say
nothing, and both are wrong.

> Evidence: An unrelated assertion started failing about twice in five runs
> during an edit, which is exactly the shape of something newly broken.
> Stashing the edit and running the untouched tree four times put it at one in
> four — the same rate inside the noise these sample sizes carry — so it was
> pre-existing and merely never measured. The two ratios look different and at
> that sample size cannot be told apart; that is the whole point.

<!-- source: METHOD.md 161-167 -->

### An added probe is part of the experiment.  `[T0]` `[2026-08-12]`

Compare only runs whose instrumentation is identical. Be suspicious of a bug
that survives exactly as long as nobody is looking at it.

> Evidence: A failure disappeared whenever the instrumentation for diagnosing
> it was present, because each extra round trip into the page changed the
> timing.

<!-- source: METHOD.md 169-173 -->

### The toolchain's own version is a variable, and it is invisible in the diff.  `[T1]` `[2026-08-12]`

A cross-machine comparison is not clean until the tool versions on both
machines are compared too. Either match them, or name the confound beside the
number rather than reporting the rate as though the machine were the only
difference.

> Evidence: An unmodified script failed every run on a second machine where the
> first had been failing about half the time — except that the second machine
> had just picked up a newer build of the tool the harness drives. Two
> variables changed at once and only one of them was visible in the working
> tree.

<!-- source: METHOD.md 175-183 -->

### An observation window has to outlast the event it is meant to observe.  `[T1]` `[2026-08-12]`

That is a property of the platform rather than of the plan. Before writing "go
and look" into a task, establish that the record will still exist when you get
there. If it will not, there are three ways out: be present inside the window,
trigger the event yourself, or make the event leave a durable trace.

> Evidence: A step written as "check the dashboard and confirm the scheduled
> job authenticated" was not executable: the console reported no outcome for
> past runs, and log retention was far shorter than the interval between runs.
> The evidence expires long before anyone can arrive, so the check returns an
> empty list that means nothing at all — and reads like success. Triggering the
> event yourself is usually cheapest, and it costs one named gap: a manual
> invocation exercises the same handler and the same credential but not the
> scheduler, so state which of the two you proved.

<!-- source: METHOD.md 185-199 -->

### A failure that stops after a change is not a failure the change fixed.  `[T1]` `[2026-08-12]`

Put the suspected cause back and confirm the failure returns. Sabotaging the
*code* proves a test has power; sabotaging your own *fix* proves the diagnosis
does. Skipping the step costs more than the time it saves, because what gets
written down is a diagnosis rather than a coincidence and the next reader
cannot tell which they are holding.

> Evidence: A subscription delivered nothing, a plausible race was found in a
> library's source, the fix went in, the run went green, and the cause was
> written into two files as established fact. Reverting the fix later produced
> three green runs in a row: the race was real and had nothing to do with the
> failure, which remains unexplained.

<!-- source: METHOD.md 201-213 -->

### Measure the transport floor before attributing any latency to the system under test.  `[T1]` `[2026-08-12]`

Deploying does not remove the problem, because the measuring machine is still
not production. Take one request that does no work, and whatever the platform
will say about where the request arrived. A measurement whose floor is unknown
is not a slow result; it is an unread instrument.

> Evidence: A live-update figure read like the application until the floor was
> taken: a request that does nothing cost seconds, and a platform header
> reported every request entering the provider's network a continent away from
> both the application and its database.

<!-- source: METHOD.md 240-248 -->

### Measure that floor the way the system under test uses the network.  `[T1]` `[2026-08-12]`

A single cold request pays DNS, connection setup and a TLS handshake; an
application holding a warm connection never pays the handshake twice. Send
several requests over one connection and take the later ones. A floor measured
cold does not overstate latency a little — it overstates it by however long a
handshake takes.

> Evidence: The first attempt here reported a floor several times higher than
> the warm one, and the giveaway was an observed live update arriving *faster
> than the floor* — impossible, and therefore proof that the floor was
> measuring something the application does not do.

<!-- source: METHOD.md 250-260 -->

### There is not one floor — there is one per tier the request reaches.  `[T1]` `[2026-08-12]`

Take the floor whose request travels as far as the thing being measured. A
floor taken at the nearest tier makes everything behind that tier look like
the application's own cost.

> Evidence: From one machine over one warm connection, a cached static asset
> returned several times faster than a dynamic response that runs a function in
> another continent. Both are honest floors; they answer different questions.

<!-- source: METHOD.md 267-273 -->

### "The handler never ran" has a boring explanation before it has an interesting one.  `[T0]` `[2026-08-12]`

The element under the pointer may belong to a different render branch of the
same component. Establish which variant is mounted before suspecting the
framework or the input layer.

> Evidence: Recorded as a corollary of the investigation behind "Wait for
> something only the loaded state can produce" in kit/skills/verification.md,
> and named as one of the two things that cost it time.

<!-- source: METHOD.md 306-309 -->

### A rate that differs between two machines may be caused by neither of them.  `[T1]` `[2026-08-12]`

A shared dependency both machines reach can decide the outcome on its own.
This is why a confound gets named beside the number rather than concluded
from.

> Evidence: The difference between two machines' failure rates turned out to be
> the round trip to a shared database, which decided whether a fetch had landed
> before the probe interacted with the page. The tool-version difference the
> two machines also had — the confound named earlier in the same
> investigation — turned out to be irrelevant.

<!-- source: METHOD.md 309-315 -->

### Fix the timing, do not retry the probe.  `[T1]` `[2026-08-12]`

An intermittent assertion is worse than a failing one, because it gets re-run
until it passes and then believed.

> Evidence: A page whose header and list fill in asynchronously shifts
> everything below them; a probe that measured an element's position and
> touched those coordinates a moment later passed twice and failed once, with
> the feature working perfectly throughout.

<!-- source: METHOD.md 317-322 -->
