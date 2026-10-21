#!/bin/bash
# Turns normal sleep back on, then removes the app and its sudoers rule.
set -euo pipefail

APP="$HOME/Applications/KeepMacAwake.app"
DEST=/etc/sudoers.d/keep-mac-awake

pkill -x KeepMacAwake 2>/dev/null || true
# Must run before the rule is removed, while it still needs no password.
sudo -n /usr/bin/pmset -a disablesleep 0 2>/dev/null \
	|| echo "Couldn't turn sleep back on. Run: sudo pmset -a disablesleep 0" >&2
rm -rf "$APP"

if [ -e "$DEST" ]; then
	osascript -e "do shell script \"rm -f $DEST\" with prompt \"Keep Mac Awake needs your password to remove its sleep permission.\" with administrator privileges" \
		|| echo "Couldn't remove $DEST. Run: sudo rm $DEST" >&2
fi
echo "Keep Mac Awake removed. If you added it to Login Items, remove it there too."
