#!/bin/bash
# collect5.sh — indexability audit of every URL in the sitemap.
#
# Fetches each URL as Googlebot and reports the signals that decide whether
# Google will index it: HTTP status, the robots meta tag, whether the
# canonical points at itself, and whether a title and meta description
# exist. A page that is noindex, canonicalised elsewhere, or non-200 will
# never appear in search no matter how long you wait.
#
# Run from inside the repo on the SiteGround server:
#     cd ~/review && bash collect5.sh
#
# READ-ONLY over HTTP. Writes only into 05-seo-output/.

set -u
cd "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)" || exit 1

DOMAIN="${1:-almamater-mahjongg.com}"
UA="Mozilla/5.0 (compatible; Googlebot/2.1; +http://www.google.com/bot.html)"
OUT="05-seo-output/indexability.txt"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
: > "$OUT"
say() { echo "$*" | tee -a "$OUT"; }

say "=== Indexability audit ==="
say "Date: $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
say ""

# ── Gather every URL from the sitemap index and its children ────────
curl -sS -L --max-time 30 -A "$UA" "https://${DOMAIN}/sitemap_index.xml" -o "$TMP/index.xml" 2>/dev/null
CHILDREN="$(grep -oE '<loc>[^<]+</loc>' "$TMP/index.xml" | sed -e 's/<loc>//' -e 's|</loc>||')"

: > "$TMP/urls.txt"
for c in $CHILDREN; do
  curl -sS -L --max-time 30 -A "$UA" "$c" -o "$TMP/child.xml" 2>/dev/null
  grep -oE '<loc>[^<]+</loc>' "$TMP/child.xml" | sed -e 's/<loc>//' -e 's|</loc>||' >> "$TMP/urls.txt"
done

TOTAL=$(wc -l < "$TMP/urls.txt")
say "URLs in sitemap: $TOTAL"
say ""
say "STATUS  ROBOTS                 CANON  DESC  TITLE  WORDS  URL"
say "------  ---------------------  -----  ----  -----  -----  ---"

noindex=0; badcanon=0; nodesc=0; notok=0; thin=0

while IFS= read -r url; do
  [ -z "$url" ] && continue
  body="$TMP/page.html"
  code=$(curl -sS -L --max-time 30 -A "$UA" -o "$body" -w '%{http_code}' "$url" 2>/dev/null)

  # Yoast emits single-quoted attributes; match either.
  robots=$(grep -oiE "<meta[^>]+name=['\"]robots['\"][^>]*>" "$body" 2>/dev/null \
           | grep -oiE "content=['\"][^'\"]*" | head -1 | sed -e "s/content=['\"]//" \
           | cut -c1-21)
  [ -z "$robots" ] && robots="(none)"

  canon=$(grep -oiE "<link[^>]+rel=['\"]canonical['\"][^>]*>" "$body" 2>/dev/null \
          | grep -oiE "href=['\"][^'\"]*" | head -1 | sed -e "s/href=['\"]//")

  if [ -z "$canon" ]; then cflag="none"; badcanon=$((badcanon+1))
  elif [ "${canon%/}" = "${url%/}" ]; then cflag="self"
  else cflag="OTHER"; badcanon=$((badcanon+1)); fi

  if grep -qiE "<meta[^>]+name=['\"]description['\"]" "$body" 2>/dev/null; then dflag="yes"
  else dflag="NO"; nodesc=$((nodesc+1)); fi

  tlen=$(grep -oiE "<title>[^<]*</title>" "$body" 2>/dev/null | head -1 | sed -e 's/<[^>]*>//g' | wc -c)

  # Strip script/style then all tags to approximate the visible word count.
  # Google declines to index thin pages regardless of technical correctness.
  words=$(sed -e 's/<script[^>]*>.*<\/script>//g' -e 's/<style[^>]*>.*<\/style>//g' "$body" 2>/dev/null \
          | sed -e 's/<[^>]*>/ /g' | tr -s '[:space:]' ' ' | wc -w)
  [ "${words:-0}" -lt 200 ] && thin=$((thin+1))

  case "$robots" in *noindex*) noindex=$((noindex+1)) ;; esac
  [ "$code" != "200" ] && notok=$((notok+1))

  printf "%-7s %-22s %-6s %-5s %-6s %-6s %s\n" \
    "$code" "$robots" "$cflag" "$dflag" "$((tlen-1))" "$words" "${url#https://$DOMAIN}" | tee -a "$OUT"
done < "$TMP/urls.txt"

say ""
say "=== Summary ==="
say "  URLs checked:            $TOTAL"
say "  Non-200 responses:       $notok"
say "  Marked noindex:          $noindex"
say "  Canonical not self:      $badcanon"
say "  Missing meta description:$nodesc"
say "  Thin (<200 words):       $thin"
say ""
if [ "$noindex" -gt 0 ] || [ "$badcanon" -gt 0 ] || [ "$notok" -gt 0 ]; then
  say ">>> Blocking problems found. These pages cannot be indexed as-is."
else
  say ">>> No technical block. Every URL is crawlable and indexable."
  if [ "$thin" -gt 0 ]; then
    say "    But $thin page(s) are under 200 words. Google routinely crawls"
    say "    thin pages and declines to index them - that shows up in Search"
    say "    Console as 'Crawled - currently not indexed'. This is a content"
    say "    problem, not a technical one, and no amount of waiting fixes it."
  else
    say "    The delay is Google's queue, not the site."
  fi
fi
say ""
say "Next: git add -A && git commit -m 'Add indexability audit' && git push"
