---
name: r-function-design
description: Designing R functions — where validation lives, when one function should be several, decomposing a calculation, and keeping nesting shallow. Use when writing or reviewing the internals of R functions, when a function is hard to follow or hard to test, when deciding how to split a calculation into steps, or when asked about defensive programming, check_ functions, cyclomatic complexity, or "this function does too much".
---

# R function design

Layers on `r-project-conventions` (project envelope) and sits under
`targets-workflow` (pipeline structure). This one is about the inside of a
function.

## Search the tidy design principles first

**The `r-design` knowledge store is design.tidyverse.org** (Tidy Design
Principles). Most questions about function *interfaces* are answered there
better than they are here. Search it before reasoning from scratch. The exact
tool name varies by setup; look for an `r-design` MCP tool named like
`search_store`:

```
mcp__r-design__search_store_004(text = c(
  "<a full sentence describing the design question>",
  "<three or four keywords for the same thing>"
))
```

**No store configured?** design.tidyverse.org is fetchable directly; store
build scripts live in `stores/` at github.com/njtierney/skills.

The chapters that come up most:

| Question | Chapter |
|---|---|
| Does this function do too much? | `strategy-functions` — "Three functions in a trench coat" |
| Where does input validation go? | `cs-setNames` — the `check_names()` case study |
| Repeated errors | `err-constructor` — `stop_{error_type}()` naming |
| Naming, prefixes, families | `function-names` |
| Hidden dependencies on options/state | `inputs-explicit` |
| `<<-`, and `map()` where a loop is clearer | `spooky-action` |

That store covers **interface** design. What follows is the part it does not:
what the inside of the function looks like.

## Error handling eclipse

Validation inline, in volume, obscures what the function is for. Nick's write-up:
<https://www.njtierney.com/posts/2023-12-01-long-errors-smell/>

```r
# The whole function. 8 lines of guard, 4 lines of work.
superpose <- function(panels, contribution) {
  if (nrow(panels) == 0) {
    cli::cli_abort(c(
      "No panels to evaluate.",
      "x" = "The panel table has no rows.",
      "i" = "A constraints surface needs at least one panel."
    ))
  }

  panels |>
    split(seq_len(nrow(panels))) |>
    purrr::map(contribution) |>
    purrr::reduce(`+`)
}
```

Extract to a named `check_*` function, so the guard reads as one line and the
work is visible:

```r
superpose <- function(panels, contribution) {
  check_has_rows(panels)

  panels |>
    split(seq_len(nrow(panels))) |>
    purrr::map(contribution) |>
    purrr::reduce(`+`)
}
```

**Use `caller_env()` and `caller_arg()`**, or the error is attributed to the
check rather than to the function the user called:

```r
check_has_rows <- function(x,
                           arg = rlang::caller_arg(x),
                           call = rlang::caller_env()) {
  if (nrow(x) > 0) {
    return(invisible(x))
  }
  cli::cli_abort("{.arg {arg}} has no rows.", call = call)
}
```

The `cs-setNames` case study makes the same point about separation, and adds a
detail worth copying: put a blank line between the checks and the implementation,
so the two parts of the function are visible at a glance.

## Validate once, early — not in every function that touches the data

Count the guards before adding another. If the same condition is checked in five
places, the check belongs at the boundary, not at each use.

```
$ grep -c "cli_abort" R/*.R
```

One project had **26 `cli_abort` calls across 2,901 lines — 6% of the codebase**,
with the same "no panels" condition guarded in five separate functions and zero
`check_*` functions anywhere.

In a pipeline, that boundary is a target that fails (see `targets-workflow`
rule 6). Everything downstream can then assume valid input, which is what lets
the calculations read as calculations.

**The trade-off, stated honestly:** a function with its guards removed is less
safe called directly from the console. That is the right trade when the function
is internal and the boundary is real. It is the wrong trade for an exported API,
where `r-design`'s advice applies instead.

## One function, one job

`strategy-functions` covers the interface case. The internal version:

```r
filter_active_panels <- function(panels) {
  # 1. abort if no rows
  # 2. return unchanged if the column is absent
  # 3. abort if nothing is active
  # 4. inform about what was dropped
  # 5. ...filter
}
```

Five jobs behind a name promising one. The filtering is `dplyr::filter(panels,
active)`; the rest is validation that belongs at the boundary and a message that
belongs where the decision is made.

**Signals:** a name containing "and"; a docstring listing behaviours; a function
you cannot describe without "it also".

## Decompose calculations into named steps, not loops over names

```r
# Hard to read, hard to breakpoint, hard to test one coefficient
resolve_hb_coefficients <- function(panels, lookup, plateau) {
  coefficients <- c("smax_te", "k1", "k2", "k3")
  resolved <- lapply(coefficients, \(var) resolve_hb_var(panels, var, lookup))
  names(resolved) <- coefficients
  resolved$smax_te <- pmin(resolved$smax_te, plateau)
  dplyr::mutate(panels, !!!resolved)
}
```

Four named functions — `lookup_smax_te()`, `lookup_k1()`, `lookup_k2()`,
`lookup_k3()` — are more lines and less code. Each is separately testable,
separately documentable, and shows up by name in a traceback.

**Metaprogramming to avoid writing four similar functions usually costs more than
it saves.** A character vector of column names, a `!!!` splice and a helper that
builds argument names with `paste0()` is three indirections to avoid four
one-liners. Prefer the four.

Use `function-names` from `r-design` to pick the prefix: a shared `lookup_*` or
`approx_*` groups them for autocomplete and says what kind of thing they are.

## Keep nesting shallow, and name the intermediate

`split() |> map() |> reduce()` in one expression is three ideas with no names
between them. Give the middle one a name:

```r
contributions <- panels |>
  split(seq_len(nrow(panels))) |>
  purrr::map(contribution)

purrr::reduce(contributions, `+`)
```

Now `contributions` is inspectable at a breakpoint, and the reduce says what it
reduces.

**Question every `reduce()`.** It is the right tool for a genuine fold over an
associative operation, and the wrong one where a vectorised call says it plainly.
`reduce(x, `+`)` over a list of equal-length vectors is often `rowSums()` of a
matrix. `reduce(pmax, .init = rep(0, n))` is often `apply(m, 1, max)`. Neither
rewrite is automatically better — but if you cannot say why the fold is clearer,
it probably is not.

`spooky-action` in `r-design` makes the related point about `map()`: purrr
restricts what you can do so the code is easier to understand, and where it does
not achieve that, a loop is fine.

## Reviewing function design

1. How many lines of the function are guards, and how many are work?
2. Is the same condition checked in more than one function?
3. Can you name what the function does without "and" or "also"?
4. Does any function loop over a character vector of names to avoid writing
   several small functions?
5. Is there an unnamed intermediate in a three-stage pipe?
6. Does every `reduce()` beat the vectorised alternative, and can you say why?
7. Are `check_*` functions using `caller_env()` / `caller_arg()`?

Then search `r-design` for anything touching the *interface*: argument order,
names, defaults, dots, return types.
