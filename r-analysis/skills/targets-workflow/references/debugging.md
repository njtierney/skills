# Debugging a failed target

The house workflow, distilled from chapter 4 of the manual. For the full
chapter — `demo_small.R`, `demo_browser.R`, `demo_workspace.R` from
wlandau/targets-debug, and everything not settled here — search the `targets`
MCP store.

Debugging a pipeline is different from debugging a script, and the difference
is deliberate: the pipeline runs in a non-interactive `callr::r()` process,
possibly on `crew` workers, with its own error catching. Do not fight that with
`print()` and re-runs. Peel the layers back in this order.

## 0. Read what the pipeline already told you

```r
tar_meta(fields = error, complete_only = TRUE)     # the error, per target
tar_meta(fields = warnings, complete_only = TRUE)  # warnings you missed
```

A warning that precedes the error is often the actual story.

## 1. Workspaces — the default route

Every target that errors saves a **workspace**: a file that reconstructs the
target's environment locally — global functions, upstream dependencies, and the
target's original RNG seed. Saving on error is the default since targets 1.8.0
([NEWS](https://github.com/ropensci/targets/blob/main/NEWS.md#targets-180));
only pre-1.8.0 projects need `tar_option_set(workspace_on_error = TRUE)`.

The loop:

```r
tar_make()
#> ✖ analysis_9f60c6e05a6c5414 errored

tar_workspaces()                          # which targets left workspaces
tar_workspace(analysis_9f60c6e05a6c5414)  # load deps, functions, seed
ls()                                      # the target's world, in your session
analyze_data(data)                        # reproduce the error interactively
tar_traceback(analysis_9f60c6e05a6c5414)  # the saved traceback if you need it
```

Fix the function in `R/`, then `tar_make()`. Do not patch objects in the
session and call it fixed — the pipeline rebuilds from functions, not from your
workspace.

Why this is the default route:

- **Dynamic branching.** The workspace names the one failed branch of a
  hundred, and loads that branch's slice of the upstream data. There is no
  faster way to get exactly the failing case into your hands.
- **crew.** The workspace is saved wherever the target ran, so the loop is
  unchanged when the error only appears under a controller. The browser routes
  below need the pipeline in your own session; this one does not.
- **Seeds.** The workspace restores the target's seed, so "random" failures
  reproduce. The seed itself: `tar_meta(names = <target>, fields = seed)`.

Workspaces are not only for errors — to inspect a target that *succeeds* but
looks wrong, name it: `tar_option_set(workspaces = c("analysis"))`.

Clean up when done: `tar_destroy(destroy = "workspaces")`.

## 2. The `debug` option — a live browser inside one target

When you need to *step through* the target as the pipeline runs it — not just
hold its inputs — point `debug` at the target and skip everything else:

```r
# _targets.R
tar_option_set(
  debug = "analysis_58_8edfc70f9a7feaf4",  # branch names work
  cue = tar_cue(mode = "never")            # skip other outdated targets
)
```

```r
# R console — restart the session first
tar_make(callr_function = NULL, use_crew = FALSE, as_job = FALSE)
#> → You are now running an interactive debugger in target analysis_58_...
Browse[1]> debug(analyze_data)   # then `c` to step into your own function
```

`cue = tar_cue(mode = "never")` force-skips outdated targets so you jump
straight to the one under debug; targets not yet in the metadata, and targets
with their own cues, still run.

## 3. `browser()` in the function

The blunt version of the same trick, when you would rather edit the function
than the options: insert `browser()` into the failing function, restart the
session, and run the pipeline interactively with the same
`tar_make(callr_function = NULL, use_crew = FALSE, as_job = FALSE)`.

## The `callr_function = NULL` caveat

`callr_function = NULL` runs the pipeline in your current session. That is for
debugging **only**: a messy local environment can silently change the functions
and objects targets depend on, invalidating targets and erasing results that
were previously correct — which is why `targets` uses `callr` at all. Restart
the session before using it, and never leave it in a script.
