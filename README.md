<p align="center"><img src="docs/icon.png" width="128" alt=""></p>

<h1 align="center">Keep Mac Awake</h1>

<p align="center">
A tiny macOS menu bar app that keeps your Mac running with the lid closed.<br>
Builds, downloads and AI coding agents keep going while the laptop is shut.
</p>

<p align="center"><img src="docs/menu.png" width="300" alt="The menu: Keep Mac Awake (checked), Keep Screen Awake, Quit Keep Mac Awake"></p>

## What it does

Click the cup in the menu bar:

| Menu item | What happens | Under the hood |
|---|---|---|
| **Keep Mac Awake** | Your Mac doesn't sleep, not even with the lid closed. The screen still turns off and locks as usual; everything running keeps running. | `pmset -a disablesleep 1` |
| **Keep Screen Awake** | The screen doesn't turn off while you're idle. Switches itself off when you quit the app. | A `PreventUserIdleDisplaySleep` power assertion, the same one `caffeinate -d` uses |

The cup is filled while Keep Mac Awake is on. Hover over it to see what's on.

**Why not `caffeinate`?** It stops idle sleep, but closing the lid still puts the Mac to sleep (unless an external display and power are plugged in). Keep Mac Awake covers the lid.

## Install

Needs macOS 14 (Sonoma) or later and the Xcode Command Line Tools (`xcode-select --install`). It builds from source on your Mac, so there's no binary to trust.

### Ask your AI agent

Paste this into Claude Code, Codex, opencode or any other coding agent:

```text
Install Keep Mac Awake for me: clone https://github.com/HJ29/keep-mac-awake and follow its AGENTS.md.
```

The agent builds and starts the app. When macOS shows a password dialog, type your password there; it never passes through the agent.

### Or by hand

```bash
git clone https://github.com/HJ29/keep-mac-awake.git
cd keep-mac-awake
./install.sh
```

`install.sh` compiles the app into `~/Applications/KeepMacAwake.app`, asks for your password once (see below) and starts it. Run it again to update. `./install.sh --check` shows whether everything is in place.

To start it at login: **System Settings → General → Login Items → +** and pick KeepMacAwake.

## Why it asks for your password

Stopping lid-closed sleep (`pmset disablesleep`) needs root. Instead of running the app as root, the installer adds one file, `/etc/sudoers.d/keep-mac-awake`, that lets your user run exactly these two commands without a password:

```text
/usr/bin/pmset -a disablesleep 1
/usr/bin/pmset -a disablesleep 0
```

Nothing else, and no wildcards. The file is checked with `visudo` before and after it's installed, so it can't break `sudo`. Keep Screen Awake needs no permission at all.

## Good to know

- **Lid closed: plug it in and keep it out of a bag.** A shut laptop that's still working has a harder time getting rid of heat, and on battery it keeps draining.
- **Locking is fine.** With Keep Mac Awake on, the screen still turns off and locks; your apps keep running behind the lock screen.
- **Keep Screen Awake stops auto-lock.** If your Mac locks when the screen turns off (the usual setting), it won't lock itself while this is on. Press Control-Command-Q to lock it when you walk away. On a work Mac, check that this is allowed.
- **Keep Mac Awake stays on after you quit the app**, because it's a system setting. Switch it off in the menu first, or run `sudo pmset -a disablesleep 0`.
- **With the lid closed, the built-in screen is always off.** Keep Screen Awake matters with the lid open or with an external display.

## Uninstall

```bash
./uninstall.sh
```

It turns normal sleep back on and removes the app and the sudoers file (one password dialog).

## How it's built

One Swift file, [`src/main.swift`](src/main.swift), about 130 lines of AppKit with no dependencies. [`scripts/build.sh`](scripts/build.sh) compiles it with `swiftc` and signs it ad hoc. The menu reads the sleep setting from the system every 5 seconds, so it stays right even if you change it from the terminal.

## License

[MIT](LICENSE)
