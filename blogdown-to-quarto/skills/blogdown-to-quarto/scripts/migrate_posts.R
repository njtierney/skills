#!/usr/bin/env Rscript
# Migrate blogdown/hugodown posts to a Quarto posts/ directory.
#
# Uses each post's already-rendered output (never re-executes R code),
# cleans Hugo-era frontmatter, adds an old-URL alias derived from the
# FRONTMATTER date + slug, copies asset dirs and static figure dirs
# (rewriting absolute /post/*_files/ paths), and replaces tweet/youtube
# shortcodes with plain embeds.
#
# Requires the cli and fs packages: install.packages(c("cli", "fs"))
#
# Validate aliases against the live sitemap:
#
#   curl -s https://example.com/sitemap.xml | grep -o '<loc>[^<]*' |
#     sed 's/<loc>//' > sitemap.txt
#   Rscript migrate_posts.R --content content/post --out posts \
#     --static static/post --sitemap sitemap.txt
#
# Review every warning individually; finish only when the sitemap report
# is clean (aliases <-> live URLs must match 1:1).

for (pkg in c("cli", "fs")) {
  if (!requireNamespace(pkg, quietly = TRUE)) {
    stop("The cli and fs packages are required: install.packages(c(\"cli\", \"fs\"))",
         call. = FALSE)
  }
}

# --- command line ------------------------------------------------------------

parse_args <- function(argv = commandArgs(trailingOnly = TRUE)) {
  opts <- list(
    content = NULL,
    out = NULL,
    static = NULL,
    sitemap = NULL,
    permalink_section = "post",
    drafts_dirname = "drafts",
    keep_author = FALSE,
    keep_tags = FALSE,
    dry_run = FALSE
  )
  i <- 1L
  take_value <- function() {
    if (i + 1L > length(argv)) {
      cli::cli_abort("{.arg {argv[i]}} needs a value.")
    }
    i <<- i + 1L
    argv[i]
  }
  while (i <= length(argv)) {
    switch(argv[i],
      "--content"           = opts$content <- take_value(),
      "--out"               = opts$out <- take_value(),
      "--static"            = opts$static <- take_value(),
      "--sitemap"           = opts$sitemap <- take_value(),
      "--permalink-section" = opts$permalink_section <- take_value(),
      "--drafts-dirname"    = opts$drafts_dirname <- take_value(),
      "--keep-author"       = opts$keep_author <- TRUE,
      "--keep-tags"         = opts$keep_tags <- TRUE,
      "--dry-run"           = opts$dry_run <- TRUE,
      cli::cli_abort("Unknown argument {.arg {argv[i]}}.")
    )
    i <- i + 1L
  }
  if (is.null(opts$content) || is.null(opts$out)) {
    cli::cli_abort("{.arg --content} and {.arg --out} are required.")
  }
  if (!fs::dir_exists(opts$content)) {
    cli::cli_abort("{.arg --content} directory {.path {opts$content}} does not exist.")
  }
  opts
}

# --- pure helpers: text in, text out ------------------------------------------

split_frontmatter <- function(text, src) {
  match <- regexec("(?s)^---\n(.*?)\n---\n?(.*)$", text, perl = TRUE)
  parts <- regmatches(text, match)[[1]]
  if (length(parts) != 3L) {
    cli::cli_abort("No YAML frontmatter found in {.file {src}}.")
  }
  list(yaml = parts[2], body = parts[3])
}

yaml_field <- function(yaml, pattern) {
  parts <- regmatches(yaml, regexec(pattern, yaml, perl = TRUE))[[1]]
  if (length(parts) < 2L) NULL else parts[-1]
}

clean_frontmatter <- function(yaml, alias, keep_author = FALSE, keep_tags = FALSE) {
  drop_keys <- c("output", "rmd_hash", "disable_comments", "editor_options")
  if (!keep_author) drop_keys <- c(drop_keys, "author")
  if (!keep_tags) drop_keys <- c(drop_keys, "tags")

  lines <- strsplit(yaml, "\n", fixed = TRUE)[[1]]
  kept <- character()
  in_dropped_block <- FALSE
  for (line in lines) {
    if (in_dropped_block) {
      if (grepl("^[ \t-]", line) && nzchar(trimws(line))) next
      in_dropped_block <- FALSE
    }
    key <- regmatches(line, regexec("^([A-Za-z][A-Za-z0-9_-]*):", line))[[1]]
    if (length(key) == 2L && key[2] %in% drop_keys) {
      in_dropped_block <- TRUE
      next
    }
    kept <- c(kept, line)
  }
  while (length(kept) > 0L && !nzchar(trimws(kept[length(kept)]))) {
    kept <- kept[-length(kept)]
  }
  if (!is.null(alias)) {
    kept <- c(kept, "aliases:", sprintf('  - "%s"', alias))
  }
  paste(kept, collapse = "\n")
}

# Approximate Hugo's urlize(), used as the :slug fallback
hugo_urlize <- function(title) {
  slug <- tolower(trimws(title))
  slug <- gsub("['‘’\"!?:,.()\\[\\]{}*`]", "", slug, perl = TRUE)
  slug <- gsub("[\\s/]+", "-", slug, perl = TRUE)
  gsub("^-+|-+$", "", slug)
}

# Returns list(body = <rewritten body>, unhandled = <leftover shortcodes>)
replace_shortcodes <- function(body) {
  body <- gsub("<!--html_preserve-->|<!--/html_preserve-->", "", body)
  body <- gsub(
    "\\{\\{[<%]\\s*tweet\\s*\"?(\\d+)\"?\\s*[>%]\\}\\}",
    paste0(
      '<blockquote class="twitter-tweet">',
      '<a href="https://twitter.com/i/web/status/\\1"></a></blockquote>\n',
      '<script async src="https://platform.twitter.com/widgets.js" charset="utf-8"></script>'
    ),
    body,
    perl = TRUE
  )
  body <- gsub(
    "\\{\\{[<%]\\s*youtube\\s*\"?([A-Za-z0-9_-]+)\"?\\s*[>%]\\}\\}",
    paste0(
      '<iframe src="https://www.youtube.com/embed/\\1" width="100%" ',
      'height="400" frameborder="0" allowfullscreen></iframe>'
    ),
    body,
    perl = TRUE
  )
  unhandled <- regmatches(body, gregexpr("\\{\\{[<%][^}]*[>%]\\}\\}", body, perl = TRUE))[[1]]
  list(body = body, unhandled = unhandled)
}

# --- discovery ----------------------------------------------------------------

# Posts are bundles (dirs with a rendered index.md / index.markdown;
# hugodown's index.md preferred) or loose .md/.markdown files.
collect_posts <- function(content_dir, drafts_dirname = "drafts") {
  in_drafts <- function(path) {
    drafts_dirname %in% unlist(fs::path_split(path))
  }

  posts <- list()
  seen <- character()

  bundle_dirs <- fs::dir_ls(content_dir, type = "directory", recurse = TRUE)
  for (dir in sort(bundle_dirs)) {
    if (in_drafts(dir)) next
    for (candidate in c("index.md", "index.markdown")) {
      index <- fs::path(dir, candidate)
      if (fs::file_exists(index)) {
        posts[[length(posts) + 1L]] <- list(
          src = index,
          name = fs::path_file(dir),
          bundle = dir
        )
        seen <- c(seen, fs::path_file(dir))
        break
      }
    }
  }

  loose_files <- fs::dir_ls(
    content_dir,
    type = "file",
    recurse = TRUE,
    regexp = "\\.(md|markdown)$"
  )
  for (file in sort(loose_files)) {
    name <- fs::path_ext_remove(fs::path_file(file))
    if (in_drafts(file) || startsWith(fs::path_file(file), "index.")) next
    if (name %in% seen) next  # rendered sibling of an already-collected post
    posts[[length(posts) + 1L]] <- list(src = file, name = name, bundle = NULL)
    seen <- c(seen, name)
  }

  posts
}

read_sitemap_urls <- function(sitemap_file, permalink_section) {
  if (is.null(sitemap_file)) {
    return(character())
  }
  lines <- readLines(sitemap_file, warn = FALSE)
  pattern <- sprintf("(/%s/\\d{4}/\\d{2}/\\d{2}/[^/]+/)$", permalink_section)
  hits <- regmatches(lines, regexpr(pattern, lines, perl = TRUE))
  unique(hits[nzchar(hits)])
}

# --- per-post migration ---------------------------------------------------------

resolve_alias <- function(yaml, name, permalink_section, sitemap_urls, used_urls) {
  date <- yaml_field(yaml, "(?m)^date:\\s*['\"]?(\\d{4})-(\\d{2})-(\\d{2})")
  if (is.null(date)) {
    return(list(alias = NULL, note = "no date in frontmatter"))
  }

  slug <- yaml_field(yaml, "(?m)^slug:\\s*['\"]?([^'\"\n]+)")
  if (!is.null(slug)) {
    slug <- trimws(slug[1])
  } else {
    title <- yaml_field(yaml, "(?m)^title:\\s*['\"]?(.+?)['\"]?\\s*$")
    slug <- if (!is.null(title)) {
      hugo_urlize(title[1])
    } else {
      sub("^\\d{4}-\\d{2}-\\d{2}-", "", name)
    }
  }

  alias <- sprintf("/%s/%s/%s/%s/%s/", permalink_section, date[1], date[2], date[3], slug)
  note <- NULL

  if (length(sitemap_urls) > 0L && !(alias %in% sitemap_urls)) {
    same_day <- sprintf("/%s/%s/%s/%s/", permalink_section, date[1], date[2], date[3])
    candidates <- setdiff(sitemap_urls[startsWith(sitemap_urls, same_day)], used_urls)
    if (length(candidates) == 1L) {
      note <- sprintf("alias corrected via sitemap: %s -> %s", alias, candidates)
      alias <- candidates
    } else {
      note <- sprintf("no unique sitemap match for %s", alias)
    }
  }

  list(alias = alias, note = note)
}

copy_bundle_assets <- function(bundle, out_dir) {
  for (item in fs::dir_ls(bundle)) {
    item_name <- fs::path_file(item)
    if (fs::is_dir(item)) {
      fs::dir_copy(item, fs::path(out_dir, item_name), overwrite = TRUE)
    } else if (!startsWith(item_name, "index.") && !startsWith(item_name, ".")) {
      fs::file_copy(item, out_dir, overwrite = TRUE)
    }
  }
  invisible(out_dir)
}

# Copies referenced static figure dirs into the post and returns the body
# with those references rewritten to relative paths.
relocate_static_figures <- function(body, out_dir, static_dir, permalink_section) {
  pattern <- sprintf("/%s/([A-Za-z0-9._-]+_files)/", permalink_section)
  refs <- unique(unlist(regmatches(body, gregexpr(pattern, body, perl = TRUE))))
  missing <- character()

  for (ref in refs) {
    figure_dir <- sub(pattern, "\\1", ref, perl = TRUE)
    source_dir <- if (!is.null(static_dir)) fs::path(static_dir, figure_dir) else NULL
    if (!is.null(source_dir) && fs::dir_exists(source_dir)) {
      fs::dir_copy(source_dir, fs::path(out_dir, figure_dir), overwrite = TRUE)
      body <- gsub(ref, sprintf("%s/", figure_dir), body, fixed = TRUE)
    } else {
      missing <- c(missing, figure_dir)
    }
  }

  list(body = body, missing = missing)
}

migrate_post <- function(post, opts, sitemap_urls, used_urls) {
  out_dir <- fs::path(opts$out, post$name)
  if (fs::dir_exists(out_dir)) {
    return(list(name = post$name, status = "exists"))
  }

  parts <- split_frontmatter(
    paste(readLines(post$src, warn = FALSE), collapse = "\n"),
    post$src
  )

  if (grepl("(?m)^draft:\\s*(yes|true)\\s*$", parts$yaml, perl = TRUE)) {
    return(list(name = post$name, status = "draft"))
  }

  resolved <- resolve_alias(
    parts$yaml, post$name, opts$permalink_section, sitemap_urls, used_urls
  )
  if (!is.null(resolved$note)) {
    cli::cli_alert_warning("{.file {post$name}}: {resolved$note}")
  }
  if (is.null(resolved$alias)) {
    return(list(name = post$name, status = "skipped"))
  }

  yaml <- clean_frontmatter(
    parts$yaml, resolved$alias,
    keep_author = opts$keep_author, keep_tags = opts$keep_tags
  )
  shortcodes <- replace_shortcodes(parts$body)
  for (leftover in shortcodes$unhandled) {
    cli::cli_alert_warning("{.file {post$name}}: unhandled shortcode {.code {leftover}}")
  }

  if (opts$dry_run) {
    cli::cli_alert_info("would migrate {.file {post$name}} (alias {.url {resolved$alias}})")
    return(list(name = post$name, status = "migrated", alias = resolved$alias))
  }

  fs::dir_create(out_dir)
  if (!is.null(post$bundle)) {
    copy_bundle_assets(post$bundle, out_dir)
  }

  figures <- relocate_static_figures(
    shortcodes$body, out_dir, opts$static, opts$permalink_section
  )
  for (figure_dir in figures$missing) {
    cli::cli_alert_warning(
      "{.file {post$name}}: figure dir {.path {figure_dir}} not found under {.arg --static}"
    )
  }

  writeLines(
    sprintf("---\n%s\n---\n%s", yaml, figures$body),
    fs::path(out_dir, "index.md")
  )
  cli::cli_alert_success("migrated {.file {post$name}} (alias {.url {resolved$alias}})")
  list(name = post$name, status = "migrated", alias = resolved$alias)
}

# --- reporting ------------------------------------------------------------------

report_migration <- function(results, sitemap_urls) {
  status <- vapply(results, function(x) x$status, character(1))
  aliases <- unlist(lapply(results, function(x) x$alias))
  drafts <- vapply(results[status == "draft"], function(x) x$name, character(1))

  cli::cli_h1("Migration summary")
  cli::cli_bullets(c(
    "*" = "migrated: {sum(status == 'migrated')}",
    "*" = "already present: {sum(status == 'exists')}",
    "*" = "drafts skipped: {length(drafts)}"
  ))
  if (length(drafts) > 0L) {
    cli::cli_alert_info("drafts: {.file {drafts}}")
  }

  if (length(sitemap_urls) > 0L) {
    missing <- setdiff(sitemap_urls, aliases)
    extra <- setdiff(aliases, sitemap_urls)
    cli::cli_h2("Sitemap report")
    if (length(missing) == 0L && length(extra) == 0L) {
      cli::cli_alert_success("aliases and live URLs match 1:1")
    } else {
      if (length(missing) > 0L) {
        cli::cli_alert_danger("live URLs missing an alias: {.url {missing}}")
      }
      if (length(extra) > 0L) {
        cli::cli_alert_danger("aliases not on the live site: {.url {extra}}")
      }
      cli::cli_alert_warning("investigate each mismatch before continuing (see SKILL.md)")
    }
  }

  invisible(results)
}

# --- migrate all posts and report -------------------------------------------------

migrate_all_posts_and_report <- function() {
  opts <- parse_args()

  sitemap_urls <- read_sitemap_urls(opts$sitemap, opts$permalink_section)
  if (length(sitemap_urls) > 0L) {
    cli::cli_alert_info("live post URLs in sitemap: {length(sitemap_urls)}")
  }

  posts <- collect_posts(opts$content, opts$drafts_dirname)
  cli::cli_alert_info("posts discovered: {length(posts)}")

  results <- list()
  used_urls <- character()
  for (post in posts) {
    result <- migrate_post(post, opts, sitemap_urls, used_urls)
    if (!is.null(result$alias)) {
      used_urls <- c(used_urls, result$alias)
    }
    results[[length(results) + 1L]] <- result
  }

  report_migration(results, sitemap_urls)
}

migrate_all_posts_and_report()
