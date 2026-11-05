<div align="center">

# ⛩ Shrine Waybar

**A warm, autumn-shrine Waybar + rofi setup for KDE Plasma on Bazzite**

Floating dark-wood pills · a Quickshell dynamic island · maple-red highlights · themed menus

![KDE Plasma](https://img.shields.io/badge/KDE_Plasma-Wayland-1D99F3?style=for-the-badge&logo=kde&logoColor=white)
![Bazzite](https://img.shields.io/badge/Bazzite-Fedora_Atomic-8A2BE2?style=for-the-badge&logo=fedora&logoColor=white)
![Waybar](https://img.shields.io/badge/Waybar-2A1D11?style=for-the-badge)
![rofi](https://img.shields.io/badge/rofi-CB3F27?style=for-the-badge)
![License](https://img.shields.io/badge/License-MIT-E18A42?style=for-the-badge)

<br>

<img src="screenshots/desktop.png" alt="Shrine Waybar desktop" width="100%">

<br><br>

<img src="screenshots/bar.png" alt="The bar" width="100%">

<br><br>

<img src="screenshots/island-demo.gif" alt="The dynamic island switching between music, clock, volume, stats, downloads and sync" width="760">

<sub>The dynamic island: drag or scroll to switch sections, click to open a card</sub>

</div>

<br>

## ✦ Gallery

<table>
  <tr>
    <th align="center">App launcher</th>
    <th align="center">Power menu</th>
  </tr>
  <tr>
    <td align="center"><img src="screenshots/launcher.png" alt="App launcher" width="400"></td>
    <td align="center"><img src="screenshots/power-menu.png" alt="Power menu" width="400"></td>
  </tr>
</table>

### Dynamic island cards

<table>
  <tr>
    <th align="center">Music</th>
    <th align="center">Volume</th>
    <th align="center">Stats</th>
  </tr>
  <tr>
    <td align="center"><img src="screenshots/island-music.png" alt="Music card with album art, visualiser and controls" width="290"></td>
    <td align="center"><img src="screenshots/island-volume.png" alt="Volume card with slider and output devices" width="260"></td>
    <td align="center"><img src="screenshots/island-stats.png" alt="Stats card with CPU, GPU and RAM bars" width="270"></td>
  </tr>
  <tr>
    <th align="center">Downloads</th>
    <th align="center">Nextcloud sync</th>
    <th align="center">Pop-up <sub>(copied image)</sub></th>
  </tr>
  <tr>
    <td align="center"><img src="screenshots/island-downloads.png" alt="Downloads card with recent files" width="290"></td>
    <td align="center"><img src="screenshots/island-sync.png" alt="Sync card showing Nextcloud is up to date" width="260"></td>
    <td align="center"><img src="screenshots/island-popup.png" alt="Pop-up for a copied image" width="260"></td>
  </tr>
</table>

### Waybar tooltips

<table>
  <tr>
    <th align="center">Per-core CPU</th>
    <th align="center">Temperature</th>
    <th align="center">RAM</th>
    <th align="center">Volume output</th>
  </tr>
  <tr>
    <td align="center"><img src="screenshots/cpu-tooltip.png" alt="CPU tooltip" width="200"></td>
    <td align="center"><img src="screenshots/temp-tooltip.png" alt="Temperature tooltip" width="200"></td>
    <td align="center"><img src="screenshots/ram-tooltip.png" alt="RAM tooltip" width="200"></td>
    <td align="center"><img src="screenshots/volume-tooltip.png" alt="Volume tooltip" width="200"></td>
  </tr>
</table>

## ✦ Features

| | Feature | What it does |
|:-:|---|---|
| 🔍 | **App launcher** | rofi menu with a shrine header image and search |
| 🔌 | **Power menu** | Shutdown, restart, sleep and logout in a matching theme |
| 🏝 | **Dynamic island** | Replaces the centre of the bar. Clock, music with a cava visualiser, volume, stats, downloads and Nextcloud sync, plus pop-ups for screenshots, downloads and finished commands. See [Dynamic island](#-dynamic-island) |
| 📊 | **System stats** | Temperature, CPU, RAM and volume. Click temp/RAM for btop, volume for pavucontrol |
| ⛩ | **Quick launch** | Dolphin, Bazaar and Brave, one click each |

## ✦ Dynamic island

The centre of the bar is a [Quickshell](https://quickshell.org) island that matches the pills around it. Drag sideways or scroll on it to switch sections, and click to open a card.

| Section | Collapsed | Card |
|---|---|---|
| Clock | Time, date on hover | Large time and full date |
| Music | Album art, title, visualiser. Click the art to pause | Art, artist, seekable progress bar, controls |
| Volume | Level and percentage | Slider, mute, one-click output switching. Scroll to adjust |
| Stats | CPU %, CPU and GPU temperature | CPU, GPU and RAM bars, Open System Monitor |
| Downloads | Download speed | In-progress files, 5 recent files, Open in Dolphin |
| Sync | Nextcloud state | Nextcloud's status, open the client or folder |

Music only shows while a player is open, and Sync only while the Nextcloud client is running.

It also pops out briefly for a new screenshot, a copied image, a finished download, a Nextcloud error, a volume change, or a command run with `island`:

```bash
island rpm-ostree upgrade   # pops a tick or a cross, with how long it took
```

Everything lives in `config/quickshell/`. Its [README](config/quickshell/README.md) covers each file and fixes for common problems.

## ✦ Palette

| | Colour | Hex | Used for |
|:-:|---|---|---|
| ![](https://img.shields.io/badge/-%20%20%20%20-2A1D11?style=flat-square) | Dark Wood | `#2A1D11` | Pill and menu backgrounds |
| ![](https://img.shields.io/badge/-%20%20%20%20-CB3F27?style=flat-square) | Maple Red | `#CB3F27` | Visualiser, highlights, calendar |
| ![](https://img.shields.io/badge/-%20%20%20%20-E18A42?style=flat-square) | Gold | `#E18A42` | Hover borders and glow |
| ![](https://img.shields.io/badge/-%20%20%20%20-FF8C00?style=flat-square) | Orange | `#FF8C00` | Tooltip frame, weekdays |
| ![](https://img.shields.io/badge/-%20%20%20%20-E5D3B3?style=flat-square) | Light Wood | `#E5D3B3` | Tooltip text |
| ![](https://img.shields.io/badge/-%20%20%20%20-87CEEB?style=flat-square) | Sky Blue | `#87CEEB` | Pill and menu outlines |

## ✦ Requirements

| Program | Used for |
|---|---|
| `waybar` | The bar itself |
| `quickshell` | The dynamic island (from a COPR, see install step 1) |
| `wl-clipboard` | Copied-image pop-ups on the island |
| `rofi` | App launcher and power menu |
| `cava` | The island's audio visualiser |
| `playerctl` | Optional: only the old Waybar now-playing module uses it |
| `kitty` + `btop` | Stats window when clicking temp/RAM |
| `pavucontrol` | Volume mixer when clicking volume |
| `python3` | The island's downloads watcher (already on Bazzite) |
| [JetBrainsMono Nerd Font](https://www.nerdfonts.com/font-downloads) | All the icons |

> [!NOTE]
> The quick-launch buttons open Dolphin (comes with KDE), Bazaar (comes with Bazzite), [Brave](https://flathub.org/apps/com.brave.Browser) and [Evolution](https://flathub.org/apps/org.gnome.Evolution) for the calendar (only if you add the Waybar `clock` module back). Swap any of them for your own apps (see [Customising](#-customising)).

## ✦ Install

### 1. Install the programs

Bazzite is an immutable (atomic) system, so packages are layered with `rpm-ostree`, not `dnf`. Quickshell isn't in the normal Fedora repos, so add its COPR first:

```bash
sudo curl -Lo /etc/yum.repos.d/quickshell.repo \
  "https://copr.fedorainfracloud.org/coprs/errornointernet/quickshell/repo/fedora-$(rpm -E %fedora)/errornointernet-quickshell-fedora-$(rpm -E %fedora).repo"

rpm-ostree install waybar rofi cava playerctl kitty btop pavucontrol quickshell wl-clipboard
systemctl reboot
```

If it complains a package is already installed, remove that one from the list and run it again. The installer in step 4 also tells you exactly what's missing.

Optional Flatpak apps for the buttons:

```bash
flatpak install flathub com.brave.Browser
flatpak install flathub org.gnome.Evolution   # Only for the optional Waybar clock module
```

### 2. Install the font

```bash
mkdir -p ~/.local/share/fonts/JetBrainsMonoNerd
curl -fLo /tmp/JetBrainsMono.zip https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip
unzip -o /tmp/JetBrainsMono.zip -d ~/.local/share/fonts/JetBrainsMonoNerd
fc-cache -f
```

### 3. Clone the repo

```bash
git clone https://github.com/Sevar-Naicker/Waybar.git ~/shrine-waybar
cd ~/shrine-waybar
```

> [!IMPORTANT]
> Keep this folder where it is. Your configs will point into it, so moving or deleting it breaks the bar.

### 4. Run the installer

```bash
./install.sh
```

The installer:

1. Checks for missing programs and the font, and prints the command to install them
2. Moves any existing `~/.config/waybar`, `~/.config/rofi`, `~/.config/quickshell` and autostart entries into `~/.config-backup/`
3. Symlinks the repo's configs into `~/.config`
4. Adds the `island` command to `~/.bashrc`
5. Restarts Waybar, then the dynamic island

> [!TIP]
> Because the configs are symlinked, any edit in `~/shrine-waybar/config/` takes effect live, and you can commit it straight to git.

### 5. Hide the KDE panel

Otherwise you'll have two bars. Right-click the KDE panel and choose **Show Panel Configuration**, then either:

- set **Visibility** to **Auto Hide**, to keep it as a backup, or
- click **Delete Panel**, to rely fully on Waybar

## ✦ Customising

| To change | Edit |
|---|---|
| Quick-launch apps | `on-click` in the `custom/dolphin`, `custom/torii` and `custom/brave` blocks of `config/waybar/config.jsonc`. For a Flatpak, use `flatpak run <app id>` |
| Terminal for stats | `kitty` in the `temperature` and `memory` blocks |
| Calendar app | `on-click` in the `clock` block (only used if you put `clock` back in `modules-center`) |
| Bar colours | `config/waybar/style.css` |
| Menu colours | `config/rofi/app_launcher.rasi` and `config/rofi/power.rasi` |
| Menu header image | Replace `config/rofi/shrine_header.png` with any PNG |
| Island sections and their order | `sectionOrder` in `config/quickshell/shell.qml` |
| Island colours | The hex colours in `config/quickshell/shell.qml` (same palette as above) |
| Screenshots folder the island watches | `ScreenshotsFolder` at the top of `config/quickshell/downloads.py` |

After editing, reload the bar:

```bash
pkill waybar; setsid -f waybar
```

The island reloads by itself whenever `shell.qml` is saved.

<details>
<summary><b>📁 Repo layout</b></summary>

```
shrine-waybar/
├── install.sh                  # Sets everything up (backs up your old configs first)
├── config/
│   ├── waybar/
│   │   ├── config.jsonc        # Bar layout and modules
│   │   ├── style.css           # Bar colours and pill styling
│   │   ├── mediaplayer.py      # Old now-playing module (not on the bar now, kept as an option)
│   │   └── cava.sh             # Old visualiser module (not on the bar now, kept as an option)
│   ├── rofi/
│   │   ├── launcher.sh         # Opens the app launcher
│   │   ├── power-menu.sh       # Opens the power menu
│   │   ├── app_launcher.rasi   # Launcher theme
│   │   ├── power.rasi          # Power menu theme
│   │   └── shrine_header.png   # Header image for both menus
│   ├── quickshell/
│   │   ├── shell.qml           # The dynamic island
│   │   ├── cava.conf           # Island visualiser settings
│   │   ├── stats.sh            # CPU, GPU and RAM readings
│   │   ├── downloads.py        # Downloads, screenshots and download speed
│   │   ├── clipboard.sh        # Watches for copied images
│   │   ├── clipboard-handler.sh
│   │   ├── island-command.sh   # The "island" terminal command
│   │   └── README.md           # Island details and troubleshooting
│   └── autostart/
│       ├── waybar.desktop      # Starts Waybar when you log into KDE
│       └── dynamic-island.desktop  # Starts the island
└── screenshots/
```

</details>

<details>
<summary><b>🛠 Troubleshooting</b></summary>

- **Icons show as boxes:** the Nerd Font isn't installed or the font cache is stale. Redo step 2, then log out and back in.
- **Music section missing from the island:** it only appears while a media player is open. Play something.
- **Island visualiser bars stay flat:** check that `cava` runs on its own in a terminal.
- **Two bars on login:** another autostart entry is also starting Waybar. Check `~/.config/autostart/`.
- **Waybar doesn't start on login:** check that `~/.config/autostart/waybar.desktop` exists, or add Waybar in **System Settings → Autostart**.
- **The island shows but can't be clicked:** Waybar is sitting on top of it. Check that `config/waybar/config.jsonc` has `"layer": "bottom"`, then reload Waybar.
- **The island doesn't appear:** run `qs log` to see what it printed, or start it by hand with `setsid -f qs`.
- **Reloading Waybar closes an app:** that app was opened before the `setsid -f` launch commands were added. Reopen it and it won't happen again.
- **Logout takes a few seconds:** that's KDE closing your apps and saving your session, which is normal.

</details>

<details>
<summary><b>↩ Uninstall</b></summary>

Remove the symlinks and restore your backup:

```bash
rm ~/.config/waybar ~/.config/rofi ~/.config/quickshell
rm ~/.config/autostart/waybar.desktop ~/.config/autostart/dynamic-island.desktop
cp -r ~/.config-backup/shrine-waybar-<date>/* ~/.config/   # Only if you had configs before
```

Then delete the `island-command.sh` line the installer added to `~/.bashrc`.

</details>

---

<div align="center">

Made by [Sevar Naicker](https://github.com/Sevar-Naicker) · Released under the [MIT License](LICENSE)

</div>
