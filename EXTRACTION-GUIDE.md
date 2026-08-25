# Extraction Guide

Click-by-click steps for getting each piece of the site into this repo.
You do not have to do these in order, but **Steps 1, 5, and 6 matter most**
for the sitemap error.

If a step doesn't match what you see, the plugin version differs — grab the
closest equivalent and note the difference. Partial data is still useful.

---

## Step 1 — WPCode snippets → `01-wpcode-snippets/`

This is the highest-value export. It is very likely where the sitemap
problem lives.

**Preferred (one file, everything):**

1. WordPress admin → **Code Snippets → Tools**
2. Open the **Export** tab
3. Select all snippets → **Export**
4. Drop the downloaded `.json` into `01-wpcode-snippets/`

**If Tools → Export isn't there** (older WPCode / Lite builds), do it manually:

1. **Code Snippets → All Snippets**
2. Open each snippet, copy the code body
3. Save one file per snippet, named `NN-snippet-title.php` (or `.js`/`.css`)
4. At the top of each file, add a comment recording its settings:

```php
<?php
// TITLE:     Google Analytics tag
// TYPE:      PHP Snippet          (PHP / HTML / JS / CSS / Universal)
// LOCATION:  Site Wide Header     (exact "Location" dropdown value)
// PRIORITY:  10
// STATUS:    Active               (Active / Inactive)
// DEVICE:    Any
```

The **Location** and **Type** values are as important as the code itself —
a PHP snippet running site-wide is what corrupts XML responses.

Also record the total count of snippets, active and inactive, in
`01-wpcode-snippets/README.md`.

---

## Step 2 — Divi code → `02-divi-code-modules/`

**Theme Options integration code (do this one manually — it's short):**

1. **Divi → Theme Options → Integration** tab
2. Copy the contents of each of the four boxes into
   `02-divi-code-modules/theme-options-integration.txt`, labeling each:
   - Add code to the `<head>` of your blog
   - Add code to the `<body>`
   - Add code to the top of your posts
   - Add code to the bottom of your posts

This is a very common place for a duplicate analytics tag to hide.

**Page layouts containing Code modules:**

1. Open a page in the **Divi Visual Builder**
2. Click the **`⋯`** (three dots) at the bottom center to expand the toolbar
3. Click the **Portability** icon (two arrows / up-down arrows)
4. **Export** tab → name it → **Export Divi Builder Layout**
5. Drop the `.json` into `02-divi-code-modules/`

Repeat for the homepage and any page where you pasted code. Alternatively,
**Divi → Divi Library → Portability → Export** grabs saved layouts in bulk.

---

## Step 3 — Theme files → `03-theme/`

Access either through **SiteGround Site Tools → Site → File Manager**, or
**Appearance → Theme File Editor** in WordPress.

Copy in whichever of these exist:

- `functions.php` from your **child theme** (`/wp-content/themes/divi-child/`)
- `style.css` from the child theme
- Any custom page templates you or ChatGPT added
- If you edited the **parent** Divi theme directly, say so in
  `03-theme/README.md` — that is its own problem, since Divi updates
  overwrite it.

If you have no child theme at all, note that too.

---

## Step 4 — Server config → `04-server-config/`

**`.htaccess`** (site root, `public_html/`):

1. SiteGround **Site Tools → Site → File Manager**
2. Enable **show hidden files** (leading-dot files are hidden by default)
3. Open `.htaccess`, copy the whole thing into `04-server-config/htaccess.txt`

Name it `htaccess.txt`, not `.htaccess` — a real dotfile in the repo root
could confuse tooling.

**`wp-config.php` — do NOT commit this file.** It holds your database
password and auth salts, and `.gitignore` blocks it. Instead, open it and
report just these constants (values only, no secrets) in
`04-server-config/wp-config-constants.txt`:

```
WP_HOME           = ?
WP_SITEURL        = ?
WP_CACHE          = ?
WP_DEBUG          = ?
WP_MEMORY_LIMIT   = ?
FORCE_SSL_ADMIN   = ?
```

If any are absent, write `not set`. `WP_HOME` / `WP_SITEURL` matter directly
to the www-vs-non-www question behind many sitemap fetch failures.

**PHP version:** SiteGround **Site Tools → Devs → PHP Manager**. Record it.

---

## Step 5 — SEO output → `05-seo-output/`

**The sitemap itself (most important single item):**

1. Open your sitemap URL in a browser. Depending on your SEO plugin it is one of:
   - Yoast SEO → `/sitemap_index.xml`
   - Rank Math → `/sitemap_index.xml`
   - All in One SEO → `/sitemap.xml`
   - WordPress core, no SEO plugin → `/wp-sitemap.xml`
2. **View Source** (`Ctrl+U` on Windows, `Cmd+Opt+U` on Mac) — the raw
   source, not the rendered page
3. Save the **entire** output to `05-seo-output/sitemap-index-viewsource.xml`

Preserve the very beginning of the file exactly. Whether anything appears
before `<?xml` is the single most diagnostic detail in this whole repo — do
not trim leading blank lines when you paste.

4. Do the same for one **child** sitemap listed inside the index (e.g.
   `page-sitemap.xml`), saved as `sitemap-child-viewsource.xml`. Google can
   fetch an index fine and still fail on a child.

**robots.txt:** visit `/robots.txt`, save to `05-seo-output/robots.txt`.
It's usually generated by the SEO plugin rather than being a real file, so
save what the browser shows.

**Google Search Console:**

- Screenshot the **Sitemaps** page showing the status and the exact URL you submitted
- Note the **exact property name** as GSC displays it (`https://` vs `http://`,
  `www.` vs bare, or "Domain property") in `05-seo-output/gsc-notes.txt`
- Pages report → **Export** → drop the CSV in

**Plugin + settings inventory** → `05-seo-output/plugins-and-settings.txt`:

- Full active plugin list (**Plugins → Installed Plugins**)
- Which SEO plugin, and whether more than one is installed
- **Settings → Reading** → is *"Discourage search engines from indexing this site"*
  checked? Check this now regardless — it is a common post-launch mistake and
  a 5-second fix.
- SG Optimizer: which caching and optimization toggles are on
- Whether SiteGround's Cloudflare integration is enabled

**PageSpeed Insights:** run https://pagespeed.web.dev/ against your homepage
and one interior page, and save the report URLs to
`05-seo-output/pagespeed-urls.txt`.

---

## Step 6 — Page source → `06-page-source/`

For the homepage plus 2–4 important pages:

1. Open the page in a browser
2. **View Source** (`Ctrl+U` / `Cmd+Opt+U`)
3. Save the complete HTML as `06-page-source/homepage.html`, `about.html`, etc.

Use View Source, not "Save Page As" and not DevTools' Elements panel —
we need the raw server response, before JavaScript modifies the DOM. This
is what reveals duplicate analytics tags, conflicting canonicals, doubled
schema blocks, and title/meta problems.

---

## Committing

```
git add -A
git commit -m "Add site export for review"
git push -u origin claude/almamater-sitemap-indexing-m1plnj
```

Before pushing, skim the diff for anything sensitive:

```
git diff --cached | grep -iE "password|passwd|api[_-]?key|secret|token|salt"
```

Redact anything that turns up, replacing the value with `REDACTED`.
