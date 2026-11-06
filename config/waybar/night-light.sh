#!/bin/bash
# This file contains the night light module for the Shrine Waybar
# Run with no arguments for the pill's status, or with --toggle to switch KDE's night light on or off

# Section: Settings
# Anything warmer than this counts as night light being on (6500K is normal daylight)
WarmThreshold=6400
MoonIcon=$' '

# The read_temperature function asks KWin for the screen's current colour temperature
# Newer Plasma uses /org/kde/KWin/NightLight; older versions used /ColorCorrect
read_temperature()
{
    local Reply

    Reply=$(gdbus call --session --dest org.kde.KWin --object-path /org/kde/KWin/NightLight \
        --method org.freedesktop.DBus.Properties.Get org.kde.KWin.NightLight currentTemperature 2>/dev/null)

    if [[ -z "$Reply" ]]
    then
        Reply=$(gdbus call --session --dest org.kde.KWin --object-path /ColorCorrect \
            --method org.freedesktop.DBus.Properties.Get org.kde.kwin.ColorCorrect currentTemperature 2>/dev/null)
    fi

    # The reply looks like "(<uint32 4500>,)"; keep just the number
    echo "$Reply" | grep -oE '[0-9]{3,5}' | tail -n 1
}

# Section: Toggle
if [[ "$1" == "--toggle" ]]
then
    gdbus call --session --dest org.kde.kglobalaccel --object-path /component/kwin \
        --method org.kde.kglobalaccel.Component.invokeShortcut "Toggle Night Color" >/dev/null 2>&1
fi

# Section: Status
Temperature=$(read_temperature)

if [[ -z "$Temperature" ]]
then
    printf '{"text": "%s", "tooltip": "Night light\\nClick to toggle", "class": "unknown"}\n' "$MoonIcon"
elif (( Temperature < WarmThreshold ))
then
    printf '{"text": "%s", "tooltip": "Night light on (%sK)\\nClick to turn off", "class": "on"}\n' "$MoonIcon" "$Temperature"
else
    printf '{"text": "%s", "tooltip": "Night light off\\nClick to turn on", "class": "off"}\n' "$MoonIcon"
fi
