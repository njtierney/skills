---
name: blogdown-to-quarto
description: Migrate a blogdown/hugodown (Hugo) R blog to Quarto. Use when converting a Hugo-based R blog or website to a Quarto website - covers auditing the site, replicating the theme, migrating posts from pre-rendered output without re-executing R code, preserving old URLs with aliases validated against the live sitemap, RSS continuity, and GitHub Pages deployment with DNS cutover. Triggers on blogdown, hugodown, "Hugo to Quarto", "Rmarkdown blog", "migrate my blog".
---

# blogdown/hugodown → Quarto migration

A battle-tested playbook, distilled from a real 77-post, 13-year blog
migration. The prime directives:

1. **Never re-execute old R code.** Use the already-rendered output that
   blogdown/hugodown committed. Old posts documented what was true when
   written; re-running them breaks and rewrites history.
2. **Every existing URL keeps working.** Aliases validated 1:1 against the
   live sitemap, not guessed.
3. **Verify by rendering and looking**, not by assuming. Screenshot the old
   and new sites side by side; sweep rendered HTML for broken references.

## Phase 0 — Interview the user

Before touching anything, resolve these with the user (do not guess):

- **Old post handling**: pre-rendered output as frozen `.md` (recommended)
  vs re-execution. New posts will be `.qmd` with `freeze`.
- **URLs**: keep Hugo's structure exactly, or new Quarto-native structure
  (`/posts/<dir>/`) with redirects from every old URL (recommended).
- **Deployment**: GitHub Pages / Netlify / other; which repo and account
  (org repos may enforce domain verification — see
  `references/deployment.md`).
- **Scope**: skeleton + ~10 representative sample posts for approval first
  (recommended), then bulk migration.

## Phase 1 — Audit (read-only)

Inventory before writing anything:

- Classify every post: plain `.md` / `.markdown`+`.Rmarkdown` /
  bundle `index.md` (hugodown) / `.Rmd`. hugodown renders `.Rmd` → `.md`,
  so pre-rendered markdown usually exists for everything; verify per post.
- Identify drafts (`draft:` frontmatter — beware `draft: no` parses as a
  *truthy string* in Quarto) and untracked work-in-progress folders (they
  are unrecoverable if deleted — plan a `drafts/` rescue).
- Fetch the live `sitemap.xml` — it is the ground truth for URL count and
  permalinks. Post count from files must reconcile with it exactly.
- Inspect `static/`: `_redirects` (legacy redirect rules to replicate as
  aliases), `imgs/`, `favicon.ico`, figure dirs (`static/post/*_files/`),
  and anything hotlinkable (headshots, hex stickers).
- Grep content for Hugo shortcodes (`{{< tweet >}}`, `{{% youtube %}}`),
  math conventions, and raw HTML `<img>` tags.
- Read the theme + custom `layouts/` and `static/css/` — the look usually
  lives in a handful of small files.

## Phase 2 — Theme replication

Goal: near-identical look. See `references/theme-replication.md`. Keep the
Hugo site fully intact during migration: give `_quarto.yml` a `render:`
allowlist covering only new files, so old and new coexist in one repo.
Verify with side-by-side screenshots of the live site vs `quarto render`
output (headless browser), iterating on the SCSS until they match.

## Phase 3 — Migrate posts

Use `scripts/migrate_posts.R` (base workflow; requires the cli and fs
packages; see the header comment for usage). Per post it:
copies the best rendered source, cleans frontmatter (drops `output`,
`rmd_hash`, `tags`, optionally `author`), builds the old-URL alias, copies
asset dirs and `static/post/*_files/` figures (rewriting absolute paths),
and replaces tweet/youtube shortcodes with plain embeds.

Critical rules:

- **Aliases come from *frontmatter* date + slug** (that is what Hugo's
  permalink used), never from folder names — they frequently differ.
- Slug fallback when absent is the urlized title.
- **Validate every alias against the live sitemap**; investigate every
  mismatch individually (shadowed duplicate posts, published posts living
  in `drafts/`, date edits). Finish only when aliases ↔ sitemap is 1:1.

## Phase 4 — Verify

Gate on all of these before calling migration done:

- Clean `quarto render` (delete output dir first) with zero errors.
- Sweep every rendered HTML file for local image/href references that
  don't exist in the output — must be zero.
- Every live sitemap URL has a redirect page in the output.
- Feed exists, and a copy is written to the old Hugo feed path
  (`post-render` script) for existing RSS subscribers.
- Screenshot-compare representative pages against the live site.
- The definitive pre-cleanup test: clone the repo, delete the Hugo dirs,
  render from scratch, diff the output file list against the current one.

Known failure modes and their fixes: `references/gotchas.md`.

## Phase 5 — Deploy and cut over

GitHub Pages workflow, DNS records, domain verification traps, the
post-transfer 404 fix, and the decommission/salvage checklist:
`references/deployment.md`.

## Aftercare

Give the user a replacement for `blogdown::new_post()` (folder-per-post
archetype + small R function), document the new-post workflow, and only
delete the Hugo files after the salvage audit (drafts, static extras,
`_redirects` rules) and the clean-clone render test both pass.
