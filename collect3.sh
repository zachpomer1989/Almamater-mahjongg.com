#!/bin/bash
# collect3.sh — pull Divi page content and integration code straight from the
# database via WP-CLI, bypassing the Divi Portability UI entirely.
#
# Run from inside the repo on the SiteGround server:
#     cd ~/review && bash collect3.sh
#
# READ-ONLY. Reads post content and Divi theme options. Writes only into
# this repo's 02-divi-code-modules/ folder.

set -u
cd "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)" || exit 1

OUT="02-divi-code-modules"
mkdir -p "$OUT/pages"
LOG="$OUT/collection-log.txt"
: > "$LOG"
say() { echo "$*" | tee -a "$LOG"; }

SITE=""
for c in "$HOME"/www/*/public_html "$HOME"/public_html; do
  [ -f "$c/wp-config.php" ] && { SITE="$c"; break; }
done

if [ -z "$SITE" ]; then say "!! Could not locate wp-config.php"; exit 1; fi
if ! command -v wp >/dev/null 2>&1; then say "!! WP-CLI not found"; exit 1; fi

WP="wp --path=$SITE"

say "=== Divi content collection ==="
say "Date: $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
say "Site: $SITE"
say ""

# ── Divi Theme Options → Integration ────────────────────────────────
# Head/body code pasted here is a very common home for tracking tags and
# hand-added libraries.
say "--- Theme Options / Integration ---"
$WP eval '
$o = get_option("et_divi");
$keys = ["integration_head","integration_body","integration_single_top","integration_single_bottom"];
foreach ($keys as $k) {
  echo "===== " . $k . " =====\n";
  if (!empty($o[$k])) { echo $o[$k] . "\n"; } else { echo "(empty)\n"; }
  echo "\n";
}
' > "$OUT/theme-options-integration.txt" 2>/dev/null

if [ -s "$OUT/theme-options-integration.txt" ]; then
  n=$(grep -c '=====' "$OUT/theme-options-integration.txt")
  empties=$(grep -c '^(empty)$' "$OUT/theme-options-integration.txt")
  say "OK  captured (${empties} of 4 boxes empty)"
else
  say "--  could not read et_divi option"
fi
say ""

# ── Page and post inventory ─────────────────────────────────────────
say "--- Content inventory ---"
$WP post list --post_type=page,post,product --post_status=publish,draft \
   --format=csv --fields=ID,post_type,post_status,post_title \
   > "$OUT/content-inventory.csv" 2>/dev/null
say "OK  $(( $(wc -l < "$OUT/content-inventory.csv") - 1 )) items"
say ""

# ── Per-page content dump ───────────────────────────────────────────
say "--- Page content ---"
IDS="$($WP post list --post_type=page --post_status=publish --format=ids 2>/dev/null)"
count=0
for id in $IDS; do
  slug="$($WP post get "$id" --field=post_name 2>/dev/null)"
  [ -z "$slug" ] && slug="page-$id"
  $WP post get "$id" --field=content > "$OUT/pages/${id}-${slug}.txt" 2>/dev/null
  sz=$(wc -c < "$OUT/pages/${id}-${slug}.txt" 2>/dev/null || echo 0)
  codemods=$(grep -o 'et_pb_code' "$OUT/pages/${id}-${slug}.txt" 2>/dev/null | wc -l)
  say "    ${id}-${slug}  ${sz}B  et_pb_code refs: ${codemods}"
  count=$((count+1))
done
say "OK  ${count} pages dumped"
say ""

# ── Flag the interesting bits ───────────────────────────────────────
say "--- Pattern scan across all page content ---"
scan() {
  hits=$(grep -ril "$1" "$OUT/pages/" 2>/dev/null | wc -l)
  [ "$hits" -gt 0 ] && say "    ${2}: ${hits} page(s)"
}
scan "progressive_redirect" "Vimeo signed URL (expires)"
scan "jsdelivr"             "jsDelivr CDN"
scan "cdnjs"                "cdnjs CDN"
scan "font-awesome"         "Font Awesome"
scan "<script"              "inline script tags"
scan "gtag("                "gtag calls"
scan "googletagmanager"     "Google Tag Manager"
scan "typekit"              "Adobe Typekit"
say ""

say "=== Done ==="
say ""
say "Next: git add -A && git commit -m 'Add Divi content' && git push"
