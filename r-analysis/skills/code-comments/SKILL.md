---
name: code-comments
description: Write fewer, better code comments — the three-stage test for whether a comment earns its place, and an audit pass for comments already written. Use when writing or editing code in any language, when reviewing a diff before committing, or when asked to "check the comments", "audit these comments", "this is over-commented", or "explain why not what".
---

# Writing comments

Sits alongside `r-function-design` (function internals) and
`r-project-conventions` (project envelope). This one is about the prose inside
the code.

The default failure is not writing *wrong* comments. It is writing *too many
correct-sounding ones*, fused into blocks, narrating the change rather than the
code. All three of those are caught below; "explain why, not what" alone catches
none of them.

## The three stages

Every candidate comment passes through all three, in order. Most die at stage 1.

### Stage 1 — try to delete it

Before writing a comment, try to make it unnecessary:

1. **Rename.** A better variable or function name beats a comment explaining a
   worse one.

```r
# before
# Number of days since the last observation
d <- as.numeric(today - last_seen)

# after
days_since_seen <- as.numeric(today - last_seen)
```

2. **Extract a helper.** A named predicate beats a comment describing a
   condition.

```r
# before
# Check x is a non-empty string
if (!is.na(x) && nzchar(x)) {

# after
if (is_non_empty_string(x)) {
```

3. **Introduce an explaining variable.** Assign the confusing subexpression to a
   named one and let the name do the talking.

```r
# before
# TRUE once warmup is done and we are still inside the current burst
if (i > warmup && i - burst_start < burst_length) {

# after
in_sampling_burst <- i > warmup && i - burst_start < burst_length
if (in_sampling_burst) {
```

A comment you cannot delete this way has earned a look at stage 2. A comment you
*can* delete this way is a bug report about the code.

> Write the code as if comments did not exist. Only when you cannot imagine any
> way to make it clearer should you reach for one.

### Stage 2 — reader parity

The survivors face one question:

> **What did I know while writing this that the code cannot say?**

Two piles of knowledge are in play:

1. Everything you knew while writing the code: the approach you tried and
   abandoned, what the benchmark measured, the upstream bug that forced your
   hand.
2. What the code transmits on its own, to anyone who reads it.

The second pile is always smaller. **The gap is what is left over** — the things
you knew that the syntax has no way to carry. A comment exists to ferry exactly
that across, and nothing else.

Answering **"what did I know that the code cannot say?"** points one of two
ways, which is why this is the central test and stage 3 is not:

- **Something is in the gap** — you hold a load-bearing fact the code cannot
  state: an upstream bug, a measured benchmark, a rejected alternative, a
  statistical argument. Write it down. Too few comments is a failure too.
- **The gap is empty** — you are about to restate what is already on screen.
  Cut it.

The same line of code, treated three ways:

```r
# nothing written down, so the reader is left wondering why not solve()
K_inv <- chol2inv(chol(K))

# gap empty: the comment says what the line already says
# Use chol2inv() rather than solve()
K_inv <- chol2inv(chol(K))

# gap filled: a rejected alternative and a measured cost
# solve() hits a singular K on roughly two thirds of fits once warmup
# passes ~50 iterations. The Cholesky route is stable, and ~3% slower.
K_inv <- chol2inv(chol(K))
```

Only the third tells the reader something they could not have worked out. Note
that the first is a failure too — stage 2 caught a *missing* comment, not a
surplus one.

This is the only one of the three stages that can tell you a comment is
*missing*. Stage 1 and stage 3 only ever push toward fewer, or toward better
phrasing of one you have already decided to keep.

### Stage 3 — why, not what

Now phrase what is left. State the reason, not the mechanics.

```r
# before: restates the mechanics
# Recurse only with bare lists
x <- map_if(x, is_bare_list, recurse)

# after: states the intent
# Objects like data frames are treated as leaves
x <- map_if(x, is_bare_list, recurse)
```

The same move on a greta line:

```r
# before: names the call
# Convert the Keras iteration counter with numpy()
self$it <- as.numeric(tfe$tf_optimiser$iterations$numpy()) + 1

# after: says why the call is there at all
# Keras 3's `iterations` is a keras.Variable, which reticulate surfaces as a
# Python object rather than converting it.
self$it <- as.numeric(tfe$tf_optimiser$iterations$numpy()) + 1
```

Note where this rule sits: it governs *phrasing*, not *existence*. By the time
you apply it the comment is already justified, so it can never be the whole
test.

**State the consequence, not just the cause.** A fact with no "so" attached
leaves the reader holding a true statement and no idea what it licenses. This is
the easiest way to over-apply stage 3: the clause that connects the fact to the
line looks like it restates the code, and cutting it strands the fact.

```r
# before: true, but the reader has to guess what it licenses
# `iterations` is a keras.Variable, which reticulate leaves as a Python object.
self$it <- as.numeric(tfe$tf_optimiser$iterations$numpy()) + 1

# after: the fact, and what it makes this line do
# It is a keras.Variable, which reticulate leaves as a Python object, so read
# it through $numpy().
self$it <- as.numeric(tfe$tf_optimiser$iterations$numpy()) + 1
```

## Facts about the world, not facts about the change

**The single most common failure.** A comment written during a change tends to
address the reviewer of that change, this week — not the reader of the code, in
a year.

| Cut — facts about the change | Keep — facts about the world |
|---|---|
| "This is what `minimize()` used to do" | "Keras 3 removed `Optimizer$minimize()`" |
| "As before, the objective is re-evaluated after" | "TFP imports `tf_keras` unconditionally" |
| "Now we build the slots first" | "A `tf_function` may not create variables on a retrace" |
| "Changed to use `chol2inv()`" | "`solve()` goes singular on this matrix after warmup" |

The test is **reader-dependence**: does making sense of this comment require
having seen the previous version of the code? It is *not* "does it mention the
past" — a comment can record history and still be a fact about the world.

```r
# diff-narration: means nothing to a reader who never saw the old version
# As before, the objective is re-evaluated after the step.

# a fact about the world: lands for a reader who never saw the 3.125
# This used to be a hardcoded 3.125 that any layout change would silently
# invalidate.
```

The second records *the failure that motivated the design*, which is the "why
the obvious code was not written" category, and it keeps a future reader from
reintroducing the bug. The first is addressed to whoever reviewed one diff.

Words worth a second look — *as before*, *now*, *previously*, *used to*,
*changed to*, *no longer* — are a prompt to apply the test, not a verdict.

That content is not worthless — it belongs in the commit message, the PR
description, or `NEWS.md`. Just not in the source.

## One reason, one place

**One comment = one reason = one location.**

If you have three reasons, write three comments, each sitting against the line
it explains. Do not fuse them into a preamble. A block of prose at the top of a
function body is a wall the reader skips, which forfeits the whole point:
comments work as *flags*, and flags only work when they are rare and local.

A multi-paragraph preamble is a smell. Either the reasons belong further down
against their own lines, or the function is doing too much — see
`r-function-design`.

Proximity also governs decay. The further a comment sits from what it describes,
the sooner someone edits the code without seeing it, and the comment turns from
helpful to actively misleading.

## What earns a comment

Short list. Be suspicious of anything outside it.

- **A design decision** — why the obvious code was *not* written. The single
  most valuable category.
- **A workaround** — an upstream bug or version quirk. Link the issue.
- **A measured fact** — a benchmark, a failure rate, a numerical result. Say the
  number, and link where the measurement lives — a public issue, not a private
  note. A number with no route back to its evidence cannot be rechecked when
  someone doubts it, and it will be doubted.
- **Numerical stability or statistical correctness** — reasoning that is
  invisible in the arithmetic.
- **Why this cannot be improved** — a limit someone will otherwise waste a day
  trying to fix. "No four hues stay hue-distinct under red-green deficiency;
  that is the best any four-colour set can do, not a property of this one."
- **A genuinely complex algorithm** — rare. Genuinely rare.
- **`TODO` / `FIXME`** — explicit exceptions, not a habit.

## What never earns a comment

- Restating the code.
- Change logs, author names, dates, "modified by". Git owns this.
- Commented-out code. Git owns this too — delete it.
- Trailing comments on the same line as code. Put them on the line above.
- Section banners of `#####` or ASCII art.

## R and greta specifics

### The roxygen boundary

Exported, user-facing behaviour goes in roxygen — always, and it always earns
its place. Internal functions get no roxygen (project rule), so knowledge about
them goes in a comment at the top of the function, held to the same three
stages. Use `@noRd` only when you want roxygen's structure without a `.Rd` file.

Do not explain in a comment what the roxygen already says. Pick one home.

### The TF/Python boundary

The one place in greta where longer comments are routinely earned. Anything
true on the Python side and invisible from the R side is a genuine parity gap:

- reticulate conversion behaviour (what comes back as a Python object rather
  than an R one, and why `$numpy()` is needed)
- 0- vs 1-based indexing
- TF/TFP version constraints and what breaks without them
- tracing and retracing behaviour of `tf_function`
- which Keras API surface is in play

These still get one reason per comment, placed against the line.

### Tests

Keep them minimal. The `test_that()` description carries the intent — if you
want a comment explaining what the test checks, put it in the description
instead. Comment only for:

- a non-obvious fixture (why *these* numbers, why this seed)
- the origin of a regression test (link the issue)

### Section markers

`# ---- section ----` markers are navigation, not explanation. They sit outside
the three stages and are not audited as comments. But needing many of them in
one file is a size signal: consider splitting the file.

### Mechanics

Follow the tidyverse style guide: one space after `#`, sentence case, and a full
stop only when the comment runs to two or more sentences.

## The audit pass

When asked to check the comments in a diff, or before committing a change with
substantial new comments, run every comment through this and act:

| Verdict | When |
|---|---|
| **refactor away** | A rename, helper, or explaining variable removes the need |
| **cut** | Restates the code, or narrates the change rather than the world |
| **move** | Correct, but sitting away from the line it explains |
| **split** | One block carrying two or more reasons |
| **substantiate** | Asserts a measured fact — go and check it |
| **keep** | A real parity gap, one reason, well placed |

Report only what changed and why, in one line each. Do not list the keeps.

### Run it as a procedure, not a rubric

The table above is the easy half. Reading a codebase and *noticing* bad comments
is a sweep: it finds whatever pattern you fixed on first, in whatever file you
were sharpest, and it cannot tell you what it missed. Judged-and-kept and
never-looked-at produce identical output. Work the four passes in order.

**Pass 1 — enumerate before judging.** Extract every comment block to a worklist
keyed `file:line` *first*, then assign exactly one verdict per row. Do not judge
while reading. Completeness is then arithmetic — rows in equals verdicts out —
and "did you audit this file?" has an answer that is not recollection.

**Pass 2 — regroup by claim, across files.** *One reason, one place* is the only
rule with no per-file anchor: a reason stated in two files is invisible to any
file-by-file reading. Sort the worklist by the claim each block makes rather
than by where it lives, and look for the same reason twice. A pipeline or
config file is the usual offender — it re-narrates what the functions it calls
already explain at their own definitions. Keep the copy that sits with the
implementation.

**Pass 3 — substantiate, with three outcomes.** Never two. Each numeric or
causal claim ends as **verified**, **corrected**, or **could not verify —
flagged to the user**. Silence is not an outcome, and "too expensive to check"
resolves to *flagged*, never to *fine*. Before reaching for a measurement, read
the claim adversarially and against itself: a comment whose own figures
contradict its conclusion is caught by arithmetic alone. Check the *attribution*
separately from the *number* — a correct measurement welded to the wrong cause
reads as well as a right one, and is the most durable kind of wrong comment.

Scan *every* block for claims, including ones already judged **keep**. Placement
and claim-bearing are independent axes, so no category earns an exemption —
file headers, usage menus and section preambles assert version behaviour,
provenance and equivalences as readily as any line-level note, and being
well-placed is no evidence of being true. "Byte-identical to the copy upstream"
sat unchecked in a header for exactly this reason. Verdict the block for
placement; scan its sentences for claims separately.

**Pass 4 — re-derive, don't pattern-match.** Findings from the first file become
a search template for the rest, so late files get tested against an early
hypothesis instead of against the three stages. Audit in a fixed order, and on
each file ask stage 2 fresh rather than asking "does this file have the problem
the last one had".

**Fluency is not a verdict.** Prose with real numbers, real reasons and good
sentences passes stage 3 on nearly every line — see the worked example below,
where every sentence passes and most still get cut. A well-written comment can
still be misplaced, duplicated, or measurably false. Grade the placement and the
claim, never the writing.

**Substantiate is the one verdict reading the code cannot reach.** A comment
claiming a benchmark, a failure rate, a version behaviour, or a reason for an
`if` can be confidently wrong while looking perfectly well written, and it is
usually inherited — written in an earlier session, carried forward unchecked.
Find the evidence and put the number in, or cut the claim. "Slow enough to show
up in benchmarks" was hiding a measured 1.65x.

The same applies to an inherited comment that states a *reason*: check the
reason is the real one before you keep it. "Add 1 because python indexing" had
survived years of edits, and the actual reason was that the counter reports
completed steps.

## Worked example

Eleven lines of comment over ten lines of code, from a real greta diff:

```r
# Keras 3 removed Optimizer$minimize(), so take the gradient step
# ourselves: record the objective on a tape, then apply. This is what
# minimize() did internally under Keras 2. As before, the objective is
# re-evaluated *after* the step, so the convergence check compares
# successive post-step values.
#
# The whole step is compiled with tf_function: done eagerly it costs
# four R->Python round trips per iteration where minimize() cost one,
# which is slow enough to show up in benchmarks. Build the optimiser's
# slot variables first -- a tf_function may not create variables on a
# retrace.
```

Every sentence passes "why, not what" — which is exactly why that rule is not
enough on its own. Running the pipeline instead:

- *"record the objective on a tape, then apply"* — **cut** at stage 1; the three
  lines below say it in code
- *"This is what minimize() did internally under Keras 2"* — **cut** at stage 2;
  a fact about the change
- *"As before, the objective is re-evaluated after the step"* — **cut**; same,
  and "as before" dangles for anyone who never saw the old version
- three real gaps survive, and **split** to their own lines

```r
# Keras 3 removed Optimizer$minimize(), so take the gradient step by hand.
objective <- if (self$adjust) objective_adjusted else objective_unadjusted

# A tf_function may not create variables on a retrace, so the optimiser's
# slot variables have to exist before tracing.
tfe$tf_optimiser$build(list(free_state))

# Compiled because tape/gradient/apply as separate eager calls cost four
# R->Python round trips per iteration: that version benchmarked 1.65x slower
# than Keras 2's minimize(), where this one is 2.3x faster.
step <- tensorflow::tf_function(function() {
```

Five lines instead of eleven. Three flags instead of one wall. Every survivor is
a fact about the world; every casualty was a fact about the afternoon.

## Further reading

- [Tidyverse style guide — comments](https://style.tidyverse.org/functions.html#comments-1)
  and [internal functions](https://style.tidyverse.org/documentation.html#internal-functions)
- [Code comments and self-explaining code](https://blog.r-hub.io/2023/01/26/code-comments-self-explaining-code/) — r-hub, R-specific, the "little flags" framing
- [Coding without comments](https://blog.codinghorror.com/coding-without-comments/) — Atwood
- [Code tells you how, comments tell you why](https://blog.codinghorror.com/code-tells-you-how-comments-tell-you-why/) — Atwood, the Raskin argument
- [When good comments go bad](https://blog.codinghorror.com/when-good-comments-go-bad/) — Atwood, comment decay and proximity
- [Common excuses used to comment code](https://www.codeodor.com/index.cfm/2008/6/18/Common-Excuses-Used-To-Comment-Code-and-What-To-Do-About-Them/2293) — Larbi, the excuse-by-excuse teardown
- [Introduce an explaining variable](https://blog.thepete.net/blog/2021/06/24/explaining-variable/) — Hodgson
- *The Art of Readable Code*, Boswell and Foucher — source of the parity test
- *The Programmer's Brain*, Hermans — naming as a three-step process
