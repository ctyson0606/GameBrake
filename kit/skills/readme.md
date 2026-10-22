---
name: readme
description: Writing or rewriting the README — its shape, its three editions,
             and the two sections check.sh holds to the repository.
---

# README

Read this before writing or rewriting a README, and before any change that
makes one false: a new install step, a renamed path, a changed command.

kit/readme-skeleton.md is the shape below as a file to copy. Start from it.

## Shape

In this order. Leave out a section that has nothing true to say; never fill
one to keep the order.

1. **Hero**, centred: the name as `<h1>`; one sentence in bold saying what it
   is, then what it does; a row of shields.io static badges; the language line.
2. **Screenshot**, centred, under the hero. Until an image is committed, the
   slot stays an HTML comment: a link to a missing image renders broken.
3. `## ✨ Features`: one bullet per feature, `**Name**: one sentence`. Take
   them from SPEC.md: the goals, and the Means lines where they are written.
4. `## 🚀 Installation`: the prerequisite in one line; numbered options as
   `**Option 1 · …**`, the one most people need first; an option for the few
   inside `<details>`; and always a closing `**Verify**` block with a command
   and what its output looks like when it worked.
5. `## 🕹️ Usage`: `###` subsections by task, not by component. The Try lines
   in SPEC.md are the usage guide; start there.
6. The project's own sections, each with its own emoji, between Usage and
   Development: what a user of this project needs that the others do not.
7. `## 💾 …`, a settings or storage table, `| Item | Value |`, where there is
   configuration a user can see or change.
8. `## 🛠️ Development and testing`: the commands a contributor runs, each in a
   fence. Checked; see below.
9. `## 📦 Project layout`: the top-level paths that matter, one per line in a
   `text` fence, then one bullet per path saying what it holds. Checked; see
   below.
10. `## ⚠️ Compatibility and limits`: what it does not do, and where it
    degrades.
11. `## ❓ FAQ`: a `| Symptom | What to do |` table, from problems that
    actually happened.
12. `## 📄 License`: one line, linking LICENSE.

Style: short sections, bold for the term a bullet defines, inline code for
every name a reader might type or search for, tables for anything with two
columns. No section restates another.

## Editions

Three files of one structure: README.md in English, README.zh-TW.md and
README.zh-CN.md. Each carries the same language line in the hero, linking the
other two, and every edition marks itself without a link. Translate prose,
never what a reader copies: fences, inline code, paths, ids and badge URLs stay
byte for byte. check.sh compares headings, fences and table rows across the
editions, and the content of every fence.

Write the English first, then translate it; a fix lands in all three in the
same commit.

## Sources

Read every claim out of the repository, not out of memory or a previous
README: commands from AGENTS.md's Environment facts, behaviour from the code,
features from SPEC.md. A badge shows only what a file in the repository holds
(the licence, a pinned version, a declared platform), and changes with it.

## The two checked sections

The layout block and the development commands are the README's restatements of
the repository, so each has something that diffs it, by the rule in
kit/skills/verification.md that a restatement nothing diffs goes false.

- Every path in a fence under a `## 📦` heading must exist. Write one path per
  line; a `# comment` after it is allowed, a drawn tree is not.
- Every command in a fence under a `## 🛠` heading must be, character for
  character, one of the Environment facts in AGENTS.md. A command worth
  documenting for contributors is worth listing there first.

Both read README.md only; the translation check carries them to the editions.

### A README's development commands are copied from AGENTS.md, not written.  `[T0]`  `[2026-10-22]`

The command a contributor is told to run has a source of truth one file away,
and a README that names a different one is believed over it, because the
README is what a newcomer reads.

> Evidence: One project's README told contributors to run `node --test
> test/`, which the Node build there refused; its Environment facts already
> held the form that runs, `node --test test/*.test.js`. In another project a
> README restated the layout, the setup procedure and an execution record,
> and all three were false within four commits.
