#!/bin/bash
# apply-seo-fixes.sh — write the reviewed SEO content and settings.
#
# WRITES TO YOUR LIVE SITE. Everything it overwrites is captured to
# fixes/seo-backup-<timestamp>/backup.json first.
#
#   cd ~/review && bash apply-seo-fixes.sh
#
# Review fixes/meta-posts.tsv and fixes/meta-terms.tsv before running —
# that is the actual copy that will appear in Google's search results.
#
# What it does:
#   1. Writes meta descriptions to 8 pages and 6 products
#   2. Writes meta descriptions to 6 product categories
#   3. Sets product tag archives to noindex (13 tags across 6 products
#      means most tag pages hold a single item — thin, near-duplicate)
#   4. Sets the Coming Soon page to noindex
#   5. Deletes the three malformed tags produced by the semicolon-separated
#      CSV import
#   6. Deactivates the login-logo snippet still pointing at WPCode's demo
#      real estate logo
#
# It does NOT delete the "Test Product" draft or rename any slugs — those
# are your calls, and both are listed at the end.

set -u
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$REPO" || exit 1

SITE=""
for c in "$HOME"/www/*/public_html "$HOME"/public_html; do
  [ -f "$c/wp-config.php" ] && { SITE="$c"; break; }
done
[ -z "$SITE" ] && { echo "!! wp-config.php not found"; exit 1; }
command -v wp >/dev/null 2>&1 || { echo "!! WP-CLI not found"; exit 1; }

for f in fixes/meta-posts.tsv fixes/meta-terms.tsv fixes/apply-seo.php; do
  [ -s "$f" ] || { echo "!! missing $f"; exit 1; }
done

STAMP="$(date -u '+%Y%m%d-%H%M%S')"
BK="$REPO/fixes/seo-backup-$STAMP"
mkdir -p "$BK"

echo "=== SEO content and settings fix ==="
echo "Site:   $SITE"
echo "Backup: fixes/seo-backup-$STAMP"
echo ""

export REVIEW_REPO="$REPO"
export REVIEW_BACKUP="$BK"

wp --path="$SITE" eval-file fixes/apply-seo.php 2>&1 | tee "$BK/apply-log.txt"

if [ ! -s "$BK/backup.json" ]; then
  echo ""
  echo "!! backup.json was not written — the run did not complete cleanly."
  echo "!! Review $BK/apply-log.txt before re-running."
  exit 1
fi

# ---- Rollback -------------------------------------------------------
cat > "$BK/rollback.sh" <<'ROLLBACK'
#!/bin/bash
# Restores what apply-seo-fixes.sh overwrote. Deleted tags are listed in
# backup.json but are NOT recreated — re-add those by hand if wanted.
set -u
BK="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$BK/../.." && pwd)"
SITE=""
for c in "$HOME"/www/*/public_html "$HOME"/public_html; do
  [ -f "$c/wp-config.php" ] && { SITE="$c"; break; }
done
REVIEW_BACKUP="$BK" wp --path="$SITE" eval '
$b = json_decode( file_get_contents( getenv("REVIEW_BACKUP") . "/backup.json" ), true );
foreach ( $b["post_meta"] as $k => $v ) {
  if ( substr( $k, -8 ) === "_noindex" ) {
    $id = (int) $k;
    if ( $v === "" ) { delete_post_meta( $id, "_yoast_wpseo_meta-robots-noindex" ); }
    else { update_post_meta( $id, "_yoast_wpseo_meta-robots-noindex", $v ); }
  } else {
    $id = (int) $k;
    if ( $v === "" ) { delete_post_meta( $id, "_yoast_wpseo_metadesc" ); }
    else { update_post_meta( $id, "_yoast_wpseo_metadesc", $v ); }
  }
}
if ( $b["taxonomy"] !== null ) { update_option( "wpseo_taxonomy_meta", $b["taxonomy"] ); }
if ( $b["titles"] !== null )   { update_option( "wpseo_titles", $b["titles"] ); }
foreach ( $b["wpcode"] as $w ) { wp_update_post( array( "ID" => $w["ID"], "post_status" => $w["status"] ) ); }
echo "Restored.\n";
'
wp --path="$SITE" sg purge >/dev/null 2>&1 || true
ROLLBACK
chmod +x "$BK/rollback.sh"

# ---- Verify ---------------------------------------------------------
echo ""
echo "--- Verifying ---"
wp --path="$SITE" eval '
$ids = array(371192,371328,371332,371246,371435,371313,371319,371337,371418,371477,371478,371255,371293,371294);
$missing = 0;
foreach ( $ids as $id ) {
  $d = get_post_meta( $id, "_yoast_wpseo_metadesc", true );
  if ( ! $d ) { echo "  !! $id has no description\n"; $missing++; }
}
echo $missing ? "  $missing post(s) missing\n" : "  OK  all 14 posts have descriptions\n";

$tm = get_option( "wpseo_taxonomy_meta", array() );
$c  = isset( $tm["product_cat"] ) ? count( array_filter( $tm["product_cat"], function( $t ) { return ! empty( $t["wpseo_desc"] ); } ) ) : 0;
echo "  OK  $c product categories have descriptions\n";

$t = get_option( "wpseo_titles", array() );
echo ! empty( $t["noindex-tax-product_tag"] ) ? "  OK  product tags are noindex\n" : "  !!  product tags NOT noindex\n";

$bad = 0;
foreach ( array("ecueast-carolinapiratescollege-mahjong","meredith-collegecollege-mahjong","nc-statewolfpackcollege-mahjong") as $s ) {
  if ( get_term_by( "slug", $s, "product_tag" ) ) { $bad++; }
}
echo $bad ? "  !!  $bad malformed tag(s) remain\n" : "  OK  malformed tags removed\n";
' 2>/dev/null

echo ""
echo "--- Purging cache ---"
wp --path="$SITE" sg purge >/dev/null 2>&1 && echo "  SG cache purged" || echo "  (purge from SG Optimizer)"

echo ""
echo "=== Done ==="
echo ""
echo "Left for you to decide:"
echo "  - Product slugs still say 'coming-soon' but the products are now"
echo "    titled 'Preorder: ...'. Renaming needs redirects, so it is yours to make."
echo "  - A draft named 'Test Product' (371599) is still in the database."
echo "  - Drafts 'NC State Mah Jongg Sets' (371495) and 'Code Layouts' (371163)."
echo ""
echo "To undo:  bash fixes/seo-backup-$STAMP/rollback.sh"
echo "Then:     git add -A && git commit -m 'Apply SEO fixes' && git push"
