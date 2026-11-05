# Dynamic Island

A Quickshell dynamic island that replaces the centre of the [Shrine Waybar](../../README.md). It sits level with the other Waybar pills, uses the same dark wood, blue outline and orange hover glow, and springs open into cards when clicked.

Built for Bazzite (KDE Plasma, Wayland) and runs on every monitor.

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

Music only appears while a media player is open, and Sync only while the Nextcloud client is running. The island returns to music (or the clock) after 10 seconds untouched.

**Pop-ups** — the island briefly pops out for:

- A new screenshot or finished download (click to open, right-click to show in Dolphin)
- A copied image (click to save it to Screenshots, right-click to open it)
- A Nextcloud sync error (click to open Nextcloud)
- A finished terminal command run with `island` (tick or cross, with how long it took)
- A volume change from the keyboard or another app

## Files

| File | Purpose |
| --- | --- |
| `shell.qml` | The island itself |
| `cava.conf` | Visualiser settings (12 bars, plain numbers out) |
| `stats.sh` | Prints CPU, GPU and RAM readings every 2 seconds |
| `downloads.py` | Watches Downloads and Screenshots, measures download speed |
| `clipboard.sh` | Watches the clipboard for copied images |
| `clipboard-handler.sh` | Saves a copied image to a temporary folder |
| `island-command.sh` | The `island` terminal command |

## Install

The repo's installer sets up the island along with Waybar and rofi. Follow the [main README](../../README.md#-install), which adds the Quickshell COPR, installs the programs and runs `./install.sh`.

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
| Turn off at login | System Settings → Autostart → Dynamic Island |
| Restart the whole bar | `pkill waybar; setsid -f waybar; sleep 1; pkill -x qs; setsid -f qs` |

Saving `shell.qml` reloads the island instantly, so edits show up without a restart.

## Troubleshooting

**The island shows but can't be clicked** — Waybar is sitting on top of it. Check that the Waybar config says `"layer": "bottom"`, then reload Waybar with `pkill -SIGUSR2 waybar`.

**Visualiser bars stay flat** — make sure `cava` runs on its own in a terminal.

**Stats show nothing for the GPU** — run `stats.sh`; a `-1` means that sensor wasn't found.

**No Sync section** — the Nextcloud client isn't running, or its tray icon isn't showing.

**Copied images don't pop up** — check `wl-paste --version`, and look in `qs log` for a "data-control" message.

**Screenshots don't pop up** — the island watches `~/Pictures/Screenshots`. If Spectacle saves somewhere else, change `ScreenshotsFolder` at the top of `downloads.py`.

## Still to come

- KDE Connect (calls, texts, phone battery, received files) once the Galaxy Z Fold 8 arrives
