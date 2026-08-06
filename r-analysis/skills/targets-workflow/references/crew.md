# Going parallel with `crew`

Loaded on demand from the `targets-workflow` skill. Read this when adding a
controller to a pipeline, not before — a serial pipeline that is fast enough
needs none of it.


```r
tar_option_set(controller = crew::crew_controller_local(workers = 4))
```

Adding a controller to a pipeline that worked serially is a good stress test —
it surfaces untracked state, because workers do not source `_targets.R`. Rules 5
and 8 are what make the move uneventful: hooks travel with the command, and
packages travel in the `.packages()` snapshot.

- **Don't set `workers` to the core count — sweep it.** Anything with a
  per-process startup cost (font database scans, JIT, large package loads) is paid
  *once per worker*, so past some point each new worker adds more setup than it
  removes work. One pipeline measured 3 workers 19.3s, 4 workers 19.4s, 6 workers
  21.3s, 8 workers 20.7s against 33.1s serial on 8 cores — the knee was at four,
  half the cores. Four clean builds tell you more than any reasoning about cores.
- **Total CPU time goes *up*, and that is fine.** Watch wall clock, not
  `tar_meta(fields = "seconds")`. Memory-bandwidth-heavy work (reading big images)
  contends, so the same job can cost 4× the CPU seconds across branches while the
  build still finishes sooner.
- **Branch the long target on the critical path.** That is the main structural
  win — a single target that waits for everything upstream and blocks everything
  downstream. A slow target that nothing waits for is not worth branching.
- **Confirm the parallel build is byte-identical to the serial one.** If it is
  not, you have found real order-dependence, not a crew problem.
