#!/bin/bash
# collect7.sh — test whether the sitemap survives compressed delivery.
#
# Search Console now shows "Last read 9/6/26" with "Sitemap could not be
# read" and 0 discovered pages. That is a PARSE failure, not a fetch
# failure: Google retrieved the file and could not make sense of it.
#
# Every test so far fetched the sitemap UNCOMPRESSED. Googlebot always
# sends "Accept-Encoding: gzip". The response carries "Vary: Accept-
# Encoding", so the compressed and uncompressed paths are served
# differently and only one of them has ever been checked.
#
#   cd ~/review && bash collect7.sh
#
# READ-ONLY over HTTP.

set -u
cd "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)" || exit 1

DOMAIN="${1:-almamater-mahjongg.com}"
UA="Mozilla/5.0 (compatible; Googlebot/2.1; +http://www.google.com/bot.html)"
OUT="05-seo-output/encoding-test.txt"
D="05-seo-output/encoding"
mkdir -p "$D"
: > "$OUT"
say() { echo "$*" | tee -a "$OUT"; }

say "=== Sitemap encoding / parse test ==="
say "Date: $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
say ""

test_url() {
  local url="$1" tag="$2"
  say "########## $tag"
  say "  $url"
  say ""

  # A: no compression requested
  curl -sS -L --max-time 30 -A "$UA" \
       -D "$D/${tag}-plain-headers.txt" -o "$D/${tag}-plain.xml" "$url" 2>/dev/null
  local a_size a_first a_hash
  a_size=$(wc -c < "$D/${tag}-plain.xml" 2>/dev/null || echo 0)
  a_first=$(head -c 20 "$D/${tag}-plain.xml" 2>/dev/null | tr -d '\0')
  a_hash=$(md5sum "$D/${tag}-plain.xml" 2>/dev/null | cut -c1-12)
  say "  [A] no Accept-Encoding"
  say "      size: ${a_size}B  md5: ${a_hash}"
  say "      starts: ${a_first}"
  say "      $(grep -i '^content-encoding:' "$D/${tag}-plain-headers.txt" 2>/dev/null | tr -d '\r' || echo 'content-encoding: (none)')"

  # B: curl handles gzip - this is what Googlebot effectively does
  curl -sS -L --max-time 30 -A "$UA" --compressed \
       -D "$D/${tag}-gzip-headers.txt" -o "$D/${tag}-gzip.xml" "$url" 2>/dev/null
  local b_size b_first b_hash
  b_size=$(wc -c < "$D/${tag}-gzip.xml" 2>/dev/null || echo 0)
  b_first=$(head -c 20 "$D/${tag}-gzip.xml" 2>/dev/null | tr -d '\0')
  b_hash=$(md5sum "$D/${tag}-gzip.xml" 2>/dev/null | cut -c1-12)
  say "  [B] --compressed (gzip accepted)"
  say "      size: ${b_size}B  md5: ${b_hash}"
  say "      starts: ${b_first}"
  say "      $(grep -i '^content-encoding:' "$D/${tag}-gzip-headers.txt" 2>/dev/null | tr -d '\r' || echo 'content-encoding: (none)')"

  if [ "$a_hash" = "$b_hash" ] && [ -n "$a_hash" ]; then
    say "      OK  compressed and uncompressed bodies are identical"
  else
    say "      !!  BODIES DIFFER - compressed delivery is corrupting this file"
  fi

  # C: byte-order mark or leading whitespace
  local bom
  bom=$(head -c 3 "$D/${tag}-plain.xml" 2>/dev/null | od -An -tx1 | tr -d ' \n')
  if [ "$bom" = "efbbbf" ]; then
    say "      !!  UTF-8 BOM present - this alone can break XML parsing"
  else
    say "      OK  no BOM (first 3 bytes: $bom)"
  fi

  # D: XML well-formedness
  if command -v xmllint >/dev/null 2>&1; then
    if xmllint --noout "$D/${tag}-plain.xml" 2>"$D/${tag}-xmllint.txt"; then
      say "      OK  xmllint: well-formed"
    else
      say "      !!  xmllint reports errors:"
      sed 's/^/          /' "$D/${tag}-xmllint.txt" | head -5 | tee -a "$OUT"
    fi
  else
    say "      -- xmllint unavailable, skipping validation"
  fi
  say ""
}

test_url "https://${DOMAIN}/sitemap_index.xml" "index"

# Every child too - Google reads the index, then each child. One bad
# child is enough to fail the whole submission.
CHILDREN="$(grep -oE '<loc>[^<]+</loc>' "$D/index-plain.xml" 2>/dev/null | sed -e 's/<loc>//' -e 's|</loc>||')"
for c in $CHILDREN; do
  test_url "$c" "$(basename "$c" .xml)"
done

say "=== Summary ==="
say "Any '!!' above is the cause. If every line is OK, the sitemap is"
say "byte-identical whether compressed or not, well-formed, and free of a"
say "BOM - meaning the parse failure is on Google's side and resubmitting"
say "is the correct next step."
say ""
say "Next: git add -A && git commit -m 'Add encoding test' && git push"
