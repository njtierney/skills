# r-analysis

House style for R analysis projects, as four interlocking skills:

- **[r-project-conventions](skills/r-project-conventions/SKILL.md)** — the
  project envelope: attach packages with `conflicted` rather than `pkg::fun()`,
  `fs` over base file functions, `air` formatting, `.Renviron`, where generated
  files go, what the README must answer, sizing files in `R/`.
- **[r-function-design](skills/r-function-design/SKILL.md)** — the inside of a
  function: where validation lives (`check_*` functions), when one function
  should be several, decomposing calculations, keeping nesting shallow.
- **[targets-workflow](skills/targets-workflow/SKILL.md)** — structure the
  analysis as a `targets` pipeline: layout, `tar_assign()` style, file targets,
  the grammar of a readable plan (verbs in `R/`, nouns in the plan), workspace
  debugging, going parallel with `crew`. Conventions follow
  [tflow](https://github.com/MilesMcBain/tflow) and the
  [targets manual](https://books.ropensci.org/targets/).
- **[code-comments](skills/code-comments/SKILL.md)** — write fewer, better
  comments: the three-stage test for whether a comment earns its place, and an
  audit pass for comments already written.

They layer: conventions is the envelope, function-design the internals,
targets-workflow the pipeline on top, code-comments the prose inside. Each
skill cites the others rather than restating them, so install the set.

```
/plugin install r-analysis@njtierney-skills
```

## Knowledge stores

`targets-workflow` and `r-function-design` reach for retrieval stores (the
targets user manual; Tidy Design Principles) when one is configured — an MCP
tool named like `search_store`. Build scripts live in
[`stores/`](../stores/) at the repo root. Without a store, the skills fall
back to fetching the source sites directly.
