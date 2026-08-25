#!/bin/bash
# collect2.sh — fetch and validate every child sitemap listed in the index.
#
# collect.sh checked only the sitemap index. Google can read an index
# successfully and still fail on a sitemap referenced inside it, so this
# checks each child individually.
#
# Run from inside the repo on the SiteGround server:
#     cd ~/review && bash collect2.sh

set -u
cd "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)" || exit 1

DOMAIN="${1:-almamater-mahjongg.com}"
UA="Mozilla/5.0 (compatible; Googlebot/2.1; +http://www.google.com/bot.html)"
INDEX="05-seo-output/sitemap_index-body.xml"
OUT="05-seo-output/child-sitemaps.txt"
: > "$OUT"

say() { echo "$*" | tee -a "$OUT"; }

status_of() { awk 'BEGIN{IGNORECASE=1} /^HTTP\//{c=$2} END{print c}' "$1" 2>/dev/null; }

say "=== Child sitemap check ==="
say "Date: $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
say ""

if [ ! -s "$INDEX" ]; then
  say "!! $INDEX missing or empty. Run collect.sh first."
  exit 1
fi

LOCS="$(grep -oE '<loc>[^<]+</loc>' "$INDEX" | sed -e 's/<loc>//' -e 's|</loc>||')"

if [ -z "$LOCS" ]; then
  say "!! No <loc> entries found in the index."
  exit 1
fi

say "Found $(echo "$LOCS" | wc -l) child sitemaps."
say ""

for url in $LOCS; do
  name="$(basename "$url" .xml)"
  hdr="05-seo-output/child-${name}-headers.txt"
  body="05-seo-output/child-${name}-body.xml"

  curl -sS -L --max-time 30 -A "$UA" -D "$hdr" -o "$body" "$url" 2>/dev/null

  code="$(status_of "$hdr")"
  size="$(wc -c < "$body" 2>/dev/null || echo 0)"
  entries="$(grep -o '<url>' "$body" 2>/dev/null | wc -l)"
  ct="$(grep -i '^content-type:' "$hdr" 2>/dev/null | tail -1 | tr -d '\r')"
  xrt="$(grep -i '^x-robots-tag:' "$hdr" 2>/dev/null | tail -1 | tr -d '\r')"
  redir="$(grep -ci '^HTTP/' "$hdr" 2>/dev/null)"

  say "--- $name"
  say "    url:     $url"
  say "    status:  ${code:-000}    size: ${size}B    <url> entries: ${entries}"
  [ -n "$ct" ]  && say "    ${ct}"
  [ -n "$xrt" ] && say "    ${xrt}"
  [ "${redir:-1}" -gt 1 ] && say "    note: ${redir} responses - redirect chain present"

  if [ "$(head -c 5 "$body" 2>/dev/null)" = "<?xml" ]; then
    say "    OK  starts with <?xml"
  else
    say "    !!  does NOT start with <?xml"
    say "    !!  first bytes: $(head -c 100 "$body" 2>/dev/null | tr '\n' ' ')"
  fi

  if [ "${entries:-0}" -eq 0 ] && [ "${code:-000}" = "200" ]; then
    say "    !!  200 OK but contains zero <url> entries - empty sitemap"
  fi
  say ""
done

# SiteGround's nginx proxy cache showed HIT on the index. Re-request with a
# cache-buster to confirm the cached copy matches what WordPress generates.
say "=== Cache-bypass re-fetch of the index ==="
curl -sS -L --max-time 30 -A "$UA" -H "Cache-Control: no-cache" \
     -D 05-seo-output/index-nocache-headers.txt \
     -o 05-seo-output/index-nocache-body.xml \
     "https://${DOMAIN}/sitemap_index.xml?cachebust=$$" 2>/dev/null

say "status: $(status_of 05-seo-output/index-nocache-headers.txt)"
say "size:   $(wc -c < 05-seo-output/index-nocache-body.xml 2>/dev/null || echo 0)B"

if diff -q "$INDEX" 05-seo-output/index-nocache-body.xml >/dev/null 2>&1; then
  say "cached copy matches freshly generated output"
else
  say "!! cached copy DIFFERS from freshly generated output - stale cache"
fi
say ""
say "=== Done ==="
say ""
say "Next: git add -A && git commit -m 'Add child sitemap check' && git push"
