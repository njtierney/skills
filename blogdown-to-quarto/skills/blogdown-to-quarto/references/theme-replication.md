# Replicating a Hugo theme in Quarto

Goal: the reader can't tell the site changed engines. Minimal Hugo themes
(hugo-xmin and friends) usually live in ~5 small files; find them first:
the theme's `layouts/_default/*.html` + `static/css/*.css`, **plus the
site's own `layouts/` and `static/css/` overrides** (the personality is
usually in the overrides, not the theme).

## Mapping Hugo → Quarto

| Hugo | Quarto |
|---|---|
| `config.toml` menus, params | `_quarto.yml` (`website:`) |
| theme + custom CSS | `theme: [default, assets/theme.scss]` |
| `layouts/partials/header.html` | `include-before-body: assets/header.html` (raw HTML replica) |
| footer partial | `page-footer:` (markdown) |
| homepage `list.html` | listing page + custom `template: assets/listing.ejs` |
| `single.html` title block | CSS overrides on `#title-block-header` |
| `static/*` | root-level dirs listed under `resources:` |
| Google Analytics / utterances | `comments.utterances`; GA via header include |

Practical notes:

- **Coexistence**: `render:` allowlist in `_quarto.yml` naming only the new
  files lets the Hugo tree stay in place untouched until cutover.
- **Custom header**: replicating a bespoke header (logo, styled title,
  centred menu) as an `include-before-body` HTML fragment is far more
  faithful than fighting Quarto's navbar. Remember it lands *inside* the
  content column.
- **Fonts**: import Google Fonts in the SCSS `$web-font-path`; set
  `$font-family-sans-serif` / `$font-family-monospace` and override
  heading font-family in rules.
- **Listing template**: a small EJS template reproduces Hugo's
  `YYYY/MM/DD title` list exactly; format dates in JS, don't rely on
  field formatting.
- **Code block conventions**: match the old site's wrapping
  (`code-overflow: wrap`), width (use `ch` units for an N-character
  target; note `ch` measures the *element's own* font), and highlight
  style — plus `syntax.css` for chroma HTML (see gotchas).
- **Margin TOC**: `posts/_metadata.yml` scopes `toc:` to posts only. The
  sidebar is sticky from page top; `margin-top` on
  `#quarto-margin-sidebar` rests it below a tall site header.
- **Breakout elements** (wider than the text column): apply width +
  negative-margin centring on the OUTER wrapper (`div.sourceCode`), never
  on an element inside an `overflow` container — transforms inside scroll
  containers clip instead of breaking out.

## The verification loop

Render, serve `_site` locally, screenshot old-live vs new-local with a
headless browser at identical viewport sizes, compare, adjust SCSS,
repeat. Pay attention to: menu wrapping, title sizes, link colours in all
states, blockquote/table styling, code font/size, footer. Expect three or
four iterations before they're indistinguishable.
