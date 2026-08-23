# GameBrake

## Declarations
MODE: project        # project | sprint
TEAM: 1

## Environment facts
install: dotnet restore
dev:                 # no runnable host yet; the tray app does not exist
test: dotnet test
typecheck: none      # C# type-checks during build, there is no separate command
lint: none           # no analyzer configured yet, see STATE.md Known Annoyances
build: dotnet build
e2e:                 # AC1-AC9 need the Windows host, which is not built yet
# Leave blank if not yet established. Write "none" if this project
# genuinely has no such command — "none" is itself a finding and must
# be reported in any verification, not silently skipped.

## Hard rules (always apply, regardless of tier)
- Stop and ask when a requirement is vague. Do not fill the gap with an assumption.
- Stop when the scope changes. Do not finish the larger thing you found.
- No completion claim without evidence: commands run, output, residual risk.
- Touch only the files in the agreed scope. Say so if anything else changed.
- Before automating a manual action, count how many items and how often.
- When proposing something larger than what was asked, first state why the
  smaller version is insufficient.
- Write English into every file: code, identifiers, commit messages, and
  METHOD.md, STATE.md and GOTCHAS.md. Talking to the user, and the README,
  follow whatever language they ask for. A memory file that accumulated in
  two languages is what this prevents, and it only accumulates.

## Tiers
T0  free — do it under any time pressure
T1  moderate cost — advisory when MODE is sprint
T2  expensive — skipped when MODE is sprint

## Skill routing

Each entry below is kit/skills/<name>.md. Read the file, not this line.

bootstrap — The one-time opening pass, run only while METHOD.md and STATE.md
  are both still empty shells.
spec-gate — What has to be settled before implementation starts, at a depth
  set by MODE.
team-contract — The two things more than one person has to agree on once, and
  nothing beyond them.
verification — Judging whether a test, probe, or suite actually constitutes
  evidence. Read before trusting any green run.
diagnosis — Chasing a failure to its cause: reproduction, rates, confounds,
  and what a measurement means before it is attributed to anything.
memory-update — When memory is written, by whom, and what an update has to
  re-read before it writes.

## Entry points

This file is the entry point for every tool. Each tool that will not read it on
its own has a small file at the path it does read, and that file says to come
here. kit/entry-points.txt lists them, and scripts/check.sh reads that list to
confirm each one still points here.

Never put an instruction in one of those files. Two tools reading two different
sets of rules is the failure the whole arrangement exists to prevent. If a
project does not use a tool, delete its entry.

## Canonical content

kit/ holds the canonical content. Each tool-specific directory
(.claude/, and one per additional agent tool) holds thin stubs that
point into kit/. Edit kit/, never the stubs.
Do not edit anything under kit/ inside a project that consumes
this framework — send the change upstream and pull it back with
scripts/update-kit.sh. This project's own knowledge lives only in
METHOD.md, STATE.md and GOTCHAS.md, which are never overwritten.
scripts/check.sh verifies the invariants of this layout. Run it after
any change to kit/, the stubs, or AGENTS.md itself.
When sending an improvement upstream, review the Unverified block in
the upstream STATE.md and tick off anything this project exercised.
A rule that has now been walked is a finding worth more than the
improvement itself.

## Memory
@METHOD.md
@STATE.md
@GOTCHAS.md
