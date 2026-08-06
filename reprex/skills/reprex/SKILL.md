---
name: reprex
description: Write minimal reproducible examples for R bug reports, GitHub issues and questions. Use when drafting an issue about broken R code, writing up a bug you have found, turning an investigation into something someone else can run, or when asked for "a reprex", "a repro", "a minimal example", or "something I can file". Also use when reviewing a draft issue that buries its code.
---

# Writing a reprex

A reprex is a **minimal, self-contained example that reproduces a problem**, in
code someone else can paste and run.

## The single most important rule

**Lead with the code.** The first thing in the file, after one sentence saying
what goes wrong, is the code that makes it go wrong.

Not a summary. Not background. Not a mechanism explanation. Code.

Everything else — why it happens, what the fix is, what else was tried — comes
*after* the reader has seen the thing fail. A reader who cannot find the
reproducing code in the first ten lines will not read the rest.

## Format

One of two, never a long `.md` write-up:

**A `.R` file**, using `#' ` for prose. `reprex::reprex()` renders those lines
as markdown and everything else as code with its output. This is the default
choice.

```r
#' `mean()` returns NA for a factor, silently.

x <- factor(c(1, 2, 3))
mean(x)
```

### The `.R` file is the reprex. The `.md` is output.

**Never write `#>` output lines into the `.R` file.** The source is the thing
you run; the rendered markdown is what `reprex()` produces from it, and what you
paste into the issue.

```r
q <- c(0.5, 0.9, 0.99)
rbind(current = quantile(wrong, q), intended = quantile(right, q))
```

not

```r
q <- c(0.5, 0.9, 0.99)
rbind(current = quantile(wrong, q), intended = quantile(right, q))
#>                  50%          90%          99%
#> current  2.855142e-09 3.844886e-04 5.325986e-03
#> intended 1.142057e-04 1.537954e+01 2.130394e+02
```

`reprex()` strips leading `#>` from its input, so a hand-written one does not
break the render — it just quietly does nothing, which is worse. The real cost:

- **It goes stale, and nothing tells you.** The numbers were true when you
  pasted them. After an edit they are decoration that disagrees with reality.
- **It invites fabrication.** Writing plausible output from memory is easy and
  invisible; a hand-written failure count of `5 / 3` sat in a file whose actual
  run gave `4 / 4`.
- **It makes the file harder to read** as what it is: a script.

So the workflow is two artefacts:

```r
reprex::reprex(input = "issue.R", venue = "gh")   # -> issue_reprex.md
```

Keep and edit the `.R`. Post the `.md`. If you want the rendered version on
disk, keep it beside the source as a build product, not as the thing you edit.

Use `##` for code you are showing but not running — a proposed diff, a line from
the package source. That is genuinely part of the script and stays.

**A self-contained `.qmd`**, when the example needs figures, several sections,
or prose that would be awkward as comment lines.

Use `##` (double hash) for code you are *showing but not running* — a proposed
diff, a line from the package source. It stays visible as code without being
executed.

## Minimal and reproducible are two different jobs

Both are required. They pull in opposite directions, which is why this is hard.

**Reproducible** — the reader can run it:

- every `library()` call is there, at the top
- every object is created in the example
- no reliance on files, options, or state from your session

**Minimal** — nothing is there that is not needed:

- **start from an existing example.** The package's own `@examples`, a vignette,
  a README chunk, a test. Cut that down rather than inventing a fresh case. It
  is code the maintainer already recognises, it is already idiomatic, and if the
  bug reproduces there it is on a supported path rather than something you
  constructed. Say which one you started from
- use built-in data (`mtcars`, `iris`, `airquality`) where you can
- if you need your own data, shrink it and use `dput()` on the small version
- strip every argument, column, and line that is not required to trigger the
  problem. If removing it still reproduces the bug, remove it

A common failure is stopping once it reproduces. Keep cutting until removing
one more thing makes it stop failing.

## Still working out what the bug is?

Everything below assumes you know the cause and are writing it up. If you are
still investigating, read **`references/investigating.md`** first. It covers:

- **Exercise the package you are accusing** — confirm it is actually that
  package before you file against it.
- **Say why the thing you are removing was there** — the discipline that keeps
  minimisation honest, and the most common way a reprex ends up reporting a
  different bug from the one you hit.
- **Measure the cost where it is actually paid**, stop proposing mechanisms once
  measurement contradicts you, instrument the real thing before theorising, and
  stress test the boundary.

A reprex built on a wrong diagnosis is worse than none: it sends a maintainer
somewhere real, and wrong.

## Structure

```
one sentence: what goes wrong
where you first hit it
the code, with its output

## What I expect              - and the code showing it
## What happens instead       - and the code showing that
## Why this is a problem      - the consequence for a user
## Fix                        - the proposed change, as code
```

**Answer all three of the middle questions explicitly.** They are what a
maintainer needs and what a reporter most often leaves out:

1. **What do you expect to happen?** State the expected behaviour, and show it
   where you can — a reference implementation, the documented behaviour, the
   equivalent call in another package.
2. **What happens instead?** The observed behaviour, from a run, not from
   memory.
3. **Why is this a problem?** The consequence. Not "it is wrong" but what it
   costs someone: silently wrong numbers, a crash in a vignette, a prior nobody
   chose. A maintainer triages on this, so a bug that stops at "this is
   incorrect" is one that sits.

   **Demonstrate it, do not only describe it.** Prose about consequences is
   weaker than code showing them. Where you can, also show what the fix
   changes — run the current behaviour and the proposed behaviour side by side:

   ```r
   #' `solve()` raises, which kills the run:
   calculate(solve(K), values = list(sp2 = 1e-30))
   #> Error: Input is not invertible. [Op:MatrixInverse]

   #' `chol2inv(chol())` returns a non-finite value instead:
   calculate(chol2inv(chol(K)), values = list(sp2 = 1e-30))
   #> [1,]  NaN  NaN
   ```

   Two calls settled that better than a table of failure rates did, and they are
   deterministic where the failure rate is not. If the fix cannot be run without
   patching the package, isolate the underlying operations and compare those
   instead.

   **Then say what it does to a conclusion.** A crash is its own argument, but
   anything that returns a number needs one more step: what would someone
   *write down* on the basis of it?

   > A user fitting `pi` and reporting it as "the proportion of structural
   > zeros" is reporting the wrong quantity. A user setting `pi` to match an
   > observed zero fraction is setting it too high. Neither error is visible
   > from the output.

   That is what separates a bug that gets scheduled from one that gets
   acknowledged. Silently wrong numbers that a researcher would put in a paper
   are more urgent than an error message, and the report has to make that
   visible — the maintainer cannot infer it from a diff.

## Pick the right way to show it

Three tools, and the choice is usually obvious once you name what the problem
is. Use more than one where they say different things.

### A table, for a handful of numbers

Two rows beat two paragraphs. Put the current and intended behaviour on
adjacent rows so the comparison needs no arithmetic from the reader:

```r
rbind(current = quantile(wrong, q), intended = quantile(right, q))
#>                  50%          90%          99%
#> current  2.855142e-09 3.844886e-04 5.325986e-03
#> intended 1.142057e-04 1.537954e+01 2.130394e+02
```

Name the rows. `[1,]` and `[2,]` make the reader hold which is which.

### A plot, for a distribution or a shape

Some problems are not numbers. A wrong distribution, a wrong curve, a wrong
scale — those are seen faster than they are read. Plot the observed and the
expected **on the same axes**, not side by side, so a discrepancy is a gap
rather than something to be compared across panels.

`reprex()` uploads figures to imgur and embeds them automatically, so a plot
costs nothing to include.

Base graphics is usually right here: no dependency to install before the reader
can run your example.

### `bench::mark()`, when the problem is speed

Never `system.time()` for a comparison, and never a single run.
[`bench::mark()`](https://github.com/r-lib/bench) is the tool:

```r
bench::mark(
  current  = f_slow(x),
  proposed = f_fast(x)
)
```

Why it, specifically:

- **It checks the results are equal by default** and errors if they are not, so
  you cannot accidentally report a speedup for code that computes something
  else. That check is the reason to prefer it over `microbenchmark`.
- It reports `mem_alloc` and `gc/sec` alongside timing — often the memory
  column, not the time column, is the actual finding.
- It runs adaptively rather than a fixed number of times, and uses nanosecond
  timers.
- `relative = TRUE` gives multiples rather than absolute times, which travel
  better across machines than "1.3 seconds on my laptop".
- `ggplot2::autoplot()` on the result gives a distribution plot, which shows a
  bimodal timing that a median would hide.

Report the table. Do not paraphrase it as "about twice as fast".

Question 3 is the one most often skipped, and the one that decides whether the
issue gets picked up.

## Reduce in public

Do not open with the minimal case. Open with **the real one**, as the user met
it — the vignette, the analysis, the actual variable names — and *then* narrow
it, in the reprex, saying you are narrowing it.

```r
#' Following the vignette:
#' ... full example ...

#' Now, we can make it smaller, at just:
#' ... minimal example ...
```

The reduction is evidence. It shows the bug is on a supported path and not an
artefact of your cut-down version, and it lets a maintainer recognise their own
code before being asked to follow yours. A reprex that starts minimal has thrown
that away and cannot get it back.

**Narrate it.** "Let's wrap this up into a function to make this easier to
repeat" reads better than a heading asserting structure. The reader is
debugging; write like someone debugging, not like someone filing a report.

## Show a success next to the failure

For an intermittent bug, show a run that **worked**, beside one that did not:

```r
runs <- replicate(5, try(fit(), silent = TRUE))
errored <- vapply(runs, function(x) inherits(x, "try-error"), logical(1))

cat(runs[errored][[1]])            # a failure
head(runs[!errored][[1]][[1]])     # and a success
```

It proves the thing is intermittent rather than simply broken, and that the
successful runs give sane output — so the report is about reliability, not
correctness. Both are useful; conflating them is not.

**Keep the raw object before summarising.** `table(...)` on the results throws
away the error text you need. Assign, look, *then* summarise.

## Include the workaround

If there is one, say so, with its cost. A reader hitting this today needs it,
even if it is not the fix — and even if you have measured that it does not
really solve the problem.

## Do not borrow jargon from another language

The reader is an R user. Words carried over from Python, C++ or numerical
linear algebra read as precision to the writer and as noise to them.

The worst offenders are the ones that look like plain English:

- **"raises"** — Python for "throws an error and stops". In R that is `stop()`.
  Write "throws an error", and name it:
  `InvalidArgumentError: Input is not invertible`.
- **"singular"**, **"ill-conditioned"**, **"underflow"** — say what they mean at
  first use, in one clause. "Near-singular — its columns are nearly dependent,
  so it has no well-behaved inverse and `K^-1` blows up."

The test: read the sentence as someone who knows R well and TensorFlow not at
all. If a word only makes sense from the other side of the boundary, define it or
replace it.

This matters more in a bug report than in prose, because the maintainer has to
*act* on it. A term they have to look up is a term they may quietly skip, and
the sentence you needed them to understand is usually the one carrying the
jargon.

Where the distinction itself is the point, make it a table rather than a
sentence:

| | what you get back |
| --- | --- |
| returns non-finite | a value — `NaN` or `Inf` — that code can inspect and react to |
| throws an error | no value at all; execution halts |

## Show the fix against the broken result

Run the proposed fix and put it **beside** the current behaviour, in the same
table and **on the same plot**. Not "this should fix it" — the fixed output,
next to the broken output, next to the reference if there is one.

```r
lines(x, current, col = "red",   lty = 2)   # broken
lines(x, fixed,   col = "green", lty = 3)   # proposed fix
lines(x, mgcv,    col = "purple")           # reference
```

Three lines on one plot, three numbers in one row. That is what makes the issue
closeable: a maintainer can see the fix works without rebuilding your setup.

**Do this before you write the recommendation, because it may not go the way you
expect.** A fix that is obviously correct in the abstract can make the visible
output worse:

> `jagam`'s prior shrinks the smooth almost to a straight line at n = 40 — RMSE
> 2.63 against `mgcv`, *worse* than the broken prior's 1.05. Correcting the rate
> moves the fit further from `mgcv`, not closer.

That result did not weaken the issue, it changed it: from "your fits are wrong"
to "your prior is not the one you document", and from a one-character change to
a decision with three options. Both are more useful and more honest than the
version written before the fix was run.

If the fix cannot be run at all without patching, say so, and fall back to
comparing the underlying operations.

## Sketch the test that would catch it

After the fix, outline a test that fails before it and passes after. Not a full
implementation — a few lines and the assertion, under a `## A test for this`
heading.

```r
## test_that("the default sp prior matches jagam's", {
##   sp <- eval(formals(...))
##   expect_equal(mean(calculate(sp, nsim = 1e5, seed = 1)[[1]]), 10,
##                tolerance = 0.05)
## })
```

Why it earns its place:

- It forces you to say what "fixed" means in checkable terms. If you cannot
  write the assertion, the report is vaguer than it felt.
- It is the part a maintainer would otherwise have to invent, and it is the
  part you are best placed to write, having just characterised the bug.
- It turns the issue into something closeable. "Fixed" becomes "this test
  passes" rather than a judgement call.

Assert the **behaviour**, not the implementation. A test that greps the source
for `chol2inv` passes for the wrong reason and breaks on any refactor; a test
that the model runs without error survives both.

Where the failure is stochastic, say what the test should tolerate — a fixed
number of repeats, or a bound, rather than an exact count.

## Say where you found it

Name the vignette, test, script or analysis that surfaced it, in one line near
the top. If the reprex is a cut-down version of something bigger, say so.

This tells a maintainer whether it is a user-facing break or an internal review
finding, and it stops a secondary bug found along the way from being read as
the cause of the primary one.

## Do not include

- **Session info, R version, package versions, OS.** `reprex()` can add these
  with `session_info = TRUE`; do not. They are noise in the issue and go stale.
  If a version genuinely matters, say so in one line of prose.
- **A "Summary" heading before the code.** This is the most common way a reprex
  turns into a report.
- **Your real data**, or your real variable names, when a toy example does the
  same job.
- **`suppressPackageStartupMessages()`.** Write plain `library()` calls. The
  startup messages are part of what the reader sees when they run it, masking
  conflicts can matter to the bug, and hiding them makes the reprex differ from
  the reader's session for no gain.

## Always set a seed

Anything random gets a `set.seed()`, at the top, so the reader gets the same
numbers you did. Simulated data, random subsets, jitter — all of it.

Write the seed as **the date you wrote the reprex**, in `YYYY-MM-DD` form:

```r
set.seed(2026-07-29)
```

R evaluates that as subtraction, so it is `set.seed(1990)` — a perfectly good
seed, arrived at without stopping to invent a number, and it dates the example
for anyone reading it later. Do not quote it: `set.seed("2026-07-29")` is an
error.

Two things to know. Dates collide, since `2026-08-28` also gives 1990, so the
seed is a mnemonic rather than a recoverable date stamp. And the arithmetic is
not obvious to every reader, so if the exact seed matters to the bug, use a
plain integer and say why.

Then check what the seed actually controls, and say so when it does not control
everything. A seed on `set.seed()` fixes R's RNG; it does not necessarily fix a
sampler running in another language or another process. For example greta's
`mcmc()` takes no seed argument and does not respect `set.seed()` (greta #285,
#427), so seeding the data generation still leaves the sampling outcome varying
run to run.

Where a seed cannot make the result deterministic, say that in one line rather
than letting the reader assume the numbers are fixed. Silent non-determinism is
what makes a reader run it once, see it pass, and close the issue.

## Intermittent problems

If the bug only fires sometimes, the reprex still has to make it visible.
Replicate and tabulate, rather than asking the reader to run it repeatedly:

```r
table(replicate(5, inherits(try(fit(), silent = TRUE), "try-error")))
```

**Use as few repeats as show the problem** — three to five. Each repeat costs
the reader time, and a reprex that takes minutes to run is one that does not
get run. Pick the number from the failure rate: at roughly 50%, five repeats
miss it once in 32 runs, which is fine. Say the rate in the prose.

Do not paste the counts into the source as `#>` comments. `reprex()` generates
the output; a hardcoded count is one more thing that can be wrong, and it will
be, because the whole point is that the result varies.

## Making one usually solves it

From Nick's [how to get good with R](https://www.njtierney.com/posts/2023-10-30-how-to-get-good-with-r/#learn-how-to-create-a-reproducible-example-a-reprex-and-use-it-a-lot):

> in the process of reducing the problem down to its core components, I often
> can solve the problem myself

Treat the reduction as the debugging technique, not as paperwork after the
debugging. Roughly 80% of the time, building a good reprex finds the cause.

## Checking it

`reprex::reprex()` runs the code in a **fresh R session** via
`rmarkdown::render()`, so anything you were relying on from your environment
fails immediately and visibly. That is the point of it, not a side effect.

```r
reprex::reprex(input = "issue.R")           # renders, copies to clipboard
reprex::reprex(input = "issue.R", venue = "gh")   # GitHub-flavoured markdown
```

Figures are uploaded to imgur and linked automatically.

**Render it before you file it. Every time, including after small edits.** A
reprex you have not run is a draft. Reading the code and believing it will work
is exactly how a broken one gets posted, because the parts were run separately
in a session that had state the reader will not have.

### Then check the errors are where you expect

Rendering is not enough — read the rendered output and account for **every**
error and warning in it. For each one, ask: is this the bug I am reporting, or
something else?

An unexpected error is one of four things, and they need different responses:

- **The bug.** Good — that is the point.
- **A different bug, intruding.** Worth knowing, and often worth saying: a prior
  draw failing on an unrelated `MatrixInverse` error inside a reprex about a
  *prior* is evidence the two issues interact, and an argument for fixing them
  in order.
- **A mistake in the reprex.** A missing object, a package not installed, a
  function that does not exist. Fix it. This is the common case and it is
  invisible until you render.
- **Something that worked in your session and not in a clean one.** State-
  dependence you did not notice — an object left over, a package attached
  earlier, a patched function still loaded.

Watch particularly for **code that only worked because you got lucky**. A line
that succeeded once, on one seed, in one session, will fail for the reader about
as often as it failed for you. If a step is stochastic, make it retry and say
why, rather than pinning the value that happened to work:

```r
draw_prior <- function(tries = 8) {
  for (s in seq_len(tries)) {
    b <- try(calculate(x, nsim = 2000, seed = s), silent = TRUE)
    if (!inherits(b, "try-error")) return(b)
  }
  stop("could not draw from the prior in ", tries, " attempts")
}
```

Also check the first code block fails in the way the first sentence claims, and
that no output block is empty where you expected numbers.

## Further reading

- [reprex package](https://github.com/tidyverse/reprex) — Jenny Bryan
- [The magic of reprex](https://www.njtierney.com/posts/2019-01-11-magic-reprex/)
- [R4DS, Workflow: getting help](https://r4ds.hadley.nz/workflow-help.html)
- [Posit Community: minimal reproducible example FAQ](https://forum.posit.co/t/faq-how-to-do-a-minimal-reproducible-example-reprex-for-beginners/23061)
- [RRRRR, I'm stuck! — minimal reproducible data](https://carpentries-incubator.github.io/R-help-reprexes/instructor/4-minimal-reproducible-data.html)
