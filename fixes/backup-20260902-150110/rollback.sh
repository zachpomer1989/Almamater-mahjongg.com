#!/bin/bash
# Restores the Divi integration values captured 20260902-150110.
#   bash fixes/backup-20260902-150110/rollback.sh
set -u
cd "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)" || exit 1
SITE="/home/u141-wwt5r1geejhs/www/almamater-mahjongg.com/public_html"
wp --path="$SITE" option patch update et_divi divi_integration_head "$(cat "fixes/backup-20260902-150110/divi_integration_head.html")"
wp --path="$SITE" option patch update et_divi divi_integration_body "$(cat "fixes/backup-20260902-150110/divi_integration_body.html")"
wp --path="$SITE" sg purge >/dev/null 2>&1 || true
echo "Rolled back to 20260902-150110."
