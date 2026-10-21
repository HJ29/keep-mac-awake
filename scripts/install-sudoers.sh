#!/bin/bash
# Run as root. Lets <user> run exactly `pmset -a disablesleep 1|0` without a password; validates before AND after.
set -euo pipefail

TARGET_USER="${1:-${SUDO_USER:-}}"
DEST=/etc/sudoers.d/keep-mac-awake

if [ "$(id -u)" -ne 0 ]; then echo "Run as root: sudo $0 \"\$(id -un)\"" >&2; exit 1; fi
if [ -z "$TARGET_USER" ] || [ "$TARGET_USER" = root ]; then echo "usage: sudo $0 <your-username>" >&2; exit 1; fi
id "$TARGET_USER" >/dev/null

TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT
cat > "$TMP" <<EOF
# Keep Mac Awake: only these two exact commands, no wildcards.
$TARGET_USER ALL=(root) NOPASSWD: /usr/bin/pmset -a disablesleep 1, /usr/bin/pmset -a disablesleep 0
EOF

/usr/sbin/visudo -c -q -f "$TMP"
install -m 0440 -o root -g wheel "$TMP" "$DEST"
if ! /usr/sbin/visudo -c -q; then
	rm -f "$DEST"
	echo "sudoers check failed, removed $DEST" >&2
	exit 1
fi
echo "Installed $DEST for $TARGET_USER"
