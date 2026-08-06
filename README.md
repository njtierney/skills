# skills

Claude Code skills and agents from [Nick Tierney](https://www.njtierney.com),
for R, Quarto, and blogging workflows. Structured as a
[plugin marketplace](https://code.claude.com/docs/en/plugin-marketplaces):

```
/plugin marketplace add njtierney/skills
```

## Plugins

### [blogdown-to-quarto](blogdown-to-quarto/)

Migrate a blogdown/hugodown (Hugo) R blog to a Quarto website — without
re-executing years-old R code, while preserving every URL, and replicating
your existing theme. Distilled from a real 13-year, 77-post migration.

```
/plugin install blogdown-to-quarto@njtierney-skills
```

Includes a migration skill (phased playbook + gotcha/theme/deployment
references), a delegated `migrate` agent, and a standalone
[`migrate_posts.R`](blogdown-to-quarto/skills/blogdown-to-quarto/scripts/migrate_posts.R)
script. See the [plugin README](blogdown-to-quarto/README.md).

### [r-analysis](r-analysis/)

House style for R analysis projects — four interlocking skills that layer:
**r-project-conventions** (the envelope: `conflicted`, `fs`, `air`, layout),
**r-function-design** (function internals: `check_*` functions,
decomposition), **targets-workflow** (the pipeline: `tar_assign()` style,
file targets, the grammar of a readable plan, workspace debugging, `crew`),
and **code-comments** (the three-stage test, plus an audit pass). Distilled
from [tflow](https://github.com/MilesMcBain/tflow), the
[targets manual](https://books.ropensci.org/targets/), and real pipelines.

```
/plugin install r-analysis@njtierney-skills
```

See the [plugin README](r-analysis/README.md), including the knowledge stores
in [`stores/`](stores/) that two of the skills reach for.

### [reprex](reprex/)

Write minimal reproducible examples for R bug reports and GitHub issues —
lead with the code, the `.R` file as source of truth, minimality as a
discipline.

```
/plugin install reprex@njtierney-skills
```

## License

MIT © Nicholas Tierney
