#!/bin/bash
# Builds Keep Mac Awake from source, grants the one sleep permission it needs, and launches it.
# Usage: ./install.sh          install or update
#        ./install.sh --check  report whether the app and the sleep permission are in place
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
APP="$HOME/Applications/KeepMacAwake.app"

# Sets disablesleep to the value it already has: passes only via the NOPASSWD rule, changes nothing.
permission_ok() {
	local current
	current="$(pmset -g | awk '/SleepDisabled/ {print $2}')"
	sudo -k -n /usr/bin/pmset -a disablesleep "${current:-0}" >/dev/null 2>&1
}

if [ "${1:-}" = "--check" ]; then
	status=0
	if [ -d "$APP" ]; then echo "ok    app installed at $APP"; else echo "MISS  app not installed"; status=1; fi
	if pgrep -x KeepMacAwake >/dev/null; then echo "ok    app running"; else echo "MISS  app not running"; status=1; fi
	if permission_ok; then echo "ok    sleep permission granted"; else echo "MISS  sleep permission (run ./install.sh)"; status=1; fi
	exit "$status"
fi

if [ "$(uname -s)" != Darwin ] || [ "$(sw_vers -productVersion | cut -d. -f1)" -lt 14 ]; then
	echo "Keep Mac Awake needs macOS 14 (Sonoma) or later." >&2
	exit 1
fi
if ! xcode-select -p >/dev/null 2>&1; then
	echo "Xcode Command Line Tools are missing. Run: xcode-select --install   then run ./install.sh again." >&2
	exit 1
fi

pkill -x KeepMacAwake 2>/dev/null || true
"$ROOT/scripts/build.sh"

if permission_ok; then
	echo "Sleep permission already granted."
else
	echo "macOS will ask for your password once, so Keep Mac Awake can switch sleep on and off."
	# A native password dialog works in agent shells too, where sudo has no terminal to prompt in.
	if ! osascript \
		-e 'on run argv' \
		-e 'do shell script "/bin/bash " & quoted form of (item 1 of argv) & " " & quoted form of (item 2 of argv) with prompt "Keep Mac Awake needs your password to switch sleep on and off." with administrator privileges' \
		-e 'end run' \
		"$ROOT/scripts/install-sudoers.sh" "$(id -un)"; then
		echo >&2
		echo "The password dialog was cancelled or couldn't open. Run this in Terminal, then run ./install.sh again:" >&2
		echo "  sudo \"$ROOT/scripts/install-sudoers.sh\" \"$(id -un)\"" >&2
		exit 2
	fi
fi

open "$APP"
echo "Done. Look for the cup icon in the menu bar."
