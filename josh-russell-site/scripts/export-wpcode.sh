#!/usr/bin/env bash
# Export all WPCode snippets from joshrussellrealestate.com production into this repo.
# Usage: ./scripts/export-wpcode.sh [ssh-host]
set -euo pipefail

HOST="${1:-joshrussell}"
WP_PATH="~/www/joshrussellrealestate.com/public_html"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="$REPO_ROOT/db-snippets"

mkdir -p "$OUT/snippets"

echo "==> Preflight: $HOST:$WP_PATH"
ssh "$HOST" "cd $WP_PATH && wp core version" >/dev/null 2>&1 || {
  echo "FAILED. Check that '$HOST' resolves (~/.ssh/config), that WP_PATH is the"
  echo "real site root, and that WP-CLI is on the PATH: ssh $HOST \"ls ~/www; wp --info\""
  exit 1
}

echo "==> Exporting snippet metadata to JSON"
ssh "$HOST" "cd $WP_PATH && wp eval '
\$posts = get_posts([\"post_type\"=>\"wpcode\",\"post_status\"=>\"any\",\"numberposts\"=>-1,\"orderby\"=>\"ID\",\"order\"=>\"ASC\"]);
\$out = [];
foreach (\$posts as \$p) {
  \$type = wp_get_object_terms(\$p->ID,\"wpcode_type\",[\"fields\"=>\"names\"]);
  \$loc  = wp_get_object_terms(\$p->ID,\"wpcode_location\",[\"fields\"=>\"names\"]);
  \$tags = wp_get_object_terms(\$p->ID,\"wpcode_tags\",[\"fields\"=>\"names\"]);
  \$out[] = [
    \"id\"=>\$p->ID,
    \"title\"=>\$p->post_title,
    \"active\"=>(\$p->post_status===\"publish\"),
    \"post_status\"=>\$p->post_status,
    \"type\"=>\$type[0] ?? \"\",
    \"location\"=>\$loc[0] ?? \"\",
    \"tags\"=>\$tags,
    \"auto_insert\"=>get_post_meta(\$p->ID,\"_wpcode_auto_insert\",true),
    \"priority\"=>get_post_meta(\$p->ID,\"_wpcode_priority\",true),
    \"note\"=>get_post_meta(\$p->ID,\"_wpcode_note\",true),
    \"conditional_logic\"=>get_post_meta(\$p->ID,\"_wpcode_conditional_logic\",true),
    \"code\"=>\$p->post_content,
  ];
}
echo json_encode(\$out, JSON_PRETTY_PRINT|JSON_UNESCAPED_SLASHES|JSON_UNESCAPED_UNICODE);
'" > "$OUT/wpcode-snippets.json"

echo "==> Writing per-snippet files on server"
ssh "$HOST" "cd $WP_PATH && wp eval '
\$posts = get_posts([\"post_type\"=>\"wpcode\",\"post_status\"=>\"any\",\"numberposts\"=>-1,\"orderby\"=>\"ID\",\"order\"=>\"ASC\"]);
\$extmap = [\"php\"=>\"php\",\"css\"=>\"css\",\"js\"=>\"js\",\"html\"=>\"html\",\"universal\"=>\"php\",\"text\"=>\"txt\",\"scss\"=>\"scss\",\"blocks\"=>\"html\"];
\$dir = sys_get_temp_dir().\"/wpcode_export\";
@mkdir(\$dir, 0755, true);
array_map(\"unlink\", glob(\"\$dir/*\"));
foreach (\$posts as \$p) {
  \$type = wp_get_object_terms(\$p->ID,\"wpcode_type\",[\"fields\"=>\"names\"]);
  \$loc  = wp_get_object_terms(\$p->ID,\"wpcode_location\",[\"fields\"=>\"names\"]);
  \$t = strtolower(\$type[0] ?? \"php\");
  \$ext = \$extmap[\$t] ?? \"txt\";
  \$slug = trim(preg_replace(\"/[^a-z0-9]+/\",\"-\", strtolower(\$p->post_title)), \"-\");
  \$fn = sprintf(\"%s/%d-%s.%s\", \$dir, \$p->ID, \$slug, \$ext);
  \$hdr = sprintf(\"WPCode snippet #%d: %s | type=%s | location=%s | status=%s | priority=%s\", \$p->ID, \$p->post_title, \$t, \$loc[0] ?? \"\", \$p->post_status, get_post_meta(\$p->ID,\"_wpcode_priority\",true));
  \$comment = in_array(\$ext,[\"css\",\"js\",\"scss\"]) ? \"/* \$hdr */\n\n\" : (\$ext===\"html\" ? \"<!-- \$hdr -->\n\n\" : \"<?php /* \$hdr */ ?>\n\");
  file_put_contents(\$fn, \$comment . \$p->post_content);
}
' > /dev/null"

echo "==> Downloading"
find "$OUT/snippets" -type f ! -name .gitkeep -delete
scp -q "$HOST:/tmp/wpcode_export/*" "$OUT/snippets/"
ssh "$HOST" "rm -rf /tmp/wpcode_export"

echo "==> Exporting Divi Theme Options integration code"
# Divi -> Theme Options -> Integration stores raw <script>/<style> blocks in the
# et_divi option. This is a THIRD place custom code hides, alongside WPCode and
# mu-plugins, and it is easy to forget because nothing about it looks like code
# in the admin. The global reveal-animation script that blanked listing detail
# pages lived here, not in WPCode.
mkdir -p "$OUT/divi-integration"
rm -f "$OUT/divi-integration"/*

for KEY in divi_integration_head divi_integration_body \
           divi_integration_single_top divi_integration_single_bottom; do
  ssh "$HOST" "cd $WP_PATH && wp eval '
    \$o = get_option(\"et_divi\");
    \$v = isset(\$o[\"$KEY\"]) ? \$o[\"$KEY\"] : \"\";
    echo is_string(\$v) ? \$v : \"\";
  '" > "$OUT/divi-integration/$KEY.html"

  if [ ! -s "$OUT/divi-integration/$KEY.html" ]; then
    rm -f "$OUT/divi-integration/$KEY.html"
  else
    echo "    $KEY.html ($(wc -c < "$OUT/divi-integration/$KEY.html") bytes)"
  fi
done

echo "==> Exporting Divi Custom CSS"
ssh "$HOST" "cd $WP_PATH && wp eval '
  \$o = get_option(\"et_divi\");
  echo isset(\$o[\"custom_css\"]) && is_string(\$o[\"custom_css\"]) ? \$o[\"custom_css\"] : \"\";
'" > "$OUT/divi-integration/custom_css.css"
[ -s "$OUT/divi-integration/custom_css.css" ] || rm -f "$OUT/divi-integration/custom_css.css"

echo "==> Done. $(ls -1 "$OUT/snippets" | wc -l) snippets in db-snippets/snippets/"
git -C "$REPO_ROOT" status --short db-snippets/ || true
