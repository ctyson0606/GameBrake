# GameBrake

## Declarations
MODE: project        # project | sprint
TEAM: 1

## Environment facts
install: dotnet restore
dev: dotnet run --project src/GameBrake.Tray
test: dotnet test
typecheck: none      # C# type-checks during build, there is no separate command
lint: none           # no analyzer configured yet, see STATE.md Known Annoyances
build: dotnet build
e2e: powershell -ExecutionPolicy Bypass -File scripts/e2e.ps1
pack: powershell -ExecutionPolicy Bypass -File scripts/pack.ps1
# Leave blank if not yet established. Write "none" if this project
# genuinely has no such command — "none" is itself a finding and must
# be reported in any verification, not silently skipped. Put the reason
# after it as a comment: "not applicable" (a language whose type check is
# its build) and "not set up yet" (no linter chosen) both read as a bare
# "none", and only the second is a gap.
# Add a line for any other command the project depends on, such as a
# packaging step. A command nobody lists is one the next session does not
# know exists.
# scripts/check.sh is never a value here, nor an acceptance criterion. It
# checks this framework's layout, so no defect in the project can make it
# fail.

## Hard rules (always apply, regardless of tier)
- Stop and ask when a requirement is vague. Do not fill the gap with an assumption.
- Stop when the scope changes. Do not finish the larger thing you found.
- No completion claim without evidence: commands run, output, residual risk.
- Touch only the files in the agreed scope. Say so if anything else changed.
- Before automating a manual action, count how many items and how often.
- When proposing something larger than what was asked, first state why the
  smaller version is insufficient.
- Write English into every file: code, identifiers, commit messages, and
  SPEC.md, METHOD.md, STATE.md and GOTCHAS.md. Talking to the user, and the
  README, follow whatever language they ask for. A memory file that
  accumulated in two languages is what this prevents, and it only accumulates.
- Write memory as you go, not when asked: the moment state changes, by
  kit/skills/memory-update.md. The memory files are always in scope. A session
  can stop without warning, and what was not written is lost with it.

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
point into kit/, and so does scripts/: its two files hand over to
kit/scripts/. Edit kit/, never the stubs.
Do not edit anything under kit/ inside a project that consumes
this framework — send the change upstream and pull it back with
scripts/update-kit.sh. This project's own knowledge lives only in
SPEC.md, METHOD.md, STATE.md and GOTCHAS.md, which are never
overwritten.
scripts/check.sh verifies the invariants of this layout. Run it after
any change to kit/, the stubs, or AGENTS.md itself.
Anything that belongs to SparkForge rather than to this project — a
rule that proved wrong or useless here, a check that missed something,
a stub or script that did not work, a framework rule this project was
the first to actually walk — goes under Upstream in STATE.md, written
as you go like the rest of memory. Leave it there until upstream has
it. That section is the only thing upstream reads from a project, and
a note kept anywhere else is never found.

## Memory
@SPEC.md
@METHOD.md
@STATE.md
@GOTCHAS.md
