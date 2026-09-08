#!/bin/bash
# collect6.sh — hunt for a leftover noindex or temp-domain artifact.
#
# Everything checked so far is clean: robots.txt, .htaccess, all 38 pages'
# robots meta, WPCode, Divi integration, blog_public. This searches the
# places a staging-era block could still be hiding.
#
#   cd ~/review && bash collect6.sh
#
# READ-ONLY. Writes only into 05-seo-output/.

set -u
cd "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)" || exit 1

SITE=""
for c in "$HOME"/www/*/public_html "$HOME"/public_html; do
  [ -f "$c/wp-config.php" ] && { SITE="$c"; break; }
done
[ -z "$SITE" ] && { echo "!! wp-config.php not found"; exit 1; }
command -v wp >/dev/null 2>&1 || { echo "!! WP-CLI not found"; exit 1; }
WP="wp --path=$SITE"

OUT="05-seo-output/noindex-hunt.txt"
: > "$OUT"
say() { echo "$*" | tee -a "$OUT"; }

say "=== Noindex / temp-domain hunt ==="
say "Date: $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
say ""

# ---- 1. Yoast global noindex switches -------------------------------
say "--- 1. Yoast noindex settings (wpseo_titles) ---"
$WP eval '
$t = get_option("wpseo_titles");
if (!is_array($t)) { echo "  wpseo_titles not readable\n"; }
else {
  $on = [];
  foreach ($t as $k => $v) {
    if (strpos($k, "noindex") === 0 && ($v === true || $v === 1 || $v === "1")) { $on[] = $k; }
  }
  echo $on ? "  NOINDEX ON for: " . implode(", ", $on) . "\n"
           : "  no global noindex switches enabled\n";
}
' 2>/dev/null | tee -a "$OUT"
say ""

# ---- 2. Per-post noindex overrides ----------------------------------
say "--- 2. Per-post Yoast noindex overrides ---"
$WP eval '
global $wpdb;
$rows = $wpdb->get_results(
  "SELECT pm.post_id, pm.meta_value, p.post_type, p.post_title
   FROM {$wpdb->postmeta} pm
   JOIN {$wpdb->posts} p ON p.ID = pm.post_id
   WHERE pm.meta_key = \"_yoast_wpseo_meta-robots-noindex\"
     AND pm.meta_value NOT IN (\"\", \"0\")
   LIMIT 50"
);
if ($rows) {
  foreach ($rows as $r) { echo "  NOINDEX: {$r->post_id} ({$r->post_type}) {$r->post_title} = {$r->meta_value}\n"; }
} else { echo "  none\n"; }
' 2>/dev/null | tee -a "$OUT"
say ""

# ---- 3. Temp / staging domain references ----------------------------
say "--- 3. Temp or staging domain references in the database ---"
$WP eval '
global $wpdb;
$needles = ["temp.domains", "sgvps", "staging", "sg-host", "wp-stage", "dev."];
foreach ($needles as $n) {
  $like = "%" . $wpdb->esc_like($n) . "%";
  $o = $wpdb->get_col($wpdb->prepare("SELECT option_name FROM {$wpdb->options} WHERE option_value LIKE %s LIMIT 10", $like));
  $p = $wpdb->get_col($wpdb->prepare("SELECT ID FROM {$wpdb->posts} WHERE post_content LIKE %s LIMIT 10", $like));
  echo "  [" . $n . "] options: " . ($o ? implode(", ", $o) : "none")
     . " | posts: " . ($p ? implode(", ", $p) : "none") . "\n";
}
' 2>/dev/null | tee -a "$OUT"
say ""

# ---- 4. X-Robots-Tag anywhere in authored code ----------------------
say "--- 4. X-Robots-Tag / noindex headers in wp-content PHP ---"
grep -rl --binary-files=without-match -i "x-robots-tag" "$SITE/wp-content" \
  --include='*.php' --exclude-dir=uploads --exclude-dir=updraft --exclude-dir=node_modules \
  2>/dev/null | sed "s|$SITE/wp-content|    wp-content|" | head -20 | tee -a "$OUT"
say ""

# ---- 5. Must-use plugins and drop-ins -------------------------------
say "--- 5. mu-plugins and drop-ins (not listed by 'wp plugin list') ---"
if [ -d "$SITE/wp-content/mu-plugins" ]; then
  ls -la "$SITE/wp-content/mu-plugins" 2>/dev/null | tail -n +2 | sed 's/^/    /' | tee -a "$OUT"
else
  say "    no mu-plugins directory"
fi
for d in advanced-cache.php object-cache.php sunrise.php maintenance.php; do
  [ -f "$SITE/wp-content/$d" ] && say "    drop-in present: $d"
done
say ""

# ---- 6. Core indexability flags -------------------------------------
say "--- 6. Core flags ---"
$WP eval '
echo "  blog_public: " . get_option("blog_public") . "\n";
echo "  home:        " . get_option("home") . "\n";
echo "  siteurl:     " . get_option("siteurl") . "\n";
$s = get_option("sg_security_settings");
echo "  sg_security_settings: " . (is_array($s) ? "present (" . count($s) . " keys)" : "not an array") . "\n";
' 2>/dev/null | tee -a "$OUT"
say ""

# ---- 7. Fresh sitemap headers ---------------------------------------
say "--- 7. Sitemap response right now, as Googlebot ---"
curl -sS -L --max-time 30 \
  -A "Mozilla/5.0 (compatible; Googlebot/2.1; +http://www.google.com/bot.html)" \
  -D 05-seo-output/sitemap-headers-latest.txt \
  -o 05-seo-output/sitemap-body-latest.xml \
  "https://almamater-mahjongg.com/sitemap_index.xml" 2>/dev/null
grep -iE '^(HTTP/|content-type|x-robots-tag|x-proxy-cache|location)' \
  05-seo-output/sitemap-headers-latest.txt 2>/dev/null | sed 's/^/    /' | tee -a "$OUT"
say "    body: $(wc -c < 05-seo-output/sitemap-body-latest.xml 2>/dev/null || echo 0) bytes"
say "    first bytes: $(head -c 40 05-seo-output/sitemap-body-latest.xml 2>/dev/null)"
say ""

say "=== Done ==="
say ""
say "Next: git add -A && git commit -m 'Add noindex hunt' && git push"
