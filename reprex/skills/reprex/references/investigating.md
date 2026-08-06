# Investigating, before you write it up

Loaded on demand from the `reprex` skill. Read this when you are still working
out **what the bug is** — before there is anything to report. If you already know
the cause and are writing it up, you do not need this file.

The sections are in the order you would actually hit them.

## Exercise the package you are accusing

Cutting can go one step too far. If the reprex ends up **reconstructing** the
behaviour instead of invoking it, it no longer demonstrates the bug — it
demonstrates something adjacent to it, and the connection back to the package
is left as an assertion in your prose.

A reprex that shows `gamma(0.05, 1/0.005)` differs from `gamma(0.05, 0.005)`
has shown arithmetic. It has not shown that the package writes the first form.
Close the gap by pulling the actual code:

```r
grep("sp <- sp", deparse(greta.gam:::jagam2greta), value = TRUE)
#> [1] "    sp <- sp %||% gamma(0.05, 1/0.005, dim = 2 * n_smooth_params)"
```

Now the load of that package is doing real work, and the one fact the issue
turns on is evidence rather than a claim.

The test: **if I deleted the package from the reprex, would the output change?**
If not, you are not demonstrating a bug in it.

### When you have to patch something

Sometimes the behaviour cannot be reached without overwriting a function or a
value — showing what a fix *would* do, forcing a branch, or reaching an internal
that has no exported route. That is legitimate. Two rules:

**Say so, loudly.** The reader must know they are not seeing stock behaviour.
Put the override in its own block with a comment, never buried mid-example.

**Make sure the patch is actually in effect.** This is the trap. Editing a
package's source file and then calling `library(pkg)` loads the *installed*
package, and your edit does nothing — the example runs unpatched and you draw a
confident conclusion from it. Load the source you edited:

```r
pkgload::load_all(".")            # the patched source
# not: library(pkg)               # the installed version
```

**Prefer not to patch at all.** Usually you can isolate the operations at issue
and compare those directly, with no package surgery — which is clearer to read
and cannot silently fail to apply:

```r
calculate(solve(K), ...)              # what it does now
calculate(chol2inv(chol(K)), ...)     # what the fix would do
```

**Avoid `assignInNamespace()`** unless there is a very good reason and you have
said what it is. It mutates a loaded namespace for the rest of the session,
affects every later call including ones the reader is not thinking about, and
can leave the package internally inconsistent. It is a debugging tool, not a
demonstration tool. `pkgload::load_all()` on a patched copy gives a coherent
package instead of a spliced one.

Whichever route, print something that proves the patch took — the function body,
a version marker, a value that differs — before relying on the result. A silent
no-op patch is indistinguishable from a fix that does not work.


## Say why the thing you are removing was there

When the fix deletes or changes existing code, **state what you think it was
for, before removing it** —
[Chesterton's fence](https://fs.blog/chestertons-fence/).

Use that as the heading. Write:

```
### Chesterton's fence: why might it be there
```

not a paragraph explaining the parable. The reader either knows it or can
follow the link; spelling it out is padding.

Then give the hypothesis. Not "this line is wrong, delete it", but "this line
was probably doing X, and here is why X is not needed here". A hypothesis is
enough — it does not have to be right, and saying it lets the maintainer
correct you.

Do this even when the code looks obviously wrong. Obviously-wrong code that
survived review usually did so for a reason, and the reason is often a real
constraint you have not hit yet.

### Search the issue tracker first

If the code lives in a git repo with an issue tracker, **search it before
writing**. Closed issues especially — they are where the fence gets explained.

```bash
gh issue list --repo owner/repo --state all --limit 50 \
  --json number,title,state -q '.[] | "\(.number)\t\(.state)\t\(.title)"' \
  | grep -iE "keyword|other-keyword"
```

Read the matches with `--comments`. What this catches:

- **You are about to file a duplicate.**
- **The behaviour was discussed and deliberately chosen.** Then it is a docs
  issue, not a bug.
- **You are about to contradict a maintainer.** Better to find that now. A
  closed issue saying "this works" and your reprex saying it does not usually
  means you are talking about different functions — say which, and cite the
  issue, rather than implying they were wrong.
- **Someone already scoped the fix.** Requirements noted there are worth
  carrying into your issue.

### Hyperlink every issue you mention

Cite what you find, and make each reference a link:

```
[#20](https://github.com/OWNER/REPO/issues/20)
```

not a bare `#20`.

GitHub auto-links `#20` **only within the same repository**. A reprex often
crosses repos — an extension package citing an issue in the package it extends —
and there the bare form renders as plain text, or worse, silently links to an
unrelated issue with that number in the repo you are posting to.

Say what the issue is, not just its number, so the reader can decide whether to
follow it:

> [#5](https://github.com/greta-dev/greta.gam/issues/5) (closed) asked for `sp`
> support in `jagam2greta()`. It was added there and works.

Same for pull requests, and for issues in other organisations' repos. If you
mention a closed issue, say it is closed — it changes how the reference reads.

### Check `git blame`

If the code is in a git repo, **do this — do not ask first.** Once you know
which line is at fault, go and find out when it arrived and what came with it.
It is fast and it usually settles the fence question outright.

```bash
git log -L <start>,<end>:<file> --oneline    # history of specific lines
git log -S"some code" -- <file>              # commits adding/removing a string
git blame -L <start>,<end> <file>
```

`git log -S` is the sharper tool for a fence: it finds when a string entered or
left a file. **An empty result is itself an answer** — if the line you think was
removed was never there, this is an omission rather than a removal, and there is
no fence to worry about. Say so; it turns a hedged guess into a fact.

**Link to it on GitHub**, if the remote is there. A maintainer can then check in
one click instead of running your commands:

```
https://github.com/OWNER/REPO/blame/main/PATH#L83
https://github.com/OWNER/REPO/commit/<full-sha>
```

Use the full SHA in commit links, and confirm the commit is actually on the
remote first (`git branch -r --contains <sha>`) — a link to an unpushed commit
is a 404.

### Link every line reference, do not write `file.R:83`

Whenever you cite a line, make it a permalink pinned to a full SHA:

```
[`jagam2greta.R#L83`](https://github.com/OWNER/REPO/blob/<full-sha>/R/jagam2greta.R#L83)
```

not

```
`jagam2greta.R:83`
```

Ranges work too: `#L76-L80`.

**Pin the SHA, never `main`.** A `blob/main/...#L83` link points at whatever
line 83 becomes, so it rots the moment anyone edits above it — and an issue is
read long after it is filed. `git rev-parse HEAD` gives you the SHA.

Two checks before you paste them:

- **The commit is pushed.** `git branch -r --contains HEAD`. Otherwise it 404s.
- **The line numbers are right at that SHA**, not in your working tree, which
  may have uncommitted edits shifting everything:
  `git show <sha>:R/file.R | sed -n '83p'`

If the code is not committed at all, you cannot link it. Paste the snippet
inline and say it is uncommitted, rather than citing a line number nobody else
can resolve.

**And inline the diff** when it is small. A three-line diff in the issue is
worth more than a link, because it is read without leaving the page:

```
-    sp <- gamma(0.05, 1/0.005, dim = 2*length(...))
+    sp <- gamma(0.05, 1 / 0.005, dim = 2 * length(...))
```

Where you can, show evidence for the hypothesis rather than asserting it:

```r
#' `1/rate` appears literally in base R's own signature, so a `1 /` is exactly
#' what you would write if you believed the target took a scale.
args(rgamma)
#> function (n, shape, rate = 1, scale = 1/rate)
```

Then say what follows if the hypothesis is wrong. "If this *was* deliberate,
the fix is wrong and the docs need to change instead" tells the maintainer
which way to check, and is the difference between a proposal and a demand.

Anything beyond that — measured evidence, comparisons of candidate fixes,
condition numbers, failure-rate tables — goes in a separate investigation note
that the reprex links to. It is not part of the reprex.


## Measure the cost where it is actually paid

If the fix might be slower, benchmark it. But benchmark **the right thing**:

- **In the right language.** Timing R code tells you nothing about the op that
  runs in TensorFlow, Python or C++. Benchmark the layer that does the work.
- **At the right moment.** Code that builds a computation graph runs *once*. The
  cost that matters is what runs per iteration. These can differ by orders of
  magnitude, and can point in opposite directions.
- **End to end as well.** A per-call figure is diluted by everything else.
  Report both: "8% on the op, 3% overall" is more useful than either alone.

A worked failure: `bench::mark(solve(K), chol2inv(chol(K)))` in R said the
Cholesky route was **twice as fast**, so the fix looked free. Benchmarking the
actual TensorFlow ops said it was **8% slower**, and end-to-end sampling said
**3% slower**. The R benchmark measured the wrong language *and* a line that
executes once at graph construction. The honest claim is a 3% cost in exchange
for not failing half the time — a good trade, but a trade.

## Stop proposing mechanisms once measurement contradicts you

Explaining *why* is valuable, but it is the part most likely to be wrong,
because it is usually inferred from something partial — a traceback line, a
synthetic example, a plausible bit of numerics.

**If a proposed mechanism is contradicted by measurement, do not reach for
another one.** Say what is measured, and say the cause is not established.

Three explanations were offered for one bug here — ill-conditioning, gradient
overflow, float32 underflow — and each was refuted by the next experiment. The
report is better for saying so:

> The fix does not depend on knowing which it is: it converts a crash into a
> rejected proposal regardless of the cause.

Separate **what the fix does** from **why the bug happens**. If the fix stands
on measurement — it failed 7/12 before and 0/12 after — then an unresolved
mechanism does not block it, and a wrong mechanism confidently asserted would
discredit it.

Related: it is worth naming what *kind* of fix it is. "This is an
error-handling fix, not a mathematical one — the two operations are identical,
but one raises where the other returns `NaN`, and greta can already reject
`NaN`" is a sentence that survives the mechanism being wrong.

## Instrument the real thing before you theorise

Synthetic reconstructions, prior sweeps and isolated operations all *feel* like
evidence and repeatedly are not. Before settling on an explanation, observe the
actual failing run: record the values it reaches, vary one knob at a time,
and see what the failure rate tracks.

Varying `warmup` while holding everything else fixed produced this, in a couple
of minutes:

| warmup | failures |
| --- | --- |
| 0 | 0 / 8 |
| 50 | 5 / 8 |

which located the problem in warmup exploration and ruled out the initial
values — something three rounds of synthetic analysis had failed to establish.

## Stress test it: when is it a problem, and when is it not?

Having shown the bug, **go and find its edges.** Vary the thing you expect it to
depend on — sample size, dimension, magnitude, sparsity — and report where the
effect is large, where it disappears, and how fast it changes between them.

```r
rbind(`n = 200` = fit_both(200), `n = 40` = fit_both(40))
#>          sd_mgcv sd_greta  rmse
#> n = 200    3.042    3.033 0.242
#> n = 40     3.248    2.990 1.090
```

This is the step most likely to change what you were about to write, so do it
before you commit to a claim, not after.

- **It stops you overstating.** A defect can be real and still be invisible in
  most uses. "The prior is 40,000× off" and "your fits are wrong" are different
  claims, and only one survives contact with `n = 200`.
- **It stops you understating.** A bug that looks marginal on your example may
  be severe in the regime the package is actually used in.
- **It tells the maintainer who is affected**, which is what triage needs.
- **It catches a wrong mechanism.** If varying the thing your explanation
  depends on does not change the effect, your explanation is wrong.

**Check the direction, not just the size.** It is easy to assert which way an
effect goes and be wrong — a weaker penalty makes posterior *draws* wigglier
while leaving the posterior *mean* smoother, so "wigglier fits" was exactly
backwards. Measure the direction before naming it, and if the obvious diagnostic
does not show the effect, say which one would.

Report the boundary honestly, including when it is narrower than you hoped. An
issue that says "this matters below about n = 50" is more useful, and more
credible, than one that implies it always matters.

**Visualise the stress test too**, not just the summary table. A curve of effect
against the thing you varied, or the fits at each level overlaid, shows the
shape of the dependence — where it turns over, whether it is gradual or a cliff
— which a two-row table cannot.
