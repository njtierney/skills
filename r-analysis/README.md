# r-analysis

House style for R analysis projects, as skills. Two so far:

- **[targets-workflow](skills/targets-workflow/SKILL.md)** — structure an R
  analysis as a `targets` pipeline: layout, `tar_assign()` style, file targets,
  the grammar of a readable pipeline (verbs in `R/`, nouns in the plan),
  workspace debugging, and going parallel with `crew`. Conventions follow
  [tflow](https://github.com/MilesMcBain/tflow), the
  [targets manual](https://books.ropensci.org/targets/), and Nick's own
  projects.
- **[code-comments](skills/code-comments/SKILL.md)** — write fewer, better
  comments: the three-stage test for whether a comment earns its place, and an
  audit pass for comments already written.

```
/plugin install r-analysis@njtierney-skills
```

## A note on sibling skills

These two are part of an interlocking set. They cite two siblings not yet
published here — `r-project-conventions` (project envelope: packages.R +
conflicted, fs, air, output/) and `r-function-design` (function internals).
The references degrade gracefully — each rule cited is named in enough context
to act on — but the full set is the intended experience, and the siblings may
land here later.

## Knowledge stores

`targets-workflow` reaches for a retrieval store of the targets user manual
when one is configured (an MCP tool named like `mcp__targets__search_store_*`).
Build scripts live in [`stores/`](../stores/) at the repo root. Without a
store, the skill falls back to fetching chapters from
books.ropensci.org/targets.
