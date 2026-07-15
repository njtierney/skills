# Deployment: GitHub Pages, DNS, and cutover

## Publish workflow

`quarto-actions` publishing to a `gh-pages` branch. Because posts are
pre-rendered markdown (and future executable posts use committed
`_freeze/`), **CI needs no R at all**:

```yaml
on:
  workflow_dispatch:
  push:
    branches: [main]   # or master
name: Quarto Publish
jobs:
  build-deploy:
    runs-on: ubuntu-latest
    permissions:
      contents: write
    steps:
      - uses: actions/checkout@v4
      - uses: quarto-dev/quarto-actions/setup@v2
      - uses: quarto-dev/quarto-actions/publish@v2
        with:
          target: gh-pages
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

Create the `gh-pages` branch once first (`quarto publish gh-pages`
locally, or an orphan branch push). Include a `CNAME` file (the custom
domain) in the site output via `resources:`.

## RSS continuity

Quarto's feed is `/index.xml`; Hugo's was commonly `/post/index.xml`.
GitHub Pages can't redirect XML. `post-render` script:

```bash
#!/bin/bash
set -e
out="${QUARTO_PROJECT_OUTPUT_DIR:-_site}"
if [ -f "$out/index.xml" ]; then   # only exists on full renders
  mkdir -p "$out/post"
  cp "$out/index.xml" "$out/post/index.xml"
fi
```

## Repo/org traps (learned the hard way)

- **Org-owned repos can enforce domain verification** (org-level setting).
  If the Custom Domain box rejects the domain with "You must verify your
  domain", and the user can't administer the org's verified domains, the
  clean escape is **transferring the repo to a personal account** —
  personal repos don't enforce verification, GitHub redirects all old repo
  URLs, and issue-based comments (utterances/giscus) move with the repo.
  Update `repo-url` and the comments `repo:` after transfer.
- **After a repo transfer, the custom domain can serve 404** ("Site not
  found") even though Pages shows everything correct and other URLs 301
  *to* the domain. Fix: remove and re-add the custom domain (API:
  `PUT /repos/{o}/{r}/pages` with `cname: null`, then the domain again) to
  refresh the stale CDN binding.
- Reproduce UI errors via `gh api` — the API returns the actual error
  message the settings page hides.

## DNS cutover (registrar/DNS console)

Only two records change. Never touch MX (email), NS/SOA, or existing TXT.

1. Days before: lower TTL on both records to 300s (fast switch, fast
   rollback). Note the old values for rollback.
2. `www` CNAME → `<account>.github.io.` (the **repo owner's** Pages host;
   changes if the repo moves between accounts/orgs).
3. Apex A record → GitHub Pages IPs: `185.199.108.153`, `.109.153`,
   `.110.153`, `.111.153` (apex can't be a CNAME). GitHub auto-redirects
   apex ↔ www toward the CNAME-file name.
4. Leave the old host (e.g. Netlify) running until verified — during TTL
   propagation both serve traffic, nobody sees downtime.
5. When the Pages DNS check is green and the certificate is issued, tick
   "Enforce HTTPS", then decommission the old host.

Test GitHub's serving *before* DNS moves:
`curl --resolve www.example.com:443:185.199.108.153 https://www.example.com/`.

## Decommission checklist

Before deleting the Hugo dirs (`content/`, `static/`, `themes/`,
`layouts/`, `archetypes/`, `resources/`, `config.toml`, `netlify.toml`):

1. Rescue unpublished writing: untracked WIP posts and `drafts/` → a
   top-level `drafts/` outside the render allowlist. Untracked files are
   unrecoverable after deletion; check `git ls-files --others`.
2. Salvage `static/` extras (see gotchas: `_redirects`, images, favicon).
3. The definitive test: clone the repo, delete the candidate dirs in the
   clone, `quarto render` from scratch, and diff the output file list
   against the current build. Zero missing files = safe.
4. After deletion, verify the live site again post-deploy (homepage, an
   old-URL redirect, the feed, an image).
