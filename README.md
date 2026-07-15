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

## License

MIT © Nicholas Tierney
