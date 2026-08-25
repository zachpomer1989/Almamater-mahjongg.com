#!/bin/bash
# collect.sh — gather site files and diagnostics for review.
#
# Run this ON the SiteGround server, from inside the cloned repo:
#     cd ~/review && bash collect.sh
#
# Optionally pass the domain if auto-detection picks the wrong one:
#     bash collect.sh almamater-mahjongg.com
#
# READ-ONLY against your site. It copies files and records output into
# this repo's folders. It never modifies WordPress, and it never reads
# database passwords or auth salts.

set -u

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$REPO_DIR" || { echo "cannot cd to repo dir"; exit 1; }

DOMAIN="${1:-almamater-mahjongg.com}"
SUMMARY="05-seo-output/collection-summary.txt"
: > "$SUMMARY"

say() { echo "$*" | tee -a "$SUMMARY"; }

say "=== Collection run ==="
say "Date:   $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
say "Domain: $DOMAIN"
say "Host:   $(hostname 2>/dev/null || echo unknown)"
say ""

# ── Locate the WordPress install ────────────────────────────────────
SITE=""
for c in "$HOME"/www/*/public_html "$HOME"/public_html "$HOME"/www/*/public_html/*; do
  if [ -f "$c/wp-config.php" ]; then SITE="$c"; break; fi
done

if [ -z "$SITE" ]; then
  say "!! Could not auto-locate wp-config.php."
  say "   Find it with:  find ~ -maxdepth 5 -name wp-config.php 2>/dev/null"
  say "   Then re-run after setting:  export SITE=/path/to/public_html"
  SITE="${SITE:-}"
else
  say "WordPress root: $SITE"
fi
say ""

# ── 1. Server config ────────────────────────────────────────────────
say "--- Server config ---"
if [ -n "$SITE" ] && [ -f "$SITE/.htaccess" ]; then
  cp "$SITE/.htaccess" 04-server-config/htaccess.txt && say "OK  .htaccess copied"
else
  say "--  .htaccess not found"
fi

# Whitelist ONLY non-secret constants. Never touch DB_PASSWORD or salts.
if [ -n "$SITE" ] && [ -f "$SITE/wp-config.php" ]; then
  grep -E "define\s*\(\s*'(WP_HOME|WP_SITEURL|WP_CACHE|WP_DEBUG|WP_DEBUG_LOG|WP_MEMORY_LIMIT|FORCE_SSL_ADMIN|DISALLOW_FILE_EDIT|WP_POST_REVISIONS|AUTOSAVE_INTERVAL)'" \
    "$SITE/wp-config.php" > 04-server-config/wp-config-constants.txt 2>/dev/null
  say "OK  wp-config constants extracted (secrets excluded)"
fi

{
  echo "PHP CLI version: $(php -v 2>/dev/null | head -1)"
  echo "Server:          $(uname -a 2>/dev/null)"
} > 04-server-config/environment.txt 2>/dev/null
say "OK  environment recorded"
say ""

# ── 2. Theme files ──────────────────────────────────────────────────
say "--- Theme ---"
if [ -n "$SITE" ]; then
  for t in "$SITE"/wp-content/themes/*/; do
    name="$(basename "$t")"
    # Child themes declare a Template: header pointing at the parent
    if [ -f "$t/style.css" ] && grep -qi "^[[:space:]]*Template:" "$t/style.css" 2>/dev/null; then
      say "OK  child theme found: $name"
      mkdir -p "03-theme/$name"
      [ -f "$t/functions.php" ] && cp "$t/functions.php" "03-theme/$name/"
      cp "$t/style.css" "03-theme/$name/" 2>/dev/null
      # Custom templates only — skip anything huge
      find "$t" -maxdepth 1 -name "*.php" ! -name "functions.php" -size -200k \
        -exec cp {} "03-theme/$name/" \; 2>/dev/null
    fi
  done
  ls -1 "$SITE"/wp-content/themes/ > 03-theme/installed-themes.txt 2>/dev/null
  say "OK  theme list recorded"
fi
say ""

# ── 3. WordPress state via WP-CLI ───────────────────────────────────
say "--- WordPress state ---"
if command -v wp >/dev/null 2>&1 && [ -n "$SITE" ]; then
  WP="wp --path=$SITE --skip-plugins --skip-themes"

  $WP plugin list --format=csv > 05-seo-output/plugins.csv 2>/dev/null \
    && say "OK  plugin list captured"

  {
    echo "=== Core ==="
    echo "WP version:  $(wp --path="$SITE" core version 2>/dev/null)"
    echo ""
    echo "=== URLs (www vs non-www matters for Search Console) ==="
    echo "home:        $(wp --path="$SITE" option get home 2>/dev/null)"
    echo "siteurl:     $(wp --path="$SITE" option get siteurl 2>/dev/null)"
    echo ""
    echo "=== Indexability ==="
    bp="$(wp --path="$SITE" option get blog_public 2>/dev/null)"
    echo "blog_public: $bp"
    if [ "$bp" = "0" ]; then
      echo ">>> PROBLEM: 'Discourage search engines' is ON. This blocks indexing sitewide."
    else
      echo "    OK - search engines are not discouraged."
    fi
    echo ""
    echo "=== Permalinks ==="
    echo "structure:   $(wp --path="$SITE" option get permalink_structure 2>/dev/null)"
  } > 05-seo-output/wp-state.txt 2>/dev/null
  say "OK  WordPress state captured"

  # blog_public surfaced in the console too - it's a 5-second fix
  bp="$(wp --path="$SITE" option get blog_public 2>/dev/null)"
  [ "$bp" = "0" ] && say "!!  'Discourage search engines' is ON - fix in Settings > Reading"
else
  say "--  wp-cli not available; capture plugin list manually"
fi
say ""

# ── 4. Sitemap + robots, with response headers ──────────────────────
say "--- Sitemap / robots (with headers) ---"
fetch() {
  local url="$1" out="$2" hdr="$3"
  curl -sS -L --max-time 30 -A "Mozilla/5.0 (compatible; Googlebot/2.1; +http://www.google.com/bot.html)" \
       -D "$hdr" -o "$out" "$url" 2>/dev/null
  local code
  code="$(awk 'BEGIN{IGNORECASE=1} /^HTTP\//{c=$2} END{print c}' "$hdr" 2>/dev/null)"
  echo "${code:-000}"
}

for path in sitemap_index.xml sitemap.xml wp-sitemap.xml; do
  base="${path%%.*}"
  code="$(fetch "https://$DOMAIN/$path" "05-seo-output/${base}-body.xml" "05-seo-output/${base}-headers.txt")"
  size="$(wc -c < "05-seo-output/${base}-body.xml" 2>/dev/null || echo 0)"
  if [ "$code" = "200" ]; then
    say "OK  /$path -> HTTP 200 (${size} bytes)"
    # The decisive check: is <?xml the very first thing in the file?
    first="$(head -c 5 "05-seo-output/${base}-body.xml" 2>/dev/null)"
    if [ "$first" = "<?xml" ]; then
      say "    starts with <?xml - clean"
    else
      say "    !! DOES NOT start with <?xml - this breaks the sitemap"
      say "    !! first bytes: $(head -c 60 "05-seo-output/${base}-body.xml" | tr '\n' ' ')"
    fi
  else
    say "--  /$path -> HTTP $code"
    rm -f "05-seo-output/${base}-body.xml" "05-seo-output/${base}-headers.txt"
  fi
done

fetch "https://$DOMAIN/robots.txt" "05-seo-output/robots.txt" "05-seo-output/robots-headers.txt" >/dev/null
say "OK  robots.txt fetched"
say ""

# ── 5. Homepage source ──────────────────────────────────────────────
say "--- Page source ---"
fetch "https://$DOMAIN/" "06-page-source/homepage.html" "06-page-source/homepage-headers.txt" >/dev/null
say "OK  homepage fetched"
say ""

say "=== Done ==="
say ""
say "Note: these fetches ran from the server itself, so they may bypass"
say "Cloudflare or the WAF. Also save a browser View Source of the sitemap"
say "for comparison - a difference between the two is itself a finding."
say ""
say "Next:"
say "  1. Add WPCode export JSON  -> 01-wpcode-snippets/"
say "  2. Add Divi layout exports -> 02-divi-code-modules/"
say "  3. git add -A && git commit -m 'Add site export' && git push"
