#!/bin/bash
# collect4.sh — locate the source of the external CDN and font references
# seen in the rendered homepage.
#
# The rendered page loads jsDelivr, cdnjs, Adobe Typekit and Google Fonts,
# but none of them appear in WPCode (5 stock snippets), Divi's Integration
# boxes (all empty), or any page's content (zero Code modules). This finds
# where they actually come from.
#
# Run from inside the repo on the SiteGround server:
#     cd ~/review && bash collect4.sh
#
# READ-ONLY. Searches files and the database; writes only into this repo.

set -u
cd "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)" || exit 1

OUT="04-server-config"
mkdir -p "$OUT" "02-divi-code-modules/theme-builder"
LOG="$OUT/source-hunt.txt"
: > "$LOG"
say() { echo "$*" | tee -a "$LOG"; }

SITE=""
for c in "$HOME"/www/*/public_html "$HOME"/public_html; do
  [ -f "$c/wp-config.php" ] && { SITE="$c"; break; }
done
[ -z "$SITE" ] && { say "!! wp-config.php not found"; exit 1; }
WP="wp --path=$SITE"

say "=== Source hunt ==="
say "Date: $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
say ""

NEEDLES="jsdelivr cdnjs typekit progressive_redirect fonts.googleapis"

# ── A. Filesystem search ────────────────────────────────────────────
# Skip uploads and vendor trees; we want authored code, not assets.
say "--- A. Files under wp-content ---"
for n in $NEEDLES; do
  say "  [$n]"
  grep -rl --binary-files=without-match "$n" "$SITE/wp-content" \
    --include='*.php' --include='*.js' --include='*.css' \
    --exclude-dir=uploads --exclude-dir=node_modules --exclude-dir=cache \
    2>/dev/null | sed "s|$SITE/wp-content|    wp-content|" | head -12
  say ""
done

# ── B. Divi parent theme integrity ──────────────────────────────────
# There is no child theme, so any edit here is destroyed on update.
say "--- B. Divi theme file modification times ---"
if [ -d "$SITE/wp-content/themes/Divi" ]; then
  say "  10 most recently modified .php files in the Divi parent theme:"
  find "$SITE/wp-content/themes/Divi" -name '*.php' -printf '    %TY-%Tm-%Td %TH:%TM  %p\n' 2>/dev/null \
    | sort -r | head -10 | sed "s|$SITE/wp-content/themes/Divi|  Divi|"
else
  say "  Divi theme directory not found"
fi
say ""

# ── C. Database: options table ──────────────────────────────────────
say "--- C. wp_options containing these strings ---"
$WP eval '
global $wpdb;
$needles = ["jsdelivr","cdnjs","typekit","progressive_redirect"];
foreach ($needles as $n) {
  $rows = $wpdb->get_col( $wpdb->prepare(
    "SELECT option_name FROM {$wpdb->options} WHERE option_value LIKE %s LIMIT 15",
    "%" . $wpdb->esc_like($n) . "%"
  ) );
  echo "  [" . $n . "] " . ( $rows ? implode(", ", $rows) : "no match" ) . "\n";
}
' 2>/dev/null | tee -a "$LOG"
say ""

# ── D. Database: posts and postmeta ─────────────────────────────────
say "--- D. Posts / postmeta containing these strings ---"
$WP eval '
global $wpdb;
$needles = ["jsdelivr","cdnjs","typekit","progressive_redirect"];
foreach ($needles as $n) {
  $like = "%" . $wpdb->esc_like($n) . "%";
  $p = $wpdb->get_results( $wpdb->prepare(
    "SELECT ID, post_type, post_title FROM {$wpdb->posts} WHERE post_content LIKE %s LIMIT 10", $like ) );
  echo "  [" . $n . "] posts: ";
  if ($p) { foreach ($p as $r) { echo $r->ID . "(" . $r->post_type . ":" . $r->post_title . ") "; } }
  else { echo "none"; }
  echo "\n";
  $m = $wpdb->get_results( $wpdb->prepare(
    "SELECT post_id, meta_key FROM {$wpdb->postmeta} WHERE meta_value LIKE %s LIMIT 10", $like ) );
  echo "      postmeta: ";
  if ($m) { foreach ($m as $r) { echo $r->post_id . "/" . $r->meta_key . " "; } }
  else { echo "none"; }
  echo "\n";
}
' 2>/dev/null | tee -a "$LOG"
say ""

# ── E. Divi Theme Builder + Library ─────────────────────────────────
# Global headers and footers live in their own post types, not in pages.
say "--- E. Divi Theme Builder / Library layouts ---"
for pt in et_pb_layout et_template et_header_layout et_body_layout et_footer_layout; do
  ids="$($WP post list --post_type="$pt" --post_status=publish,draft --format=ids 2>/dev/null)"
  if [ -n "$ids" ]; then
    n=$(echo "$ids" | wc -w)
    say "  $pt: $n item(s)"
    for id in $ids; do
      t="$($WP post get "$id" --field=post_title 2>/dev/null | tr -cd '[:alnum:]-_ ' | tr ' ' '-')"
      $WP post get "$id" --field=content > "02-divi-code-modules/theme-builder/${pt}-${id}-${t:-untitled}.txt" 2>/dev/null
    done
  else
    say "  $pt: none"
  fi
done
say ""
say "  scanning theme-builder dumps:"
for n in $NEEDLES; do
  c=$(grep -ril "$n" 02-divi-code-modules/theme-builder/ 2>/dev/null | wc -l)
  say "    $n: $c file(s)"
done
say ""

say "=== Done ==="
say ""
say "Next: git add -A && git commit -m 'Add source hunt' && git push"
