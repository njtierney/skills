# blogdown-to-quarto

A [Claude Code](https://claude.com/claude-code) plugin for migrating
blogdown/hugodown (Hugo) R blogs to [Quarto](https://quarto.org) websites —
without re-executing years-old R code, while preserving every URL, and
replicating your existing theme so readers can't tell the engine changed.

Distilled from a real migration of a 13-year, 77-post blogdown site
([njtierney.com](https://www.njtierney.com)), including all the traps we
hit so you don't have to: Quarto's executable-code detection vs verbatim
chunk demos, chroma-highlighted HTML, sitemap-validated URL aliases, RSS
continuity, Netlify→GitHub Pages DNS cutover, and more.

## What's inside

- **A skill** (`skills/blogdown-to-quarto/`): the migration playbook Claude
  follows — a phased workflow (audit → theme → posts → verify → deploy)
  with reference docs for [gotchas](skills/blogdown-to-quarto/references/gotchas.md),
  [theme replication](skills/blogdown-to-quarto/references/theme-replication.md), and
  [deployment](skills/blogdown-to-quarto/references/deployment.md).
- **An agent** (`agents/migrate.md`): a delegated worker that executes the
  playbook end-to-end on a branch, with strict verification gates.
- **A migration script**
  ([`migrate_posts.R`](skills/blogdown-to-quarto/scripts/migrate_posts.R)):
  migrates posts from their pre-rendered output, cleans Hugo frontmatter,
  and validates old-URL aliases 1:1 against your live sitemap. Uses
  [cli](https://cli.r-lib.org) and [fs](https://fs.r-lib.org); also usable
  standalone without Claude.

## Installation

In Claude Code (this plugin lives in the
[njtierney/skills](https://github.com/njtierney/skills) marketplace):

```
/plugin marketplace add njtierney/skills
/plugin install blogdown-to-quarto@njtierney-skills
```

## Usage

In your blog's repo, just describe the job — the skill triggers on it:

```
Migrate this blogdown site to Quarto, keeping the same look.
```

Claude will interview you about the decisions that matter (how to handle
old posts, URL strategy, deployment, scope) before touching anything.

Or delegate the whole migration to the agent:

```
@agent-blogdown-to-quarto:migrate this blog, using pre-rendered output,
new /posts/ URLs with redirects, GitHub Pages, sample-first.
```

Or run the post-migration script directly, no Claude required:

```bash
curl -s https://YOURSITE/sitemap.xml | grep -o '<loc>[^<]*' | sed 's/<loc>//' > sitemap.txt
Rscript migrate_posts.R --content content/post --out posts \
  --static static/post --sitemap sitemap.txt
```

## The prime directives

1. **Never re-execute old R code** — migrate the rendered output blogdown
   already committed.
2. **Every existing URL keeps working** — aliases validated against the
   live sitemap, not guessed.
3. **Verify by rendering and looking** — screenshot comparisons and
   reference sweeps, not vibes.

## License

MIT © Nicholas Tierney
