#!/usr/bin/env bash
# install.sh - installs RetiSkip, an HF band conditions page for NomadNet.
#
# Run as the same user that runs NomadNet:   ./install.sh
# Non-interactive:   CONTACT=you@example.com ./install.sh
# Optional overrides: SCRIPTS_DIR, PAGES_DIR, PYTHON
#
# Safe to re-run: the page and script are updated in place, any unrelated
# page with the same name is backed up, and the cron job is only added once.
set -euo pipefail

SRC="$(cd "$(dirname "$0")" && pwd)"
SCRIPTS_DIR="${SCRIPTS_DIR:-$HOME/scripts}"
PAGES_DIR="${PAGES_DIR:-$HOME/.nomadnetwork/storage/pages}"
PYTHON="${PYTHON:-$(command -v python3 || true)}"
STAMP="$(date +%Y%m%d-%H%M%S)"

say()  { printf '%s\n' "$*"; }
warn() { printf 'WARNING: %s\n' "$*" >&2; }
die()  { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

# --- checks -----------------------------------------------------------
[ -n "$PYTHON" ] && [ -x "$PYTHON" ] || die "python3 not found. Install Python 3.9+ or set PYTHON=/full/path/to/python3"
"$PYTHON" -c 'import sys; sys.exit(0 if sys.version_info >= (3, 9) else 1)' \
    || die "$PYTHON is older than 3.9 ($("$PYTHON" --version 2>&1))."
[ -d "$PAGES_DIR" ] || die "NomadNet pages folder not found at $PAGES_DIR. Set PAGES_DIR=/path/to/pages"

say "Python:         $PYTHON ($("$PYTHON" --version 2>&1))"
say "Scripts folder: $SCRIPTS_DIR"
say "Pages folder:   $PAGES_DIR"
say ""

# --- settings ---------------------------------------------------------
CONTACT="${CONTACT:-}"
while [ -z "$CONTACT" ]; do
    read -rp "Email or callsign to identify your node to the data feed (required): " CONTACT
done

# --- script -----------------------------------------------------------
mkdir -p "$SCRIPTS_DIR"
if [ -f "$SCRIPTS_DIR/retiskip.py" ]; then
    cp "$SCRIPTS_DIR/retiskip.py" "$SCRIPTS_DIR/retiskip.py.bak.$STAMP"
    say "Backed up existing retiskip.py"
fi
cp "$SRC/scripts/retiskip.py" "$SCRIPTS_DIR/retiskip.py"
"$PYTHON" - "$SCRIPTS_DIR/retiskip.py" "$PYTHON" "$CONTACT" <<'PY'
import re, sys
path, python, contact = sys.argv[1:]
contact = contact.replace("\\", "").replace('"', "")
s = open(path, encoding="utf-8").read()
s = re.sub(r"^#!.*", lambda m: "#!" + python, s, count=1)
s = re.sub(r'^USER_AGENT = ".*?"', lambda m: f'USER_AGENT = "(RetiSkip, {contact})"',
           s, count=1, flags=re.M)
open(path, "w", encoding="utf-8").write(s)
PY
chmod +x "$SCRIPTS_DIR/retiskip.py"
rm -f "$SCRIPTS_DIR/retiskip_cache.json"
say "Installed $SCRIPTS_DIR/retiskip.py"

# --- page -------------------------------------------------------------
if [ -e "$PAGES_DIR/retiskip.mu" ] && ! grep -q "from retiskip import" "$PAGES_DIR/retiskip.mu"; then
    cp "$PAGES_DIR/retiskip.mu" "$SCRIPTS_DIR/retiskip.mu.backup.$STAMP"
    say "Backed up an unrelated retiskip.mu to $SCRIPTS_DIR/retiskip.mu.backup.$STAMP"
fi
"$PYTHON" - "$SRC/pages/retiskip.mu" "$PAGES_DIR/retiskip.mu" "$PYTHON" "$SCRIPTS_DIR" <<'PY'
import re, sys
src, dst, python, scripts_dir = sys.argv[1:]
s = open(src, encoding="utf-8").read()
s = re.sub(r"^#!.*", lambda m: "#!" + python, s, count=1)
s = re.sub(r"^SCRIPTS_DIR = .*$", lambda m: f"SCRIPTS_DIR = {scripts_dir!r}", s, count=1, flags=re.M)
open(dst, "w", encoding="utf-8").write(s)
PY
chmod +x "$PAGES_DIR/retiskip.mu"
say "Installed $PAGES_DIR/retiskip.mu"

# --- test run ---------------------------------------------------------
say ""
say "Test run:"
"$PYTHON" "$SCRIPTS_DIR/retiskip.py" --debug || warn "Test run failed; see output above."
[ -w "$SCRIPTS_DIR" ] || warn "$SCRIPTS_DIR is not writable by $(whoami); the cache file cannot be saved."

# --- cron (hourly; the feed updates every few hours) ------------------
say ""
JOB="7 * * * * $PYTHON $SCRIPTS_DIR/retiskip.py > /dev/null 2>&1"
if ! command -v crontab >/dev/null 2>&1; then
    warn "crontab not found. Add this job manually:  $JOB"
elif crontab -l 2>/dev/null | grep -Fq "bandconditions.py"; then
    { crontab -l 2>/dev/null | grep -Fv "bandconditions.py" || true; echo "$JOB"; } | crontab -
    say "Replaced old bandconditions.py cron job with RetiSkip"
elif crontab -l 2>/dev/null | grep -Fq "$SCRIPTS_DIR/retiskip.py"; then
    say "Cron job already present (crontab -l to view)"
else
    { crontab -l 2>/dev/null || true; echo "$JOB"; } | crontab -
    say "Added cron job: refresh hourly"
fi

say ""
say "Done. Restart NomadNet so it picks up the new page, for example:"
say "    sudo systemctl restart nomadnet     (or your own service name / start method)"
say "Then visit /page/retiskip.mu on your node, and link to it from your home page:"
say '    `[Band Conditions`:/page/retiskip.mu]'
