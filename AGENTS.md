# Keep Mac Awake: agent guide

A macOS menu bar app in one Swift file with two toggles: **Keep Mac Awake** (`pmset -a disablesleep`, needs a sudoers rule) and **Keep Screen Awake** (an IOKit display-sleep assertion, needs no permission).

## Installing it for a user

1. Check the requirements: macOS 14 or later (`sw_vers -productVersion`) and the Xcode Command Line Tools (`xcode-select -p` succeeds). If the tools are missing, ask the user to run `xcode-select --install`, wait until they say it finished, then continue.
2. Tell the user before you start: "macOS will show a password dialog. Type your password there."
3. From the repo root, run `./install.sh` with a command timeout of at least 5 minutes, because it waits while the user types into the dialog. It:
   - builds the app into `~/Applications/KeepMacAwake.app` (no root needed),
   - opens the native macOS password dialog to install `/etc/sudoers.d/keep-mac-awake`, and skips this when the rule already works,
   - starts the app.
4. Never ask for the user's password in chat, and never pipe a password into `sudo`.
5. Exit code 2 means the dialog was cancelled or couldn't open (for example over SSH). Show the user the `sudo ...` command the script printed, ask them to run it in their own terminal, then run `./install.sh` again.
6. Verify with `./install.sh --check`: all three lines must start with `ok`.
7. Tell the user where to find it: the cup icon in the menu bar. **Keep Mac Awake** keeps the Mac running with the lid closed. **Keep Screen Awake** keeps the screen on, which also stops auto-lock. To start it at login, they can add it under System Settings → General → Login Items.

To update: `git pull && ./install.sh`. To remove: `./uninstall.sh`, which also shows one password dialog.

## Working on the code

- `src/main.swift` is the whole app. `scripts/build.sh` builds it into `~/Applications`, and `./install.sh` also quits and restarts it.
- The app runs exactly `sudo -n /usr/bin/pmset -a disablesleep 1|0`, and `scripts/install-sudoers.sh` allows exactly those two commands. Change both together, and never add wildcards to the rule.
- `src/make-icon.swift` is the icon source. Delete `src/AppIcon.icns` to regenerate it.
- Keep code comments to one line.
