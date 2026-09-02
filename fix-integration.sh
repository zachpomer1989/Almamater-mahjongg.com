#!/bin/bash
# fix-integration.sh — apply the Divi Theme Options integration fixes.
#
# WRITES TO YOUR LIVE SITE. It backs up the current values first and
# generates a rollback script before changing anything.
#
#   cd ~/review && bash fix-integration.sh
#
# What it changes, and why:
#
#   1. REMOVES the script that sets display:none on the <html> element and
#      only reveals the page after DOMContentLoaded. This hid the entire
#      site until JavaScript ran, destroying First and Largest Contentful
#      Paint on every page, and rendering a blank white page if any script
#      failed.
#
#   2. REMOVES the duplicate slick.min.js from the body. It was loaded in
#      both the head and the body.
#
#   3. REMOVES the AOS.init() call. The AOS library is not loaded anywhere
#      on the site, so this threw "AOS is not defined" on every page load.
#
#   4. REPLACES Font Awesome 6.0.0-beta3 with stable 6.7.2. A 2021 beta
#      was running in production.
#
# Both sliders and the scroll-reveal script are preserved unchanged.

set -u
cd "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)" || exit 1

SITE=""
for c in "$HOME"/www/*/public_html "$HOME"/public_html; do
  [ -f "$c/wp-config.php" ] && { SITE="$c"; break; }
done
[ -z "$SITE" ] && { echo "!! wp-config.php not found"; exit 1; }
command -v wp >/dev/null 2>&1 || { echo "!! WP-CLI not found"; exit 1; }
WP="wp --path=$SITE"

for f in fixes/integration-head.html fixes/integration-body.html; do
  [ -s "$f" ] || { echo "!! missing $f"; exit 1; }
done

STAMP="$(date -u '+%Y%m%d-%H%M%S')"
BK="fixes/backup-$STAMP"
mkdir -p "$BK"

echo "=== Divi integration fix ==="
echo "Site:   $SITE"
echo "Backup: $BK"
echo ""

# ---- 1. Back up current values -------------------------------------
echo "--- Backing up current values ---"
$WP eval '
$o = get_option("et_divi");
echo isset($o["divi_integration_head"]) ? $o["divi_integration_head"] : "";
' > "$BK/divi_integration_head.html" 2>/dev/null

$WP eval '
$o = get_option("et_divi");
echo isset($o["divi_integration_body"]) ? $o["divi_integration_body"] : "";
' > "$BK/divi_integration_body.html" 2>/dev/null

echo "  head: $(wc -c < "$BK/divi_integration_head.html") bytes saved"
echo "  body: $(wc -c < "$BK/divi_integration_body.html") bytes saved"

if [ ! -s "$BK/divi_integration_head.html" ]; then
  echo "!! Backup is empty - refusing to continue. Nothing was changed."
  exit 1
fi

# ---- 2. Generate the rollback BEFORE writing anything ---------------
cat > "$BK/rollback.sh" <<ROLLBACK
#!/bin/bash
# Restores the Divi integration values captured $STAMP.
#   bash fixes/backup-$STAMP/rollback.sh
set -u
cd "\$(cd "\$(dirname "\${BASH_SOURCE[0]}")/../.." && pwd)" || exit 1
SITE="$SITE"
wp --path="\$SITE" option patch update et_divi divi_integration_head "\$(cat "$BK/divi_integration_head.html")"
wp --path="\$SITE" option patch update et_divi divi_integration_body "\$(cat "$BK/divi_integration_body.html")"
wp --path="\$SITE" sg purge >/dev/null 2>&1 || true
echo "Rolled back to $STAMP."
ROLLBACK
chmod +x "$BK/rollback.sh"
echo "  rollback script written"
echo ""

# ---- 3. Apply -------------------------------------------------------
echo "--- Applying ---"
if $WP option patch update et_divi divi_integration_head "$(cat fixes/integration-head.html)" 2>&1; then
  echo "  head updated"
else
  echo "!! head update FAILED - run $BK/rollback.sh"; exit 1
fi

if $WP option patch update et_divi divi_integration_body "$(cat fixes/integration-body.html)" 2>&1; then
  echo "  body updated"
else
  echo "!! body update FAILED - run $BK/rollback.sh"; exit 1
fi
echo ""

# ---- 4. Verify ------------------------------------------------------
echo "--- Verifying ---"
$WP eval '
$o = get_option("et_divi");
$h = isset($o["divi_integration_head"]) ? $o["divi_integration_head"] : "";
$b = isset($o["divi_integration_body"]) ? $o["divi_integration_body"] : "";
$both = $h . $b;
echo (stripos($h, "style.display") === false)
     ? "  OK  page-hiding script removed\n" : "  !!  page-hiding script STILL PRESENT\n";
echo (strpos($b, "AOS.init") === false)
     ? "  OK  AOS.init removed\n" : "  !!  AOS.init still present\n";
echo (substr_count($both, "slick.min.js") === 1)
     ? "  OK  slick.min.js loaded once\n" : "  !!  slick.min.js count is " . substr_count($both, "slick.min.js") . "\n";
echo (strpos($both, "6.0.0-beta3") === false)
     ? "  OK  Font Awesome beta replaced\n" : "  !!  beta still present\n";
echo (strpos($b, "eu-community-carousel") !== false && strpos($b, "eu-testimonials") !== false)
     ? "  OK  both sliders preserved\n" : "  !!  a slider is MISSING - roll back\n";
' 2>/dev/null

# ---- 5. Purge caches ------------------------------------------------
echo ""
echo "--- Purging cache ---"
$WP sg purge >/dev/null 2>&1 && echo "  SG cache purged" || echo "  (sg purge unavailable - purge from SG Optimizer)"
$WP cache flush >/dev/null 2>&1 && echo "  object cache flushed" || true

echo ""
echo "=== Done ==="
echo ""
echo "Now load https://almamater-mahjongg.com in a private window."
echo "Check: page paints immediately, both sliders work, no console errors."
echo ""
echo "To undo:  bash $BK/rollback.sh"
echo "Then:     git add -A && git commit -m 'Apply Divi integration fix' && git push"
