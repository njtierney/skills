---
name: targets-workflow
description: Structure an R analysis as a targets pipeline. Use when setting up a new targets project, converting scripts to a pipeline, writing new targets, reviewing or tidying an existing _targets.R, debugging an errored target or failed tar_make (workspaces, tar_workspace, workspace_on_error), adding crew parallelism, splitting one pipeline into several, or when asked about targets layout, packages.R, _targets.yaml, tar_assign, tar_plan, tar_hook_before, or "make this a targets repo".
---

# Structuring a targets pipeline

Conventions follow [tflow](https://github.com/MilesMcBain/tflow) (Miles McBain),
the [targets manual](https://books.ropensci.org/targets/), and Nick's own project
layout.

**This skill covers only what is specific to a pipeline.** The conventions it
sits on — attaching packages with `conflicted` rather than `pkg::fun()`, `fs` over
base file functions, `air`, `.Renviron`, `output/`, separating pure functions from
writers, what the README must answer, how to size files in `R/` — are in the
**`r-project-conventions`** skill. Read that first; everything here assumes it.

## The manual is a knowledge store — search it

**The `targets` knowledge store is the full user manual**
(books.ropensci.org/targets): branching, literate programming, performance,
storage formats, cloud, crew, debugging. This skill is the house style; the
store is the reference under it. When a question is not settled here — a
factory's arguments, a branching pattern, a storage format — search the store
before reasoning from scratch. The exact tool name varies by setup; look for a
`targets` MCP tool named like `search_store`:

```
mcp__targets__search_store_005(text = c(
  "<a full sentence describing the question>",
  "<three or four keywords for the same thing>"
))
```

For spatial raster/vector targets, a `geotargets` store covers geotargets the
same way. **No store configured?** Fetch the relevant chapter from
books.ropensci.org/targets directly; store build scripts live in `stores/` at
github.com/njtierney/skills.

## File layout

One pipeline:

```
README.md       what it is, why, where things are, how to run it
_targets.R      the pipeline, and nothing else
packages.R      every package attached, in one place
conflicts.R     declared winners, sourced by the last line of packages.R
R/              functions, one concern per file
output/         everything the pipeline writes. Nothing generated at the root
.Renviron       R options that should apply to every session
air.toml        formatting settings, so they belong to the project
```

More than one pipeline — separate deliverables that should build, fail and
invalidate independently:

```
_targets.yaml   one project per deliverable
pipelines/      one script per project
packages.R
conflicts.R     sourced by packages.R, so every pipeline gets it
R/
.Renviron
```

Plus, on anything long-lived: `ARCHITECTURE.md` for how it fits together,
`decisions/` for decision records, `attic/` (gitignored) for retired code you
are not ready to delete.

`_targets.R` is a **map of the analysis**, not a place code lives. A reader
should see the whole shape of the work in it and know which file in `R/` to open
next.

## The grammar of a pipeline

How to *write* targets, not just review them. Distilled from the repos these
conventions come from — ttiq-simulation (150 functions averaging 50 lines; a
547-line `_targets.R` that still reads end to end), icebreaker, targets-storms,
demo-geotargets. Spaghetti is always the same failure: a few big targets with
multi-step bodies, anonymous pipelines inline, functions that read, clean, plot
and write in one go. The grammar is the antidote.

**Verbs in `R/`, nouns in the plan.** Functions are `verb_noun()`; the targets
bound to them are nouns. The reader learns the shape of the analysis from the
nouns and what happens from the verbs.

| function prefix | it... | example target bound to it |
|---|---|---|
| `read_`, `get_` | acquires data | `cases_nsw`, `populations_raw` |
| `tidy_`, `clean_`, `prepare_` | reshapes for use | `storms_tidy`, `penguins_modelling` |
| `fit_`, `derive_`, `calculate_`, `sim_`, `run_` | computes the science | `storms_model`, `tp_reductions` |
| `gg_` | returns a ggplot, writes nothing | `plot_tp_reduction` |
| `write_` | writes a file, returns the path | `plot_tp_reduction_path` |

- **One function call per target** (rule 3), named arguments once there are more
  than two. If a body wants a second step, that is a new function or a new
  target.
- **Section comments are the chapters of the analysis.** `# vaccination rollout
  formatting`, `# simulate prioritisation strategies` — a handful of them turn a
  long plan into a table of contents. (These are navigation markers in the
  `code-comments` sense, not comments to audit.)
- **A value and its file are two targets.** `tp_reductions` computes;
  `tp_reductions_path` writes it with a writer that returns the path (rule 4).
  Never fuse them — the value stays `tar_read()`-able and the write stays
  visible.
- **Writers are shared helpers, written once.** `write_csv_return_path()`,
  `ggsave_write_path()`, `saveRDS_write_path()` — make the directory, write,
  return the path. Every output target uses them; nobody re-derives the
  write-then-return dance inline.
- **Parameters are targets** (rule 1): `p_active_detection <- 0.95 |>
  tar_target()`, and derived parameters are targets computed from them. A magic
  number inline in a `mutate()` inside the plan is the quiet version of the
  constants-in-`R/` trap.
- **Target-sized functions.** Most functions in the exemplar repos are 15–50
  lines: one transformation, testable from the console. If a function needs its
  own internal section comments, it is usually two functions — see
  `r-function-design` for the internals and `r-project-conventions` for where
  they live.

**Converting a script** is the same grammar applied stepwise: take the next
value the script computes, extract the code that computes it into a verb
function in `R/`, bind the value to a noun target, repeat until the script is
only targets. Convert incrementally and `tar_make()` as you go — never rewrite
the whole script in one pass.

## 1. Nothing is assigned outside the pipeline

The rule that matters most, and the one most often broken.

```r
# WRONG — runs at definition time, invisible to the dependency graph
themes <- build_themes()
n_boot <- 500

list(
  tar_target(fit, model(data, themes, n_boot))
)
```

```r
# RIGHT — every value is a target, so changing it invalidates what used it
tar_assign({
  themes <- build_themes() |> tar_target()
  n_boot <- 500 |> tar_target()
  fit <- model(data, themes, n_boot) |> tar_target()
})
```

An object created outside the pipeline is not tracked. Edit it and targets
reports everything up to date while the results are stale. Worse, a value
computed both outside *and* inside — a shadow copy — can silently disagree with
itself, usually surfacing as branches lining up by position after the positions
have changed.

**Three exceptions, all narrow:**

- **Constants sourced by `tar_source()` are *tracked*, which is not the same as
  belonging there.** Non-function globals become `object` nodes with real edges,
  so invalidation works — but that is the whole of what works. See "Constants
  hiding in `R/`" below. A **file path** is worse than merely hidden: it is
  tracked as a *string* while the bytes it names go unwatched (rule 4).
- **Side effects on the session**, not values: registering a font, setting a
  locale, `options()`. These cannot be targets, because targets *skips* an
  up-to-date target and a skipped side effect is a silent failure. See rule 5.
- **Branch grids for static branching** (`tar_map()`, `tar_eval()`), which
  targets needs at definition time by construction. Dynamic branching
  (`pattern = map()`) does not, so prefer it.

### Constants hiding in `R/`

**No `SCREAMING_CASE <- value` in `R/`.** They accumulate quietly, because unlike
the untracked globals above they are not *broken* — which is exactly why nobody
removes them.

Correctness is genuinely fine and it is worth knowing that before arguing about
it. `tar_source()` makes a non-function global an `object` node with real edges,
and invalidation is precise: editing `SHEET_BG <- "#DCDCDC"` in `R/sheets.R`
marked 9 targets stale — every sheet, and nothing else. Measured, not assumed.

What you lose is everything else a target gives you:

| | constant in `R/` | target |
|---|---|---|
| invalidates consumers | yes | yes |
| `tar_read()` | **errors** | yes |
| in `tar_visnetwork()` | only with `targets_only = FALSE` | yes |
| swap without editing source | no | yes |
| branch over it | no | yes |

On a project whose graph is a deliverable, a constant in `R/` is a design
parameter hidden from the map of the analysis. One repo had **20 across 7
files** — sheet background, cell widths, sticker dimensions, safe-area radius,
font family and weights — while that same repo already returned its palette,
themes, layout and design choices from functions bound to targets. The convention
was right; twenty values had simply escaped it.

```r
# hiding in R/sheets.R          # in the pipeline, where the graph shows it
SHEET_BG <- "#DCDCDC"           sheet_bg <- "#DCDCDC" |> tar_target()
CELL_W   <- 300                 cell_w   <- 300 |> tar_target()
```

**The test: would you ever want to change it and see what happens?** If yes it is
a design parameter — put it in the pipeline.

There is exactly one exception: a **value that cannot vary** — a mathematical
fact (`CX <- 1` for the centre of a unit circle) or a number fixed by a file
format or an upstream package. Nothing is gained by promoting it, because there
is no experiment to run.

A **file path** is not an exception but the reverse: it is the one case where
`R/` is never acceptable even though the constant looks just as harmless, for
the separate and more serious reason in rule 4.

Prefer grouping related parameters into a function that returns a list
(`sheet_style()`, `hex_layout()`) and binding *that* to one target, rather than a
target per scalar. It keeps the graph legible and gives the values a home that is
already the project's convention.

Audit an existing project with:

```r
targets::tar_network(targets_only = FALSE)$vertices |> subset(type == "object")
```

## 2. Prefer `tar_assign()`, and pipe into it

`tarchetypes::tar_assign()` names the target on the left, so the name appears
once instead of twice. `tar_plan()` is the tflow spelling and does the same job
with `=`. Either beats `list(tar_target(name, ...))`, where the name is a
positional argument easy to mismatch with what it computes.

`tar_assign()` exists because of [targets#1309](https://github.com/ropensci/targets/issues/1309),
where Hadley Wickham proposed the DSL and Landau noted what makes it work: "I do
enjoy how `quote(x |> f())` evaluates to `f(x)`". The native pipe is a
**parse-time rewrite**, so `x |> tar_target()` *is* `tar_target(x)` — same
deparsed command, same hash. Converting a pipeline to this style rebuilds
nothing, which is a good way to confirm you have not changed anything.

```r
palette <- tar_target(greta_palette())      # both are the same target
palette <- greta_palette() |> tar_target()  # USE THIS ONE
```

**Use the piped form, with the target factory last.** Both are identical to
targets, so this is a readability rule, not a correctness one — but it is the
house style and mixing the two is worse than either. The pipeline then reads as
"here is the computation, and it is a target", with the plumbing at the end where
it can be skimmed past, rather than a wrapper you must read around to reach the
work.

It earns its keep most where the command is itself a pipeline, because the target
options stop interrupting it:

```r
contact_sheet <- sheet_contact(stickers) |>
  write_image(sheet_path("contact-sheet.png")) |>
  tar_target(format = "file")
```

That reads "assemble, write, track" in the order it happens.

**Piping works only when the factory takes `command` as its second argument,
after `name`.** The pipe fills the first free positional slot, and `tar_assign()`
has already supplied `name =`. Check with `formals()` before assuming:

| factory | second formal | piping |
|---|---|---|
| `tar_target()` | `command` | works |
| `tar_file()`, `tar_file_read()` | `command` | works |
| `tar_quarto()`, `tar_render()` | `path` | meaningless — it wants a file path, not a command |
| `tar_combine()` | `...` (`command` comes after) | **errors** — the LHS lands in `...` and is evaluated as a target |
| `tar_map()`, `tar_eval()` | no `name` at all | incompatible with `tar_assign()` entirely |

So `rbind(a, b) |> tar_combine()` fails with `object 'a' not found`, which does
not look like a syntax problem and costs a while to diagnose. Write those the
plain way:

```r
cmb <- tar_combine(a, b, command = dplyr::bind_rows(!!!.x))
```

Do not mix the two styles in one pipeline — pick one and use it throughout, or
the reader starts looking for a meaning in the difference. (Verified against
targets 1.12.0 / tarchetypes 0.14.1; `tar_file()` piping works there, so if you
remember it failing, re-test rather than working around it.)

### Name every target in the script; never behind a factory in `R/`

**No function in `R/` returns a list of targets.** `R/` holds functions; the
pipeline script holds targets, all of them, each written out by name.

```r
# WRONG — twelve targets hidden behind one line
c(
  design_targets(),
  tar_assign({ ... })
)

# RIGHT — the script is the map
tar_assign({
  palette <- greta_palette() |> tar_target()
  accents <- accent_palettes() |> tar_target()
  themes  <- hex_themes(palette, accents) |> tar_target()
  ...
})
```

It parses, it builds, and `tar_visnetwork()` looks identical — which is exactly
why it is tempting. What it costs is the thing `_targets.R` is *for*: a reader
asking "where does `palette` come from?" reads the script, finds a function call,
and has to open another file to find out. Twelve of nineteen targets invisible in
the map is not a map.

The tempting reason is sharing a block between two pipelines without letting the
copies drift. It is not good enough. **What is actually shared is the function,
not the target declaration** — both pipelines call `greta_palette()`, which lives
in `R/palette.R` and is the single source of truth already. The declaration is
one line of plumbing; duplicating it across two scripts is cheap, and a diff that
changes one and not the other is a deliberate act, plainly visible in review.

If you are undoing one of these, the conversion is presentational and you can
prove it: `tar_manifest()` should come back **identical**, and `tar_outdated()`
should be empty.

## 3. A target body is one call, and it shows the side effect

If a body is more than a call with arguments, it belongs in `R/`. That is also
what makes it testable: functions can be called from the console, target bodies
cannot.

```r
# WRONG — a loop in the pipeline
plots <- tar_target(
  vapply(names(groups), function(g) {
    ggsave(file.path("out", paste0(g, ".png")), plot_group(data, g))
    file.path("out", paste0(g, ".png"))
  }, character(1)),
  format = "file"
)

# RIGHT — the loop is a function in R/, the pipeline says what happens
plots <- write_group_plots(data, groups) |> tar_target(format = "file")
```

`r-project-conventions` says to separate the pure builder from the writer. In a
pipeline that pays off twice, because the split becomes visible in the graph:

```r
sheet <- sheet_contact(stickers) |>
  write_image(sheet_path("contact-sheet.png")) |>
  tar_target(format = "file")
```

The reader sees where the effect happens, and `sheet_contact()` can be called in
the console without producing a file.

## 4. Files are `format = "file"` — outputs *and* inputs

```r
write_plot <- function(path, data) {
  ggsave(path, plot_it(data))
  path        # the return value is what targets tracks
}
```

**External inputs a pipeline draws with** — a font, a template, a shapefile, a
reference image — belong in `format = "file"` targets too, so targets hashes them
and a change upstream rebuilds what used them.

Recording an input's md5 in a *separate* target proves nothing if nothing depends
on that target: it will happily rebuild alone while every artefact it describes
stays stale. This is easy to get wrong and easy to check:

```r
tar_network(targets_only = FALSE)$edges   # does anything depend on it?
```

Then test it for real — touch the file and confirm `tar_outdated()` names the
artefacts, not just the input.

**A file path assigned in `R/` is the trap.** It looks like the harmless constant
of rule 1, and it *is* tracked — as a string. Nothing watches the bytes:

```r
# WRONG — one value declared twice, and only the string is tracked
# R/design.R
ORIGINAL_HEX <- "reference/greta-hex-original.png"
# _targets.R
original_hex  <- ORIGINAL_HEX |> tar_file()             # hashes the file...
contact_sheet <- sheet_contact(stickers) |> tar_file()  # ...but reads the global

# RIGHT — declared once, as the target's own command, and passed in
original_hex  <- "reference/greta-hex-original.png" |> tar_file()
contact_sheet <- sheet_contact(stickers, original_hex) |> tar_file()
```

The wrong version builds green forever. Replace the png and `tar_outdated()`
names `original_hex` **and nothing else** — the sheets are pinned to the path,
which did not change, so they keep a stale image while `tar_make()` reports
success. Measured on this exact bug: 1 target outdated before the fix, 5 after.

Two habits fall out of it:

- **Put the literal in the target, not in `R/`.** One declaration. A path in `R/`
  plus a `tar_file()` in the pipeline is a shadow copy — and when the two names
  differ only by case (`ORIGINAL_HEX` / `original_hex`), reviewers will read the
  pair as one thing and never see the gap.
- **Functions take the path as an argument.** `sheet_contact(stickers,
  original_hex)`, never `sheet_contact(stickers)` reaching for a global. Passing
  it buys the dependency *edge*, not the path: the value is identical either way,
  which is exactly why the fix looks like a no-op and gets waved through.

Three more things that bite:

- **Never let two file targets write the same path.** targets cannot see the
  conflict; the filesystem resolves it by whichever ran last. If two targets need
  the same file, make one a *slice* of the other.
- **Names do not survive a `format = "file"` target.** targets stores the paths
  and hands back a bare character vector, so a downstream function cannot rely
  on `names()`. Give each file a name that identifies what it holds and recover
  it from the filename — identity carried by the artefact cannot drift.
- **Make written artefacts byte-reproducible if they are committed.** Some writers
  stamp a timestamp into the file — `magick` does it to PNGs — so every rebuild
  produces the same pixels at the same byte count with different bytes, and the
  committed output churns in git until a real change is impossible to spot.
  `image_strip()` before `image_write()`; check by building twice and diffing.

## 5. Session side effects go in a scoped `tar_hook_before()`

A bare `register_fonts()` at the top of the pipeline script does work locally —
`tar_make()` sources the script in the process that runs the targets — but it is
untracked, it is an outlier in a file that is otherwise a map of the analysis, and
it silently stops working under `crew`, because workers do not source
`_targets.R`.

| where | when |
|---|---|
| `tar_hook_before()` | the default. Injects the call into the commands you name |
| project `.Rprofile` | config that must exist before anything else — `conflicted`, `box`, `reticulate`. The manual (ch. 7) asks for it, and `crew` workers do run `.Rprofile` ([discussion #1515](https://github.com/ropensci/targets/discussions/1515)) |
| top of the pipeline script | a stopgap. Untracked and worker-invisible |

`tar_hook_before()` was built for this — [tarchetypes#44](https://github.com/ropensci/tarchetypes/issues/44)
names "custom prework, e.g. `conflicted` setup" as the motivating case:

```r
tar_assign({
  font_files <- hex_font_files() |> tar_file()
  ink_table  <- measure_ink(labels, weights) |> tar_target()
  stickers   <- draw_all(ink_table) |> tar_file()
  icons      <- draw_icons() |> tar_file()   # no type
}) |>
  tar_hook_before(
    hook = register_fonts(font_files),
    names = c(ink_table, stickers)
  )
```

**Pipe the list in; do not nest.** `targets` is `tar_hook_before()`'s first
formal, so `tar_assign({...}) |> tar_hook_before(...)` fills it and the script
reads in the order things happen: build the targets, then hook them. Nested the
other way, `tar_hook_before(` opens the file and the hook sits a hundred-odd
lines below the targets it modifies, so the pipeline has to be read inside-out.
This is rule 2 again, one level up.

Both forms are valid — `?tar_hook_before` documents `targets` as "a list of
target definition objects… arbitrarily nested", which is what `tar_assign()`
returns, and that help page's own example binds the list to a name first and then
hooks it rather than nesting. They are also equivalent: converting one to the
other leaves `tar_manifest()` identical and rebuilds nothing, which is how to
confirm you changed only the reading order.

- **Name the targets that need it, not `everything()`.** The hook is injected into
  each command, so an unscoped hook puts setup into targets that never use it and
  rebuilds all of them when it changes. Trace which code paths actually need it.
- **Pass the resource in, and `set_deps` tracks it.** `register_fonts(font_files)`
  makes `font_files` a dependency of every hooked target, so the hook does double
  duty: it runs the side effect *and* wires up the invalidation from rule 4.

`conflicted` is the one case that usually belongs in `.Rprofile` instead, because
it has to be configured before anything else attaches. In `packages.R` it does
work locally — verify rather than believe, it is a two-minute test: put an
ambiguous call in a target and check `tar_make()` errors on it.

## 6. Validation is a target that fails

```r
tar_assign({
  checks <- stop_if_invalid(results) |> tar_target(deployment = "main")
  report <- tar_quarto(path = "report.qmd")   # depends on checks
})
```

A check that returns a warning is a check nobody reads. Make it `stop()`, and
make whatever it guards depend on it, so a broken result cannot reach a
deliverable.

`deployment = "main"` because **`message()` from a worker does not reach the
console.** A check that reports its result goes silent the moment you add a
controller, which looks like it stopped running. These targets are near-instant,
so there is nothing to gain by sending them out.

Validation targets are also where sort-order assumptions hide. A check reading
`report$reach[1]` for "the worst case" depends on ordering done in a *different*
function, and breaks silently the moment the report is stitched together from
branches. Sort where you rely on it.

## 7. Cache data as targets, not in closures

A `local({ cache <- list(); function(x) ... })` memoiser dies with the session
and recomputes on every `tar_make()`. If the cached thing is a *value*, make it
a target: it persists between runs and `tar_read()` shows it.

Nor is a closure the right way to make a repeated side effect cheap. **Ask the
subsystem what state it has, instead of keeping a private ledger of what you
think you did:**

```r
register_fonts <- function(files) {
  if (all(families(files) %in% registry_fonts()$family)) return(invisible(files))
  ...
}
```

A `local({ done <- FALSE })` flag is a second copy of state that already exists
somewhere authoritative, and it goes wrong in the usual way — it says "done" when
something else has since cleared the registry. The real check is normally cheap
enough to stop mattering (measured: 0.1 ms against 126 ms), so measure before
inventing a cache.

## 8. `library()` in `packages.R`, not `tar_option_set(packages = )`

**Do not use `tar_option_set(packages = )`. Put every attachment in
`packages.R` and `source()` it.**

The manual (ch. 7, *Packages*) permits both and names exactly one advantage for
the option — utilities like `tar_visnetwork()` avoid loading packages they do not
need, so they start faster. It does not call the option better, and it is *not*
about correctness: `packages = c("dplyr")` simply makes targets call
`library(dplyr)` before running each target. A second or two on
`tar_outdated()` is not worth what the split costs.

**What the split actually costs, measured.** Once `conflicted` preferences live
in `packages.R`, any context that does not source it gets *different function
masking*. A project moved its packages out of `tar_option_set()` into
`packages.R` and added `conflicts_prefer(dplyr::filter)`. The pipeline built
green. The test suite went from 262 passing to **38 failures**, because
`tests/testthat/helper-*.R` sourced `R/` but not `packages.R`, so a bare
`filter()` in `R/` resolved to `dplyr::filter` under `tar_make()` and to
`stats::filter` under testthat. The error was `object 'active' not found` — base
R's time-series filter reading a column name as a coefficient.

Two rules follow:

- **One list, one file.** Never maintain package attachments in two places.
- **Every entry point sources it.** The pipeline scripts, the test helper, and
  any report that loads `R/` on its own account. A test helper that loads code
  differently from the pipeline is a test suite measuring a different program.

```r
# packages.R
library(targets)
library(tarchetypes)
library(conflicted)   # make function masking an error, not a surprise

library(dplyr)
library(ggplot2)
library(mgcv)

# last line: declared winners, so nothing can attach the packages without them
source("conflicts.R")
```

### `packages.R` sources `conflicts.R`, on its last line

**Not the pipeline script.** `conflicts.R` holds `conflict_prefer()` calls, which
do nothing until something runs them — and a preference that never runs is worse
than none, because the file's existence implies the decision is in force.

Sourcing it from `packages.R` makes the two travel together: every pipeline
script, test helper and report already sources `packages.R`, so none of them can
load the packages without the preferences. Leave it to the callers and you have
as many places to keep in step as there are entry points, each building fine
while resolving a bare verb differently.

The failure is silent by construction, so check rather than assume:

```r
grep -rn 'source("conflicts.R")' .   # exactly one hit, in packages.R
```

One project carried a `conflicts.R` that **nothing had ever sourced**. It was
empty, so nothing broke — until a package was attached that clashed, a
`conflict_prefer()` was added, and the call still errored. The comment at the top
of `packages.R` had claimed "sourced after this file" for the project's whole
life and had never been true.

An empty `conflicts.R` is a normal result. Keep the file, keep it sourced, and
say in it what belongs there — so the first real conflict has a home that works.

Reach for `packages =` when the metadata utilities are genuinely slow (a big
pipeline, heavy packages, `tar_outdated()` in a watch loop), or when you are
setting `imports =` as well and want the two lists together.

- **Workers still get these.** `packages` defaults to a snapshot of `.packages()`,
  which is whatever `packages.R` attached — so plain `library()` calls survive the
  move to `crew` untouched. Order is the snapshot's, so if masking matters, list
  them explicitly ([discussion #1515](https://github.com/ropensci/targets/discussions/1515)).
- **Do not maintain the same list twice.** A `packages =` vector alongside
  `library()` calls is two copies that drift — and once they have, the comment
  claiming one is derived from the other is the last thing anyone checks. Naming
  the vector once and feeding it to both `lapply(library, ...)` and `packages =`
  looks like the fix and is worse: a character vector of package names is
  invisible to `renv::dependencies()` and every other static scanner.
- **`packages =` does not track package versions.** That is `imports =`, which
  makes targets walk a package's environment so an upgrade invalidates whatever
  used it. Useful when developing a package alongside its pipeline; for everything
  else the manual points at renv.

## 9. A target that gets recomputed downstream is a lying graph

If a value is worth caching as a target, downstream functions should **take it as
an argument**, not re-derive it from the same raw inputs.

```r
# WRONG — the graph shows siblings, the code has a parent
panels_constrained <- panel_constraints(panels, lookup, params) |> tar_target()
profile            <- section_profile(panels, params, lookup) |> tar_target()
grid               <- grid_constraints(panels, params, lookup) |> tar_target()
# ...because section_profile() and grid_constraints() each call
#    panel_constraints() internally, on the same raw panels.

# RIGHT — the edge is real
panels_constrained <- panel_constraints(panels, lookup, params) |> tar_target()
profile            <- section_profile(panels_constrained, params) |> tar_target()
grid               <- grid_constraints(panels_constrained, params) |> tar_target()
```

Measured on one pipeline: `panel_constraints()` ran **8 times** for a branch that
cached it once, because two surface functions called it internally and a
sensitivity target called one of them four times. The cached target was consumed
by nothing except a summary and the report.

The cost is rarely compute — it was 15 ms there. The cost is that
**`tar_visnetwork()` stops describing the analysis.** On a project whose selling
point is visible, checkable calculation, the graph is a deliverable, and a graph
showing three siblings where the code has a parent and two children is simply
wrong. It also means editing the upstream function invalidates the cached target
and the three that "do not depend on it", so the invalidation looks mysterious.

**How to spot it:** for each target, ask what its command actually recomputes.

```r
tar_manifest(fields = "command")   # who calls what
tar_network(targets_only = TRUE)$edges   # what depends on what
```

If a function name appears in more than one command, or a target has no
dependents, look closer.

**When it is fine:** a genuinely cheap pure helper (`default_params()`) called in
several commands is not worth a target. The rule bites when the recomputed thing
*is already* a target.

## 10. One project per deliverable

When a repo has several outputs that should not be able to break each other,
give each its own project and its own store:

```yaml
# _targets.yaml
main:            # what a bare tar_make() builds; alias the one in active work
  script: pipelines/constraints.R
  store: _targets/constraints

constraints:
  script: pipelines/constraints.R
  store: _targets/constraints

fos:
  script: pipelines/fos.R
  store: _targets/fos
```

```r
Sys.setenv(TAR_PROJECT = "fos"); targets::tar_make()
targets::tar_config_projects()
```

Separate stores are the point: a broken input to one pipeline cannot invalidate
or take down another. Say in a comment which project `main` aliases and why.

## Debugging a failed target: workspaces first

The debugging loop is not print-statements-and-rerun — the pipeline runs in a
separate process, so that loop does not even work. Every errored target saves a
**workspace** — the default since targets 1.8.0, no option needed. Load it,
reproduce interactively, fix the function in `R/`, `tar_make()`:

```r
tar_workspaces()                           # which targets left workspaces
tar_workspace(analysis_9f60c6e05a6c5414)   # deps, functions and seed, loaded
analyze_data(data)                         # reproduce it in your session
tar_traceback(analysis_9f60c6e05a6c5414)   # the saved traceback
```

Under dynamic branching this is the only sane route — the workspace names the
one failed branch of a hundred and loads that branch's inputs. It also survives
`crew`, which the browser-based routes do not.

Read **`references/debugging.md`** for the full workflow: workspaces for
targets that *succeed* but look wrong, the `debug` option for a live browser
inside one target, `browser()`, and why `callr_function = NULL` is
debugging-only.

## Going parallel with `crew`

Only worth doing when a serial build is genuinely too slow. When it is, read
**`references/crew.md`** — how to sweep `workers` rather than guess it, why total
CPU time goes up while wall clock goes down, which target is worth branching, and
the byte-identical check.

The one thing to know without reading it: adding a controller is a good stress
test, because workers do not source `_targets.R`. Rules 5 and 8 are what make the
move uneventful.

## Reviewing an existing pipeline

Read the pipeline script and ask, in order:

1. What is assigned outside `tar_assign()`/`tar_plan()`/`list()`? Each one is a
   bug or a documented exception. Include the quiet ones: list every
   `SCREAMING_CASE` constant in `R/` with
   `tar_network(targets_only = FALSE)$vertices |> subset(type == "object")`, and
   for each ask whether anyone would want to vary it (rule 1).
2. Is every target named in the script, or does a function in `R/` return a list
   of targets? `grep -l "tar_target\|tar_file\|tar_assign" R/` should find
   nothing (rule 2).
3. Is there a side effect at the top of the script that should be a hook?
4. Do any two file targets write the same path?
5. Are external inputs (fonts, templates, reference data) `format = "file"`
   targets; is the path literal declared *in the target* rather than as a
   constant in `R/`; and does anything actually *depend* on them?
6. Does anything rely on branch *position* (`map(a, b)`), on names surviving a
   `format = "file"` target, or on sort order set in another function?
7. Are any target bodies more than one call?
8. Is anything in `R/` unreachable from the pipeline?
9. Does any target's command recompute something that is already a target?
   (Rule 9. `tar_manifest(fields = "command")` — a function name appearing in two
   commands, or a target with no dependents.)
10. Are packages declared in exactly one place; does `packages.R` source
    `conflicts.R` on its last line (`grep -rn 'source("conflicts.R")' .`); and
    does every entry point — pipelines, test helpers, reports — source
    `packages.R`? (Rule 8.)

Then run the structural checklist in `r-project-conventions`, and for the design
of the functions the pipeline calls, `r-function-design`.

Mechanical checks worth running:

```r
targets::tar_manifest(fields = "command")        # spot oversized bodies
targets::tar_network(targets_only = FALSE)$edges # what really depends on what
targets::tar_outdated()                          # what would rebuild
targets::tar_visnetwork()                        # orphans and shape
```

## Useful commands

```r
tar_make()             # build
tar_visnetwork()       # the graph, with staleness
tar_manifest()         # targets as a table
tar_read(name)         # a target's value
tar_meta(name)         # hashes, timings, warnings
tar_load_everything()  # for interactive debugging
tar_outdated()         # what would rebuild
tar_config_projects()  # multi-project repos
```
