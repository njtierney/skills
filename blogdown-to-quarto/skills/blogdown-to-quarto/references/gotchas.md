# Gotchas: things that WILL bite, and their fixes

Every item below was hit in a real migration.

## Quarto's executable-code detection ignores fence nesting

Posts that *demonstrate* verbatim R chunks (```` ```{r} ```` shown inside
4/5-backtick fences) make Quarto refuse to render `.md` files ("You must
use the .qmd extension for documents with executable code"). Renaming to
`.qmd` fails differently: knitr's parser also ignores nesting and errors
on duplicate chunk labels.

**Fix:** rewrite the verbatim example blocks as raw HTML
`<pre><code>...</code></pre>` with every backtick escaped as `&#96;`.
Identical display, invisible to both scanners. Scan the whole corpus up
front: `grep -rn '^\s*```\+\s*{' posts/*/index.md`.

## chroma-highlighted HTML (hugodown posts)

hugodown-era rendered markdown embeds already-highlighted code as raw HTML
(`<div class="highlight"><pre class="chroma">` with `.nf`/`.st`/... spans).
Consequences:

- Pandoc/Quarto highlighting never touches them → carry over the Hugo
  site's `syntax.css` or the code renders unstyled black text.
- Quarto's copy-to-clipboard button only attaches to code Quarto
  highlights → inject buttons via a small `include-after-body` script that
  appends Quarto's exact button markup to `div.highlight > pre` and uses
  `navigator.clipboard` (Quarto's CSS then styles it for free).
- `div.highlight` is ALSO used by hugodown to wrap *figures* — never style
  `div.highlight` itself for code; target `pre` inside it.

## Raw HTML images

knitr emitted figures as raw `<img src=... width=...>` tags. Quarto's
`lightbox: true` only attaches to markdown-syntax images. If lightbox is
wanted, add a JS shim that wraps unlinked content `<img>`s in lightbox
anchors and lazily loads GLightbox from
`site_libs/quarto-contrib/glightbox/` (present site-wide once any page
uses native lightbox). Skip images already inside `<a>`.

## Math

blogdown's convention was code-backtick-wrapped math (`` `\(...\)` ``)
unwrapped client-side by a JS helper. Quarto renders it as literal code.
Convert to `$...$` (regex: `` `\\\((.+?)\\\)` `` → `$\1$`). Usually only a
handful of posts; grep for `\frac|\alpha|\sum` to find real math and don't
be fooled by R's `$` column operator.

## draft: no

YAML `no` reaches Quarto as the *string* "no", which is truthy — the post
silently vanishes from listings while still rendering. Delete the line or
use `false`. Same for `yes`/`true`.

## Aliases and permalinks

- Hugo permalinks like `/post/:year/:month/:day/:slug/` use the
  **frontmatter** date and slug. Folder names lie: posts get renamed,
  drafted on one date and published on another.
- No `slug:` → Hugo falls back to the urlized title.
- Validate the complete alias set against the live `sitemap.xml`. Real
  mismatches found this way: a bundle containing TWO posts (`index.md`
  shadowed by `index.markdown` — only one was ever live), and a published
  post living in the `drafts/` folder.

## Figure paths

Older blogdown posts reference `/post/<slug>_files/figure-html/...` which
lives in `static/post/`. Copy each referenced `*_files` dir into the post
folder and rewrite the path to relative. Modern hugodown posts use
relative `figs/`/`imgs/` — copy the whole bundle dir. Also copy **loose
files** in bundles (a header image sitting next to index.md is easily
missed by dir-only copying).

## Shortcodes

Rendered output can still contain `{{< tweet id >}}` / `{{% youtube id %}}`
(sometimes inside `<!--html_preserve-->` wrappers — strip those).
Replace with plain embeds:

- tweet → `<blockquote class="twitter-tweet"><a href="https://twitter.com/i/web/status/ID"></a></blockquote>` + widgets.js script
- youtube → responsive `<iframe src="https://www.youtube.com/embed/ID">`

Grep for `{{[<%]` after migration; leftovers render as literal text.

## static/ salvage checklist (before deleting Hugo dirs)

- `static/_redirects` — Netlify rules often hide ancient (pre-Hugo!) URL
  redirects; replicate each as an extra post alias. Wildcard rules (e.g.
  `/slides/*`) cannot be replicated on GitHub Pages — flag the loss.
- `static/imgs/`, `favicon.ico`, hex stickers etc. — republish at the same
  root paths via Quarto `resources:` (external sites hotlink these).
- `/favicon.ico` specifically: some clients request the path blindly.

## Site-config details easily forgotten

- RSS: Quarto's feed lands at `/index.xml`; Hugo's was often
  `/post/index.xml`. GitHub Pages can't redirect XML — copy the feed to
  the old path with a `post-render` script (guard it: the feed only exists
  on full project renders).
- Homepage title: Quarto promotes the first body `<h1>` (e.g. a custom
  site header include) to page title on pages without frontmatter titles
  and shrinks it with `.display-7` — override with `!important`.
- `toc-title: ""` is ignored (empty = default); hide the heading with CSS.
- Utterances comments: Quarto supports it natively
  (`comments.utterances`); site-wide config + `comments: false` on
  non-post pages replicates "posts only".
- Keep the `render:` allowlist after cleanup if a `drafts/` folder exists
  — the allowlist is what stops Quarto rendering it.
