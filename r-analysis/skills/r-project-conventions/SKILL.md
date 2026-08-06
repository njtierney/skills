---
name: r-project-conventions
description: Conventions for structuring an R analysis project — packages and conflicts instead of pkg::fun(), fs over base file functions, air formatting, .Renviron, where generated files go, what the README must answer, and how to size files in R/. Use when setting up an R project, tidying one, reviewing R code for structure rather than correctness, or when asked about project layout, namespacing, conflicted, fs, or air.
---

# R project conventions

These apply to any R analysis project. For pipeline-specific rules — what belongs
in `_targets.R`, dynamic branching, file targets — see the `targets-workflow`
skill, which assumes everything here. For the inside of a function — where
validation lives, when one function should be several, decomposing a calculation
— see `r-function-design`, which also assumes everything here.

This skill is about the envelope: files, directories, sessions. Not the code
inside the functions.

## Packages

### Attach packages; do not write `pkg::fun()` everywhere

```r
# packages.R
library(conflicted)

library(ggplot2)
library(fs)
library(mgcv)
library(withr)
```

**One `library()` call per line, and no list of names in a character vector.**
`renv::dependencies()`, `pak`, RStudio's missing-package prompt and every other
static scanner reads `library()`, `require()` and `::` — a vector of package names
handed to `lapply(library, character.only = TRUE)` is invisible to all of them. Do
that *and* de-namespace the codebase, and nothing declares the project's
dependencies at all; renv will then happily miss real ones and pick up phantoms
from example or reference code. Worth testing on any project that has been tidied
this way:

```r
renv::dependencies(".")
```

Then call `gam()`, not `mgcv::gam()`. Namespacing every call is noise: it triples
the width of a `ggplot2` chain and buries the shape of the code in prefixes that
are the same on every line.

The objection to attaching — that masking makes it ambiguous which function you
got — is real, and `conflicted` is the answer to it. It turns an ambiguous call
into an error naming both candidates, rather than silently taking whichever
package attached last. So attaching is *safer* than namespacing plus vigilance,
because the machine does the checking.

`pkg::fun()` still earns its place in three cases: a package used once or twice
for a utility and not otherwise needed, disambiguating deliberately at a call
site, and inside a package's own `R/` where attaching is not an option. `tools` is
the usual instance of the first — `R_user_dir()` and `md5sum()` do not justify
attaching it, and leaving it unattached often removes a conflict.

### Declare conflicts in `conflicts.R`

```r
# conflicts.R -- sourced after packages.R
# tools and withr both export makevars_user(). withr is a direct dependency;
# tools is attached only for R_user_dir(), so withr is the one we would mean.
conflict_prefer("makevars_user", "withr", quiet = TRUE)
```

One file, sourced after `packages.R`. Every entry is a decision, so keep the
reason next to it — "we picked one" is not a reason. The `conflicted` error is
the prompt to come here and decide.

Check rather than guess, and prefer removing a conflict to declaring it — often
the clash comes from attaching a package you only needed two functions from:

```r
conflicted::conflict_scout()   # what is actually ambiguous
```

`0 conflicts` is a normal result. Keep the file anyway, with a comment saying what
goes in it, so the next conflict has a home.

**Every entry point must load the same setup, or attaching is worse than
`pkg::fun()`.** The rule above assumes one package environment. The moment two
entry points load different ones, a bare verb resolves differently depending on
who ran it.

A project put `conflicts_prefer(dplyr::filter)` in `packages.R`, but its
`tests/testthat/helper-*.R` sourced `R/` without it. The pipeline built green;
the suite went from 262 passing to **38 failures**, because a bare `filter()` in
`R/` was `dplyr::filter` under the pipeline and `stats::filter` under testthat.
The error — `object 'active' not found` — pointed nowhere near the cause.

So: pipelines, test helpers, Quarto reports that load `R/` on their own account,
and the app all source the same file. Check it, do not assume it:

```r
# in every entry point that loads R/
source("packages.R")
```

If an entry point genuinely cannot, then qualify the verbs in the code it
reaches — `dplyr::filter()` — and say why in a comment. That is the narrow case
where `pkg::fun()` earns its place.

## Use `{fs}` for anything touching the filesystem

`fs` over `base`:

| base | fs |
|---|---|
| `file.path()` | `path()` |
| `dir.create(recursive = TRUE)` | `dir_create()` |
| `file.exists()` | `file_exists()` |
| `file.rename()` | `file_move()` |
| `basename()` / `dirname()` | `path_file()` / `path_dir()` |
| `tools::file_path_sans_ext()` | `path_ext_remove()` |
| `list.files()` | `dir_ls()` |
| `unlink()` | `file_delete()` |

It is not only tidier. The base functions are inconsistent about failure —
`file.rename()` returns `FALSE` and lets you carry on with a path that does not
exist; `dir.create()` warns rather than errors; `file.path()` will happily build a
path out of an `NA`. `fs` errors, returns typed `fs_path` vectors, and is
consistent about vectorisation. A silent `FALSE` from a move becomes a confusing
failure three steps later, which is the expensive kind.

## Format with `{air}`

```bash
air format .          # in place
air format --check .  # exit non-zero if anything is unformatted
```

Settings go in `air.toml` at the project root, so they belong to the project
rather than to whoever's editor last touched the file:

```toml
[format]
line-width = 80
```

Format *before* reviewing, never as part of a substantive change: a commit that
both moves code and reformats it cannot be read.

## `.Renviron` for session options

```
_R_CHECK_LENGTH_1_LOGIC2_=verbose
_R_CHECK_LENGTH_1_CONDITION_=true
```

Makes a length > 1 condition in `if()` or `&&` an error rather than a silent use
of the first element — the class of bug that survives review because the code
looks right.

**It must be `.Renviron`, not `.env`.** R reads `.Renviron` (project, then user)
automatically; it does not read `.env`, and nothing will tell you so. A guard
that never runs is worse than no guard, because it buys confidence it has not
earned. Verify with `Sys.getenv()` after adding one.

One qualification before flagging an existing repo: tflow-era projects carry a
`.env` *and* `library(dotenv)` in `packages.R`, which does read it — for every
entry point that sources `packages.R`. That works; it is just one more thing
that silently stops working in a session that skipped the setup, which is why
new projects use `.Renviron`.

Say in the README what is in it. Whether to commit it depends on what it holds: a
project `.Renviron` carrying only guards like the above is worth committing, so a
fresh clone builds with them on rather than silently without. Gitignore it the day
it grows a credential — and then say in the README what a collaborator has to put
back.

## Everything generated goes under `output/`

Nothing produced by a build should sit at the repo root. `ls` at the top level
ought to show what a person *wrote*.

```
output/
  <deliverable>/    what you hand over. Committed
  sheets/           figures a README or report shows. Committed
  scratch/          intermediates and exploration. Gitignored
  report.html       rendered. Gitignored
```

Split it by *whether it is committed*. Committing a deliverable is often right —
a downstream repo may link to it, and a reader should not need a build to see the
result — but committing eighty exploration files that regenerate in thirty
seconds is not.

Keep path construction in one file. A layout spread across three files is a
convention two of them agree on by coincidence, which is the same hazard as a
constant declared twice.

## Separate the pure part from the side effect

```r
plot_it    <- function(data) ggplot(data) + geom_point()      # returns an object
write_plot <- function(path, data) { ggsave(path, plot_it(data)); path }
```

The pure function is what you test, reuse and look at in the console; the writer
is a thin shell. Keep the filesystem in as few functions as you can, and let the
call site show where the effect happens:

```r
write_image(sheet_contact(stickers), sheet_path("contact-sheet.png"))
```

That reads as "assemble, then write". A `write_contact_sheet()` that does both
hides the effect inside the assembly, and cannot be exercised without producing a
file.

## Annotate `.gitignore`

Say *why* each entry is there, and note the exceptions:

```gitignore
# Rendered Quarto. The .qmd is the source; these regenerate.
# EXCEPTION: proposal/*.html is kept — it is what the client received.
planning/*.html
```

An unexplained `.gitignore` is where a repo's real constraints go to be
forgotten — licensing, confidentiality, file size. Write them down.

## The README answers four questions

A project is not self-documenting. Write the README so a stranger — or you in six
months — gets these in order:

1. **What is this?** One paragraph, before anything else. What it produces, for
   whom. A figure of the actual output if there is one.
2. **Why does it exist, and why is it built this way?** The decisions someone
   might otherwise undo: what was traded off, what was measured, what was
   rejected. No other file can carry this, and it saves the most time later.
3. **How do I run it?** The command, the dependencies, and — most usefully —
   *which file to edit to change the answer*. Name the one function or config
   block holding the choices.
4. **Where is everything?** A table per directory. One line each, saying what a
   file is *for*, not what it contains. Mark which outputs are the deliverable
   and which regenerate.

**Why before where.** A reader who understands the point can navigate a layout
they have not seen; a reader given a file listing first has to reverse-engineer
the intent from it.

Two failure modes: a README that is only a file listing tells you nothing `ls`
would not, and one that is only a design essay leaves the next person unable to
build it. Both halves, in that order. If the *why* runs long, move the detail to
`ARCHITECTURE.md` and keep the README to decisions plus one-line reasons.

## Naming and sizing files in `R/`

Name files after the concern, hyphenated, with related ones sharing a prefix so
they sort together: `constraints-classify.R`, `constraints-surface.R`,
`outputs-plots.R`, `outputs-tables.R`. Avoid `utils.R` and `helpers.R` — they
become the drawer where anything nobody wanted to name ends up.

**One file per concern, not one file per function.** The unit is "one reason to
change": functions sharing a fit, a data shape or an output format belong
together, because the relationship between them is part of what a reader needs.
Split when a file grows past roughly 300 lines, when it starts serving two
purposes, or when two people are genuinely contending over it — not on principle.

The case for strict one-function-per-file is real — no merge conflicts, and the
filename tells you where to look — but it costs more than it looks. A model fit
is a data function, a fitting function, an extraction function and several
consumers; split into eight files, the relationship stops being visible along
with the header comment explaining the approach. Constants are not functions, so
they end up in a `constants.R` that breaks the rule on day one. And the collision
argument is weaker than it seems: two people editing the same logic collide on
semantics whether or not the text is in one file, and git merges non-overlapping
hunks without complaint.

It *is* worth it for an exported package API, where each function carries its own
roxygen block and test file and the file is the documentation unit.

## Look for the project's answer before building your own

Before writing a check, a probe, or a helper to answer a question about the
project, find out whether the project already answers it. Read the test file,
the helpers, the existing harness. This costs a couple of minutes and routinely
saves an afternoon.

The failure mode is specific and it does not announce itself: **a bespoke check
that passes reads as success.** Nothing in the result tells you it was
unnecessary, or that the project's own version was stronger and already
passing. Contrast an assertion with no evidence, which at least feels thin —
this one feels productive the whole way through, so it is only ever caught by
someone asking "don't we already test that?"

Two real cases, one afternoon:

- Wrote a moment check for two distributions, calibrated a tolerance for it,
  committed it. `test_iid_samples.R` already compared them against independent
  reference samplers with a two-sample Cramér test — stronger, and passing the
  whole time.
- Announced that six of eight optimisers had no tests, from a grep. Six were
  tested in a loop that passed them as bare symbols, which the grep's `(`
  missed. The real gap was two.

So, in order:

1. **Run the project's tests before writing one.** `devtools::test()`, whole
   suite, not a filter over the files you happen to have touched. A filter tells
   you about those files; it says nothing about the branch.
2. **Read `tests/testthat/helpers.R`** before writing a comparison. Reference
   RNGs, distributional comparisons and convergence helpers usually already
   exist there.
3. **`grep -w`**, or better, load `posit-dev:review-testing`, which
   cross-references production code against tests properly. Hand-rolled patterns
   miss bare symbols, end-of-line, and non-call usage.
4. **If you still need your own check, say what the project's one did not
   cover.** If you cannot name that, you are duplicating.

## Reviewing structure

1. Is anything namespaced that should be attached, or attached without
   `conflicted`?
2. Any base file functions where `fs` belongs?
3. Does `air format --check .` pass?
4. Is anything generated sitting at the repo root?
5. Is path construction in more than one file?
6. Do any functions mix assembling a thing with writing it?
7. Does the README answer all four questions, in order?
8. Any file in `R/` past ~300 lines or serving two purposes?
9. Is `.Renviron` actually being read? (`Sys.getenv()`, not assumption.)
10. Does any check here duplicate one the project already had?
