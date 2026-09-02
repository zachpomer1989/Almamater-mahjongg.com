#!/bin/bash
# ssh-setup.sh — bootstrap SSH access to the SiteGround server that hosts
# sunrise.equityunion.com from a fresh Claude Code session.
#
# Reads connection details from environment variables set in the Claude
# environment configuration (see README.md, Part 4):
#
#   SITEGROUND_SSH_HOST      server hostname from SiteGround SSH Keys Manager
#   SITEGROUND_SSH_USER      e.g. u1234-abcdefgh
#   SITEGROUND_SSH_PORT      18765 unless SiteGround says otherwise
#   SITEGROUND_SSH_KEY_B64   private key, base64-encoded (preferred)
#   SITEGROUND_SSH_KEY       private key as plain text (fallback)
#
# Writes ~/.ssh/sunrise_key and a `sunrise` host alias, then tests the
# connection. Safe to re-run.

set -u

HOST="${SITEGROUND_SSH_HOST:-}"
USER_="${SITEGROUND_SSH_USER:-}"
PORT="${SITEGROUND_SSH_PORT:-18765}"
KEY_B64="${SITEGROUND_SSH_KEY_B64:-}"
KEY_RAW="${SITEGROUND_SSH_KEY:-}"

missing=0
for v in SITEGROUND_SSH_HOST SITEGROUND_SSH_USER; do
  [ -n "${!v:-}" ] || { echo "!! $v is not set"; missing=1; }
done
[ -n "$KEY_B64$KEY_RAW" ] || { echo "!! neither SITEGROUND_SSH_KEY_B64 nor SITEGROUND_SSH_KEY is set"; missing=1; }
[ "$missing" -eq 0 ] || { echo "Set the variables in the Claude environment configuration and start a new session."; exit 1; }

mkdir -p "$HOME/.ssh" && chmod 700 "$HOME/.ssh"
KEYFILE="$HOME/.ssh/sunrise_key"

if [ -n "$KEY_B64" ]; then
  printf '%s' "$KEY_B64" | base64 -d > "$KEYFILE" || { echo "!! base64 decode failed"; exit 1; }
else
  printf '%s\n' "$KEY_RAW" > "$KEYFILE"
fi
chmod 600 "$KEYFILE"

if ! ssh-keygen -y -f "$KEYFILE" >/dev/null 2>&1; then
  echo "!! $KEYFILE is not a valid private key (check the variable was pasted completely)"
  exit 1
fi

CONF="$HOME/.ssh/config"
touch "$CONF" && chmod 600 "$CONF"
if ! grep -q '^Host sunrise$' "$CONF" 2>/dev/null; then
  cat >> "$CONF" <<CFG
Host sunrise
  HostName $HOST
  User $USER_
  Port $PORT
  IdentityFile $KEYFILE
  IdentitiesOnly yes
  StrictHostKeyChecking accept-new
  ServerAliveInterval 30
CFG
fi

echo "=== Testing ssh sunrise ($USER_@$HOST:$PORT) ==="
if ssh -o ConnectTimeout=20 sunrise 'echo "connected to $(hostname)"; command -v wp >/dev/null && wp --info | head -5 || echo "wp-cli: not on PATH"'; then
  echo ""
  echo "OK — use: ssh sunrise"
else
  rc=$?
  echo ""
  echo "!! connection failed (exit $rc)."
  echo "   From a Claude session the usual cause is the environment network policy"
  echo "   not allowing $HOST on port $PORT. From a PC it is usually a key mismatch."
  exit "$rc"
fi
