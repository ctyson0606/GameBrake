---
name: verification
description: Judging whether a test, probe, or suite actually constitutes
             evidence. Read before trusting any green run.
---

# Verification

Rules are ordered as they appear in the source they were extracted from.
Each carries the tier at which it costs to comply, and the date it was
recorded.

Each rule carries one of three labels, and each implies a different follow-up:

`Evidence:`   an incident is written down. Nothing further is needed.
`Found:`      the rule came out of a real investigation, but the individual
              incident was not recorded. It is true; the detail is not
              recoverable. Write the incident down the next time it recurs.
`Rationale:`  reasoning only, never tested by an incident. Design a control
              for it.

A tier tag is `[<tier> (| <tier> if: <condition>)*]`. The first token is the
tier that applies when the conditions cannot be evaluated, so it is always the
conservative one: a reader that does not understand the condition falls back
to it, and overestimating the cost only buys verification nobody needed.

Chasing a failure — reproduction, rates, confounds, and what a measurement
means before it is attributed to anything — is in kit/skills/diagnosis.md, and
those rules are not repeated here.

### A suite that passes on its first run is unverified, not correct.  `[T1]` `[2026-08-12]`

Before trusting a new suite, break the code it covers on purpose. Pick the one
or two behaviours most likely to be got wrong, confirm the expected tests fail,
and read *which* ones failed. Then revert and re-run.

> Rationale: A green first run is equally consistent with tests that assert
> nothing discriminating. Breaking the code on purpose is the only evidence
> that a green suite means anything, and it is cheap.

<!-- source: METHOD.md 67-73 -->

### A green suite is evidence only for the code it actually runs.  `[T0]` `[2026-08-12]`

Run the suite that covers what you changed. If no suite covers it, that
absence is itself the finding and must be reported. A probe that was written
and never run is worse than no probe, because its presence in the tree reads
as evidence to whoever comes next.

> Evidence: Hundreds of unit tests passed over a component whose two error
> notices were wired the wrong way round, disclosing to a stranger the one fact
> the error existed to withhold. Nothing in the unit suite touched that
> component, and the browser script that did cover it had been written in the
> same session as the bug and never run.

<!-- source: METHOD.md 75-83 -->

### Some assertions cannot be sabotaged safely, and those stay unproven.  `[T0]` `[2026-08-12]`

Sabotage is cheap where the blast radius is the check itself. It is not cheap
where the only way to falsify an assertion is to destroy live data. Sabotage
what you can, name what you could not, and never let one round of it vouch for
a whole file.

> Evidence: A deletion suite's control — that a record which has not expired
> survives — could only be falsified by removing or inverting the filter that
> decides what gets deleted, which empties the table on the live database.

<!-- source: METHOD.md 85-92 -->

### A sabotage has to be aimed at the assertion under test.  `[T0]` `[2026-08-12]`

Pick a sabotage whose blast radius is the assertion you are testing. If it is
not, move it somewhere with fewer neighbours. Treat "the run died first" as a
result that has not answered the question.

> Evidence: A sabotage meant to test a layout assertion broke interaction so
> thoroughly that the run aborted at an unrelated click, several assertions
> before the one under test. That says the suite is fragile, not that the
> assertion works.

<!-- source: METHOD.md 94-100 -->

### Aim the scenario as well as the sabotage.  `[T0]` `[2026-10-01]`

Before trusting an assertion, name the configuration in which the code under
test is necessary — the narrowest screen, the input with gaps, the case where
nothing else would do the job — and assert there. A check that runs only where
the feature is redundant passes whether or not the feature exists, and a
sabotage run there passes too, which reads as the sabotage having missed.

> Evidence: Two projects. A grid meant to narrow its columns on a phone was
> checked at 390px, and a sabotage that froze the columns passed the whole
> script: seven fixed-width days fit 390px anyway. At 320px the frozen grid
> overflowed, and the same sabotage failed at once. In the other, an
> acceptance criterion said a protected program had to be closed within two
> seconds of its window appearing, and named notepad.exe, which on Windows 11
> starts a stub that exits by itself while a different process owns the
> window. Approved and reviewed, it would have been satisfied by the stub
> disappearing while the window stayed open. Only running it showed that, and
> the subject became a plain program nothing else closes.

<!-- source: TempTime METHOD.md, after the copy in source/; promoted 2026-10-01 -->

### Confirm the sabotage landed before reading the result.  `[T0]`  `[2026-08-12]`

An injection that silently did nothing and a check that correctly passes
produce the same output. Grep for the damage and confirm the count before
trusting a green run: an anchor string that does not exist in the target file
fails without saying so, and the result reads as the check working.

> Evidence: A sabotage aimed at one file used an anchor from another, so
> nothing was inserted. The first run reported ok and would have been recorded
> as a passing case had the injection not been counted separately.

<!-- source: none; first recorded in this project -->

### A probe whose outcomes cannot differ proves nothing.  `[T1]` `[2026-08-12]`

Pick a target where success and failure look different. Run the known-bad
control in the same breath as the real one; if the two produce identical
output, the test has not started yet.

> Evidence: A secret was tested against an endpoint that rejects every
> credential of that class regardless of the token, so the real secret and a
> deliberately wrong one both returned an identical failure. The value looked
> broken when it was merely untested, and two rounds were lost that way.

<!-- source: METHOD.md 127-134 -->

### A credential is not verified by where it was copied from.  `[T1]` `[2026-08-12]`

Provenance is not evidence, and neither is passing a local shape check. Only
the live service can tell a working credential from a plausible-looking value.

> Evidence: A dashboard displays a key's identifier next to its value; the
> identifier passed the project's own length guard and was indistinguishable
> from the real thing until the service was called.

<!-- source: METHOD.md 136-138 -->

### An equality check is satisfied by two absences.  `[T0]` `[2026-08-12]`

Every comparison of the form `a === b` passes when the thing being measured
never appeared at all. Anchor the assertion on a value known to be non-empty,
so that finding nothing fails instead of agreeing with itself.

> Evidence: An assertion comparing a restored count against a painted count
> reported success while both were zero.

<!-- source: METHOD.md 140-144 -->

### Log the call, not only the transition.  `[T0]` `[2026-08-12]`

Instrumentation carries the same requirement as a test, and it is easier to
get wrong because nobody sabotages a debug log. A log that records only
changes cannot distinguish "the handler never ran" from "the handler ran and
computed the value it already held".

> Evidence: Chasing why an interaction left a readout blank, the first probe
> recorded every change of the state behind it. Both hypotheses produced an
> identical empty log, and the empty log was read as evidence for the wrong
> one.

<!-- source: METHOD.md 146-152 -->

### A comment claiming a line is required is a testable prediction.  `[T1]` `[2026-08-12]`

Remove the line and see. Keep it or drop it on the result, and if the reason
in the comment turns out to be false, record both observations rather than the
one that did not survive.

> Evidence: A line copied from a framework's own documentation and explained in
> a comment as load-bearing was commented out and changed nothing — the
> framework read the value from a different place than the documentation named.
> The line was kept, because documented behaviour is the better bet across
> upgrades, but the comment now records both observations.

<!-- source: METHOD.md 215-223 -->

### A sentence describing what happens when a value is missing is verified by removing the value.  `[T1]` `[2026-08-12]`

Setup documentation is more expensive to get wrong than a code comment,
because the reader has no working system to check it against. Empty the value
the document describes as optional, exercise the path, and restore it.

> Evidence: An example environment file told anyone setting the project up that
> one variable could be left empty and a feature would degrade gracefully.
> Emptying it and calling the endpoint failed outright — the value signs a
> token issued during setup, so nothing worked without it.

<!-- source: METHOD.md 225-231 -->

### A production number is not asserted from a machine that is not production.  `[T0]` `[2026-08-12]`

Where a target describes deployed behaviour — a latency, a throughput —
measure it and print it, but do not fail a local run against it, and say in
the spec why. This holds only where the difference is structural and named:
"it is slow here" is not a reason to stop asserting something.

> Rationale: Asserting a deployed number locally tests where the laptop is,
> not what the deployed system does.

<!-- source: METHOD.md 233-238 -->

### UI is verified by driving it, not by reading it.  `[T2 | T1 if: browser harness exists]` `[2026-08-12]`

A component that type-checks and builds has been proven to compile, nothing
more. Drive the running application in a real browser, assert on what the DOM
actually says — computed styles, element counts, the text a user would read —
and screenshot it to look at.

> Found: six separate traps, of which the rules that follow are the ones kept.

<!-- source: METHOD.md 275-278 -->

### A probe that finds nothing has usually found a wrong selector.  `[T0]` `[2026-08-12]`

A real absence and a mistyped selector produce the same empty result. Make the
probe assert something known-present first, so that "nothing here" is a claim
about the page rather than about the query.

> Found: one of six traps in a browser-driving investigation; the
> individual incident was not recorded.

<!-- source: METHOD.md 281-282 -->

### Scope a text match to the element under test.  `[T0]` `[2026-08-12]`

An unscoped match finds whichever element happens to contain the words, which
may be an ancestor or a neighbour that carries the same phrase.

> Evidence: A readout assertion matched the heading above the readout, which
> contained the same phrase, and would have passed had the readout never
> rendered at all.

<!-- source: METHOD.md 286-289 -->

### A coordinate measured on a page that updates itself is stale by the time it is used.  `[T1]` `[2026-08-12]`

Wait for the page to settle, then ask what is actually under the point before
dispatching anything to it.

> Found: one of six traps in a browser-driving investigation; the
> individual incident was not recorded. See also "Fix the timing, do not
> retry the probe" in kit/skills/diagnosis.md, which is the same trap
> measured over several runs.

<!-- source: METHOD.md 289-291 -->

### Wait for something only the loaded state can produce.  `[T1]` `[2026-08-12]`

"Wait for the data, not the page" is not enough when the empty state renders
the same shell as the loaded one. Pick a signal that cannot exist before the
data arrives. Then ask, of any empty state you write: is there anything on
screen that tells it apart from the real thing?

> Evidence: A component drew its grid in both states — same role, same
> accessible name, same cell markup — and the placeholder carried no handlers
> and no readout. A probe that waited for that group was satisfied by an inert
> copy, measured a cell on it, and interacted with something that could not
> respond. Days of "the handler never runs" followed, all of it true and none
> of it a bug.

<!-- source: METHOD.md 293-304 -->

### Assert the shape of the answer, not its presence.  `[T0]` `[2026-08-12]`

Any probe that would still pass on a plausibly broken render is measuring the
wrong thing. Assert something that depends on the computation behind the
output.

> Evidence: "Some cells are coloured" is satisfied by a scale that renders one
> colour everywhere. Grouping the cells by computed colour and requiring the
> group sizes to come out at specific counts is an assertion about the
> arithmetic behind the picture.

<!-- source: METHOD.md 324-328 -->

### Where an assertion needs a threshold, prefer one the codebase can defend.  `[T0]` `[2026-08-12]`

A threshold expressed relative to what the project already does can be argued
about and held to. A number borrowed from an external guideline invites a
redesign of everything that has never bothered anyone, and is the kind of
number that gets loosened the first time it is inconvenient.

> Evidence: "No control is a smaller tap target than the primary buttons
> already are" is defensible in review; the equivalent absolute figure from a
> platform guideline is not, in the same way.

<!-- source: METHOD.md 330-335 -->

### A translation is verified on what gets copied out of it, not on how it reads.  `[T1]` `[2026-08-12]`

Diff the copy-pasteable parts mechanically: strip the fences and the comments,
compare the remaining lines against the original. Give structure the same
treatment — matching counts of headings, code blocks and table rows is what
catches a section dropped during translation.

> Evidence: Prose can be clumsy and still work; a command that got translated
> along with the sentence around it cannot, and the reader will paste it
> without suspecting the document. Both checks together took one command.

<!-- source: METHOD.md 337-344 -->

### The platform that produces a file cannot report that the file is broken on another platform.  `[T0]` `[2026-08-12]`

Anything written on one machine carries properties that machine does not
enforce and therefore cannot check: line endings, an executable bit, file
permissions, a lockfile's platform. A check run where the file was produced
passes whatever those properties are. Assert what the repository records
against the index rather than the working tree, since the index is what other
platforms receive. Prove the rest on the platform that enforces it, and say so
where that has not happened.

> Evidence: Three projects, all produced on Windows. A lockfile written there
> omitted a dependency only macOS installs, and the first clean install on
> macOS refused outright. A script committed with CRLF ran where it was
> written and failed elsewhere with a bad interpreter; a version file came out
> with a trailing carriage return that a string comparison would have read as
> a permanent mismatch; an executable bit was recorded as absent, leaving the
> scripts unrunnable on every platform that honours it. A generated password
> kept a carriage return nobody could see, so it could never be typed back.
> And a permission failure the project had to guard against could not be
> reproduced there at all, because Docker Desktop shows every bind-mounted
> file with every permission set.

<!-- source: SparkForge METHOD.md; promoted 2026-10-01 -->

### A restatement is a copy, and nothing keeps an unguarded copy true.  `[T1]` `[2026-08-20]`

Where something has to be said in a second place, there are three outcomes and
only two of them are chosen. Point at the original and state nothing. Restate
it and add something that diffs the two. Or restate it and find out later.

The test is whether the restatement can be compared mechanically against what
it describes. A layout, a numbered procedure, a recorded status, what a piece
of code does: each of those is diffable against the thing itself, so a copy of
one that nothing diffs is already waiting to go false. Copies that cannot be
diffed are a different problem and this rule does not reach them.

> Evidence: Two projects. A README restated its project's layout, its setup
> procedure and one component's execution record; all three were false within
> four commits, and no change that falsified one reported anything. In the
> other, a code comment said the top step of a colour scale meant everyone had
> answered, and the arithmetic stopped delivering that above five people, so
> six of seven and seven of seven drew the same colour — the one answer the
> page existed to show. The fix there was the first outcome: the legend's
> labels are now computed by the function that colours a cell, so there is no
> second copy left to drift.

<!-- source: SparkForge METHOD.md; promoted 2026-10-01 -->

### Fixtures you wrote share your assumptions; one real artefact does not.  `[T1]` `[2026-10-01]`

A synthetic suite proves the cases its author thought of, because the same
head wrote the code and the cases. Before concluding that the code is fine and
the problem is elsewhere, run it on one real input from the world it will
meet: the user's actual file, the real program, the production record.

> Evidence: Two projects. Asked why a calendar import did nothing, seven
> synthetic .ics files covering every shape that seemed to matter all passed,
> and the conclusion drawn was that the parser was fine. The user's actual
> export threw on its first recurrence rule, on a property none of the seven
> used. In the other, a tool that ends chosen programs passed every test
> against a plain system program and did nothing to the game it was built for:
> under that game's anti-cheat the process listing it relied on reports no
> path, and the watcher discarded every start it could not name. Only running
> the real game found it.

<!-- source: TempTime METHOD.md, after the copy in source/; promoted 2026-10-01 -->
