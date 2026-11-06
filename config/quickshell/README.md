# Dynamic Island

A Quickshell dynamic island that replaces the centre of the [Shrine Waybar](../../README.md). It sits level with the other Waybar pills, uses the same dark wood, blue outline and orange hover glow, and springs open into cards when clicked.

Built for KDE Plasma 6 on Wayland, on any distro, and runs on every monitor.

## What it does

**Sections** — drag sideways or scroll on the island to switch, click to open a card:

| Section | Collapsed | Expanded card |
| --- | --- | --- |
| Clock | Time (date on hover) | Large time and full date |
| Music | Album art, title, cava visualiser (click art to pause) | Art, title, artist, seekable progress bar, controls |
| Volume | Level bar and percentage | Slider, mute, one-click output device switching (scroll to adjust) |
| Stats | CPU %, CPU and GPU temperature | CPU, GPU and RAM bars, Open System Monitor |
| Downloads | Download speed, active count | In-progress downloads, 5 recent files, Open in Dolphin |
| Sync | Nextcloud state | Nextcloud's status text, open client or folder |
| Updates | What's waiting, or "Restart to update" | System and Flatpak status, Update now (in your terminal), Restart |

Music only appears while a media player is open, Sync only while the Nextcloud client is running, and Updates only when something's waiting. The island returns to music (or the clock) after 10 seconds untouched.

**Pop-ups** — the island briefly pops out for:

- A new screenshot or finished download (click to open, right-click to show in Dolphin)
- A copied image (click to save it to Screenshots, right-click to open it)
- New updates (click to open the updates card)
- A Nextcloud sync error (click to open Nextcloud)
- A finished terminal command run with `island` (tick or cross, with how long it took)
- A volume change from the keyboard or another app

## Files

| File | Purpose |
| --- | --- |
| `shell.qml` | The island itself, and where the menus are switched on |
| `Theme.qml` | Colours, font and animation speed the menus share |
| `MenuWindow.qml` | The drop-down window every menu opens in (closes on Esc or a click outside) |
| `Launcher.qml` | App launcher, with search, a calculator and web search |
| `Calculator.js` | Works out sums typed into the launcher |
| `PowerMenu.qml` | Lock, sleep, log out, restart and shut down |
| `cava.conf` | Visualiser settings (12 bars, plain numbers out) |
| `stats.sh` | Prints CPU, GPU and RAM readings every 2 seconds |
| `updates.sh` | Checks waiting updates with your system's package manager, plus Flatpak, at login and hourly |
| `downloads.py` | Watches Downloads and Screenshots, measures download speed |
| `clipboard.sh` | Watches the clipboard for copied images |
| `clipboard-handler.sh` | Saves a copied image to a temporary folder |
| `island-command.sh` | The `island` terminal command |

## Install

The repo's installer sets up the island along with Waybar and rofi. Follow the [main README](../../README.md#-install), which installs the programs for your system and runs `./install.sh`.

The island's buttons (Update now, Open in Dolphin, the sync folder, saving copied images, System Monitor) go through `config/shrine-waybar/run.sh`, and its folders come from your `shrine.conf`. See [Settings](../../README.md#-settings).

The installer:

- links this folder to `~/.config/quickshell`
- links `config/autostart/dynamic-island.desktop` so the island starts at login
- adds the `island` command to `~/.bashrc`
- starts the island after Waybar

The island depends on three Waybar settings, which the repo's `config/waybar/config.jsonc` already has:

- `"modules-center": []`: the island takes the centre
- `"layer": "bottom"`: keeps the island above Waybar, even after a Waybar reload
- `setsid -f` in front of every app `on-click`: reloading Waybar won't close those apps

## Everyday commands

| Task | Command |
| --- | --- |
| Restart the island | `pkill -x qs; setsid -f qs` |
| See warnings and errors | `qs log` |
| Check the stats feed | `bash ~/.config/quickshell/stats.sh` |
| Ping the island by hand | `qs ipc call island commandDone "test" 0 3` |
| Open a menu from a shortcut | `qs ipc call menus toggle launcher` (or `power`) |
| Turn off at login | System Settings → Autostart → Dynamic Island |
| Restart the whole bar | `pkill waybar; setsid -f waybar; sleep 1; pkill -x qs; setsid -f qs` |

Saving `shell.qml` reloads the island instantly, so edits show up without a restart.

## Troubleshooting

**The island shows but can't be clicked** — Waybar is sitting on top of it. Check that the Waybar config says `"layer": "bottom"`, then reload Waybar with `pkill -SIGUSR2 waybar`.

**Visualiser bars stay flat** — make sure `cava` runs on its own in a terminal.

**Updates never show** — run `bash ~/.config/quickshell/updates.sh 0`. It prints three things: `yes`/`no` (restart needed), the number of system updates, and the number of Flatpak updates (`-1` means it couldn't check). On Bazzite and other atomic systems, updates download by themselves, so the island shows them once they're ready to apply on restart. On Arch, `pacman-contrib` must be installed.

**Stats show nothing for the GPU** — run `stats.sh`; a `-1` means that sensor wasn't found.

**No Sync section** — the Nextcloud client isn't running, or its tray icon isn't showing.

**Copied images don't pop up** — check `wl-paste --version`, and look in `qs log` for a "data-control" message.

**Screenshots don't pop up** — the island watches `SHRINE_SCREENSHOTS_DIR` from your `shrine.conf` (the installer reads Spectacle's save folder). If you change where Spectacle saves, update that line.

## Still to come

- KDE Connect (calls, texts, phone battery, received files) once the Galaxy Z Fold 8 arrives, plus "Done" and "Next task" phone buttons for the Waybar task pill
