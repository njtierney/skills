# Knowledge stores

Build scripts for the retrieval ("knowledge") stores the skills in this repo
reach for. A store is a [ragnar](https://ragnar.tidyverse.org) index over a
public reference text, exposed to Claude Code as an MCP search tool; the skill
carries the opinions, the store carries the reference.

The built store database is a local artifact (embeddings, local paths) — what
this directory shares is the **script that builds it**. Run the script, then
register the store as an MCP tool (e.g. via
[btw](https://posit-dev.github.io/btw/)) so the skills can search it.

Planned scripts, in priority order:

| store | source | used by |
|---|---|---|
| `targets` | books.ropensci.org/targets (user manual) | targets-workflow |
| `geotargets` | geotargets docs | targets-workflow (spatial) |
| `targets-reference` | docs.ropensci.org/targets + tarchetypes function reference | targets-workflow |
| `targets-design` | books.ropensci.org/targets-design (package internals) | contributing to targets |

Scripts to follow.
