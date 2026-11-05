#!/usr/bin/env bash
# This file contains the power menu: shutdown, restart, sleep and logout through a themed rofi list

# Section: Paths
ROFI_DIR="$HOME/.config/rofi"
HEADER_IMAGE="$ROFI_DIR/shrine_header.png"

# Section: Options
OPTIONS="󰐥 Shutdown\n󰜉 Restart\n󰤄 Sleep\n󰍃 Logout"

# The Log_Out function ends the session the right way for the desktop you're on
Log_Out()
{
    if [[ "$XDG_CURRENT_DESKTOP" == *KDE* ]]
    then
        for QDBUS in qdbus6 qdbus-qt6 qdbus
        do
            if command -v "$QDBUS" >/dev/null 2>&1
            then
                "$QDBUS" org.kde.Shutdown /Shutdown org.kde.Shutdown.logout
                return
            fi
        done
    elif [[ "$XDG_CURRENT_DESKTOP" == *Hyprland* ]]
    then
        hyprctl dispatch exit
        return
    fi

    # Fallback for any other desktop
    loginctl terminate-session "$XDG_SESSION_ID"
}

# Section: Menu
SELECTED=$(echo -e "$OPTIONS" | rofi -dmenu -i \
    -theme "$ROFI_DIR/power.rasi" \
    -theme-str "dummy { background-image: url(\"$HEADER_IMAGE\", width); }")

case "$SELECTED" in
    *Shutdown) systemctl poweroff ;;
    *Restart)  systemctl reboot ;;
    *Sleep)    systemctl suspend ;;
    *Logout)   Log_Out ;;
esac
