# Sitemap "Couldn't fetch" — Triage

Work these in order. Most cases resolve at step 1 or 2. You can do all of
this before any code lands in the repo.

---

## 0. Confirm it's actually broken

"Couldn't fetch" is sometimes a transient or pending state that clears on
its own. Before changing anything, open the sitemap URL in a browser. If it
loads clean XML, resubmit and give it a few days.

Everything below assumes it does *not* load clean.

---

## 1. Is something printed before the `<?xml` declaration?

An XML sitemap must begin with `<?xml` as the **very first byte**. Any PHP
snippet that echoes output — a stray blank line, a `?>` followed by
whitespace, an HTML comment, a tracking `<script>` — gets prepended and the
parser fails. Google reports that as "Couldn't fetch."

Given a lot of pasted PHP running through WPCode, this is the leading suspect.

**Test:** open the sitemap URL, then **View Source** (`Ctrl+U` / `Cmd+Opt+U`).
Not the rendered view — the raw source.

Confirmed if you see:
- anything at all before `<?xml`, or
- the browser error *"XML declaration allowed only at the start of the document"*, or
- a blank line or stray character at the very top

**Find the culprit:** WPCode → Code Snippets → deactivate all → reload the
sitemap. Fixed? Reactivate one at a time until it breaks again.

**Fix it properly:**
- Delete the trailing `?>` from the snippet entirely. A closing PHP tag is
  never required at the end of a file, and any whitespace after it is sent
  straight to the browser.
- Check the snippet's **Location**. A PHP snippet set to run site-wide
  executes on XML responses too. Scope it to where it's actually needed.
- Remove any `echo`, `print`, or raw HTML outside a hook callback. Code that
  outputs at load time rather than inside an action is the usual offender.

---

## 2. Property and URL mismatch

Search Console treats `http://`, `https://`, `www.`, and bare domain as
**four different properties**. If the property is the non-www version but the
site 301-redirects to `www` (or the reverse), the sitemap fetch redirects
off-property and fails.

**Check:** does the exact sitemap URL you submitted load without changing the
address bar? If the domain shifts, that's the problem.

**Confirm the filename matches your plugin:**

| Plugin | Sitemap URL |
|---|---|
| Yoast SEO | `/sitemap_index.xml` |
| Rank Math | `/sitemap_index.xml` |
| All in One SEO | `/sitemap.xml` |
| WordPress core (no SEO plugin) | `/wp-sitemap.xml` |

Submitting `/sitemap.xml` while Yoast generates `/sitemap_index.xml` is the
most common form of this error. GSC takes only the path after the domain.

**Best fix:** add a **Domain property** (DNS-verified) in Search Console. It
covers every protocol and subdomain at once and eliminates this whole class
of problem permanently.

---

## 3. The launch checkbox

**Settings → Reading → "Discourage search engines from indexing this site"**

If still checked from pre-launch, WordPress serves `Disallow: /` in robots.txt
and adds `noindex` sitewide. Five seconds to check, and it's a common miss on
a freshly launched site.

While you're there, confirm `/robots.txt` doesn't disallow the sitemap path
or block Googlebot.

---

## 4. SiteGround-specific causes

- **SG Optimizer** may serve the sitemap from cache with a stale or incorrect
  `Content-Type`. It must be `application/xml` or `text/xml`, never
  `text/html`. Purge the cache, then re-test.
- **SiteGround Security / WAF** can return 403 to crawler user-agents. Check
  the security logs around your submission time.
- **Cloudflare integration** — bot-fight and challenge settings can block
  Googlebot. Verify Googlebot is allowed if you enabled it.
- An `X-Robots-Tag: noindex` response header on the sitemap will also cause
  a fetch failure.

---

## 5. Child sitemap failures

Google can fetch the sitemap *index* successfully and still fail on one of
the child sitemaps it references. Open each child sitemap listed inside the
index and confirm every one returns clean XML.

---

## Related but separate: only the homepage is indexed

This is most likely not a bug. On a site launched this recently, having only
the homepage indexed is normal — indexing is a queue, not a switch, and the
rest commonly takes days to weeks.

Use **URL Inspection → Request Indexing** on your 3–5 most important pages to
prioritize them. Don't read low coverage as a technical failure yet; fix the
sitemap, then give it time.

---

## References

- https://wpstoreplus.com/fix-wordpress-sitemap-couldnt-fetch-error/
- https://digital4africa.com/search-console-sitemap-couldnt-fetch/
