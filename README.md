# AlmaMater-mahjongg.com — Technical SEO & Code Review

Intake repository for reviewing the live WordPress site
(Divi + WPCode, hosted on SiteGround).

This repo holds **exported copies** of site code and output for review.
It is not a deployment target — nothing here is pushed back to the live
site automatically. You apply fixes in WordPress yourself.

## Why this repo exists

The review session cannot reach `almamater-mahjongg.com` over the network
(blocked by the environment's egress policy), so the code and output are
brought here instead.

## Review scope

1. **Sitemap fetch failure** — Google Search Console reports "Couldn't fetch"
   on the submitted XML sitemap.
2. **Pasted code audit** — WPCode snippets and Divi Code modules, with
   attention to duplicated analytics, conflicting schema, and stray output
   that can corrupt XML responses.
3. **Full technical SEO** — titles, meta descriptions, heading structure,
   canonicals, schema, internal linking, image alt text, indexability.
4. **Speed / Core Web Vitals** — Divi's default payload plus SiteGround
   caching and optimization configuration.

## What goes where

| Folder | Contents |
|---|---|
| `01-wpcode-snippets/` | WPCode export JSON, or one `.php`/`.js` file per snippet |
| `02-divi-code-modules/` | Divi Library / layout export JSON, Theme Options → Integration code |
| `03-theme/` | Child theme `functions.php`, `style.css`, custom templates |
| `04-server-config/` | `.htaccess`, `robots.txt` output, PHP/server settings |
| `05-seo-output/` | Sitemap XML dumps, GSC exports, PageSpeed reports, plugin list |
| `06-page-source/` | Saved View Source of the homepage and key pages |

**Start here:** [`EXTRACTION-GUIDE.md`](EXTRACTION-GUIDE.md) has click-by-click
steps for pulling each item out of WordPress and SiteGround.

## Security

`.gitignore` blocks `wp-config.php`, database dumps, `.env` files, and key
files. **Do not commit database credentials, API keys, or auth salts.**
If a file you need to share contains a secret, redact the value and replace
it with `REDACTED` before committing — the structure is what matters for
review, not the secret itself.

## Priority order

The sitemap fix is the fastest win and needs the least data. If you only
have time for one thing right now, do **Steps 1, 5, and 6** in the
extraction guide — that is usually enough to identify the cause.
