#!/bin/bash
# Installs Keep Mac Awake, grants the one sleep permission it needs, and launches it.
# Usage: curl -fsSL https://raw.githubusercontent.com/HJ29/keep-mac-awake/main/install.sh | bash
#        ./install.sh          from a clone: build from source instead (needs the Xcode Command Line Tools)
#        ./install.sh --check  report whether the app and the sleep permission are in place
set -euo pipefail

APP="$HOME/Applications/KeepMacAwake.app"
ZIP_URL=https://github.com/HJ29/keep-mac-awake/releases/latest/download/KeepMacAwake.zip
INSTALL_CMD="curl -fsSL https://raw.githubusercontent.com/HJ29/keep-mac-awake/main/install.sh | bash"
WORK=""
trap 'rm -rf "$WORK"' EXIT

# Sets disablesleep to the value it already has: passes only via the NOPASSWD rule, changes nothing.
permission_ok() {
	local current
	current="$(pmset -g | awk '/SleepDisabled/ {print $2}')"
	sudo -k -n /usr/bin/pmset -a disablesleep "${current:-0}" >/dev/null 2>&1
}

check() {
	local status=0
	if [ -d "$APP" ]; then echo "ok    app installed at $APP"; else echo "MISS  app not installed"; status=1; fi
	if pgrep -x KeepMacAwake >/dev/null; then echo "ok    app running"; else echo "MISS  app not running"; status=1; fi
	if permission_ok; then echo "ok    sleep permission granted"; else echo "MISS  sleep permission (run the installer again)"; status=1; fi
	return "$status"
}

# Downloads the latest release; curl adds no quarantine flag, so Gatekeeper doesn't block the ad-hoc signed app.
download() {
	WORK="$(mktemp -d)"
	echo "Downloading the latest Keep Mac Awake…"
	curl -fsSL "$ZIP_URL" -o "$WORK/KeepMacAwake.zip"
	ditto -x -k "$WORK/KeepMacAwake.zip" "$WORK"
	if [ ! -d "$WORK/KeepMacAwake.app" ]; then echo "The download didn't contain KeepMacAwake.app." >&2; exit 1; fi
	pkill -x KeepMacAwake 2>/dev/null || true
	mkdir -p "$(dirname "$APP")"
	rm -rf "$APP"
	mv "$WORK/KeepMacAwake.app" "$APP"
}

# Wrapped in a function so a `curl | bash` cut off mid-download runs nothing.
main() {
	if [ "${1:-}" = "--check" ]; then check; return; fi

	if [ "$(uname -s)" != Darwin ] || [ "$(sw_vers -productVersion | cut -d. -f1)" -lt 14 ]; then
		echo "Keep Mac Awake needs macOS 14 (Sonoma) or later." >&2
		exit 1
	fi

	# BASH_SOURCE is empty under `curl | bash`, so only a script run from a clone builds from source.
	local root=""
	if [ -n "${BASH_SOURCE[0]:-}" ]; then root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; fi
	if [ -n "$root" ] && [ -f "$root/scripts/build.sh" ]; then
		if ! xcode-select -p >/dev/null 2>&1; then
			echo "Xcode Command Line Tools are missing. Run: xcode-select --install   then run ./install.sh again." >&2
			exit 1
		fi
		pkill -x KeepMacAwake 2>/dev/null || true
		"$root/scripts/build.sh"
		INSTALL_CMD="$root/install.sh"
	else
		download
	fi

	local sudoers="$APP/Contents/Resources/install-sudoers.sh"
	if permission_ok; then
		echo "Sleep permission already granted."
	else
		echo "macOS will ask for your password once, so Keep Mac Awake can switch sleep on and off."
		# A native password dialog works in agent shells too, where sudo has no terminal to prompt in.
		if ! osascript \
			-e 'on run argv' \
			-e 'do shell script "/bin/bash " & quoted form of (item 1 of argv) & " " & quoted form of (item 2 of argv) with prompt "Keep Mac Awake needs your password to switch sleep on and off." with administrator privileges' \
			-e 'end run' \
			"$sudoers" "$(id -un)"; then
			echo >&2
			echo "The password dialog was cancelled or couldn't open. Run this in Terminal:" >&2
			echo "  sudo /bin/bash \"$sudoers\" \"$(id -un)\"" >&2
			echo "then run the installer again: $INSTALL_CMD" >&2
			exit 2
		fi
	fi

	open "$APP"
	echo "Done. Look for the moon icon in the menu bar."
}

main "$@"
