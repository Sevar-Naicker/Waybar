<div align="center">

# ⛩ Shrine Waybar

**A warm, autumn-shrine Waybar + rofi setup for KDE Plasma on Bazzite**

Floating dark-wood pills · maple-red highlights · live audio visualiser · themed menus

![KDE Plasma](https://img.shields.io/badge/KDE_Plasma-Wayland-1D99F3?style=for-the-badge&logo=kde&logoColor=white)
![Bazzite](https://img.shields.io/badge/Bazzite-Fedora_Atomic-8A2BE2?style=for-the-badge&logo=fedora&logoColor=white)
![Waybar](https://img.shields.io/badge/Waybar-2A1D11?style=for-the-badge)
![rofi](https://img.shields.io/badge/rofi-CB3F27?style=for-the-badge)
![License](https://img.shields.io/badge/License-MIT-E18A42?style=for-the-badge)

<br>

<img src="screenshots/desktop.png" alt="Shrine Waybar desktop" width="100%">

<br><br>

<img src="screenshots/bar.png" alt="The bar" width="100%">

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

<table>
  <tr>
    <th align="center">Year calendar <sub>(hover the clock)</sub></th>
    <th align="center">Per-core CPU <sub>(hover CPU)</sub></th>
  </tr>
  <tr>
    <td align="center"><img src="screenshots/calendar.png" alt="Calendar tooltip" width="520"></td>
    <td align="center"><img src="screenshots/cpu-tooltip.png" alt="CPU tooltip" width="260"></td>
  </tr>
</table>

<table>
  <tr>
    <th align="center">Temperature</th>
    <th align="center">RAM</th>
    <th align="center">Volume output</th>
  </tr>
  <tr>
    <td align="center"><img src="screenshots/temp-tooltip.png" alt="Temperature tooltip" width="260"></td>
    <td align="center"><img src="screenshots/ram-tooltip.png" alt="RAM tooltip" width="260"></td>
    <td align="center"><img src="screenshots/volume-tooltip.png" alt="Volume tooltip" width="260"></td>
  </tr>
</table>

## ✦ Features

| | Feature | What it does |
|:-:|---|---|
| 🔍 | **App launcher** | rofi menu with a shrine header image and search |
| 🔌 | **Power menu** | Shutdown, restart, sleep and logout in a matching theme |
| 🎵 | **Now playing + visualiser** | Current track from any player, joined to a live cava bar. Click to play/pause, scroll to skip. Hides when nothing's playing |
| 🗓 | **Year calendar** | Hover the clock for the full year. Scroll to change month, right-click to switch view |
| 📊 | **System stats** | Temperature, CPU, RAM and volume. Click temp/RAM for btop, volume for pavucontrol |
| ⛩ | **Quick launch** | Dolphin, Bazaar and Brave, one click each |

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
| `rofi` | App launcher and power menu |
| `cava` | Audio visualiser |
| `playerctl` | Now-playing info and media controls |
| `kitty` + `btop` | Stats window when clicking temp/RAM |
| `pavucontrol` | Volume mixer when clicking volume |
| `python3` | Now-playing script (already on Bazzite) |
| [JetBrainsMono Nerd Font](https://www.nerdfonts.com/font-downloads) | All the icons |

> [!NOTE]
> The quick-launch buttons open Dolphin (comes with KDE), Bazaar (comes with Bazzite), [Brave](https://flathub.org/apps/com.brave.Browser) and [Evolution](https://flathub.org/apps/org.gnome.Evolution) for the calendar. Swap any of them for your own apps (see [Customising](#-customising)).

## ✦ Install

### 1. Install the programs

Bazzite is an immutable (atomic) system, so packages are layered with `rpm-ostree`, not `dnf`:

```bash
rpm-ostree install waybar rofi cava playerctl kitty btop pavucontrol
systemctl reboot
```

If it complains a package is already installed, remove that one from the list and run it again. The installer in step 4 also tells you exactly what's missing.

Optional Flatpak apps for the buttons:

```bash
flatpak install flathub com.brave.Browser org.gnome.Evolution
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
2. Moves any existing `~/.config/waybar`, `~/.config/rofi` and Waybar autostart entry into `~/.config-backup/`
3. Symlinks the repo's configs into `~/.config`
4. Restarts Waybar

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
| Calendar app | `on-click` in the `clock` block |
| Bar colours | `config/waybar/style.css` |
| Menu colours | `config/rofi/app_launcher.rasi` and `config/rofi/power.rasi` |
| Menu header image | Replace `config/rofi/shrine_header.png` with any PNG |

After editing, reload the bar:

```bash
pkill waybar; setsid -f waybar
```

<details>
<summary><b>📁 Repo layout</b></summary>

```
shrine-waybar/
├── install.sh                  # Sets everything up (backs up your old configs first)
├── config/
│   ├── waybar/
│   │   ├── config.jsonc        # Bar layout and modules
│   │   ├── style.css           # Bar colours and pill styling
│   │   ├── mediaplayer.py      # Now-playing module (playerctl)
│   │   └── cava.sh             # Audio visualiser module
│   ├── rofi/
│   │   ├── launcher.sh         # Opens the app launcher
│   │   ├── power-menu.sh       # Opens the power menu
│   │   ├── app_launcher.rasi   # Launcher theme
│   │   ├── power.rasi          # Power menu theme
│   │   └── shrine_header.png   # Header image for both menus
│   └── autostart/
│       └── waybar.desktop      # Starts Waybar when you log into KDE
└── screenshots/
```

</details>

<details>
<summary><b>🛠 Troubleshooting</b></summary>

- **Icons show as boxes:** the Nerd Font isn't installed or the font cache is stale. Redo step 2, then log out and back in.
- **Visualiser or now-playing missing:** these hide when nothing is playing. Play something. If they still don't show, check that `cava` and `playerctl` are installed.
- **Two bars on login:** another autostart entry is also starting Waybar. Check `~/.config/autostart/`.
- **Waybar doesn't start on login:** check that `~/.config/autostart/waybar.desktop` exists, or add Waybar in **System Settings → Autostart**.
- **Logout takes a few seconds:** that's KDE closing your apps and saving your session, which is normal.

</details>

<details>
<summary><b>↩ Uninstall</b></summary>

Remove the symlinks and restore your backup:

```bash
rm ~/.config/waybar ~/.config/rofi ~/.config/autostart/waybar.desktop
cp -r ~/.config-backup/shrine-waybar-<date>/* ~/.config/   # Only if you had configs before
```

</details>

---

<div align="center">

Made by [Sevar Naicker](https://github.com/Sevar-Naicker) · Released under the [MIT License](LICENSE)

</div>
