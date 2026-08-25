# SEO Output

Expected files:

- `sitemap-index-viewsource.xml` — raw View Source of the sitemap index
- `sitemap-child-viewsource.xml` — raw View Source of one child sitemap
- `robots.txt` — what the browser shows at /robots.txt
- `gsc-notes.txt` — exact GSC property name, exact submitted sitemap path,
  exact error text, submission date
- `plugins-and-settings.txt` — plugin list and the settings inventory
- `pagespeed-urls.txt` — PageSpeed Insights report links
- GSC Pages report CSV export
- Screenshot of the GSC Sitemaps page

**Critical:** when saving the sitemap View Source, preserve the start of the
file byte for byte. Do not trim leading blank lines. Whether anything
precedes `<?xml` is the key diagnostic signal.
