// This file contains state shared between the island, the menus and the Waybar pills
// Keep awake lives here: Quickshell holds the screen awake, and the coffee pill on Waybar shows and toggles it

pragma Singleton

import Quickshell
import QtQuick

// Section: Shell state
Singleton
{
    // Section: Keep awake
    // While true, every island window asks the compositor not to dim, lock or sleep the screen
    property bool keepAwake: false

    onKeepAwakeChanged: saveKeepAwake()

    // Starts off when the island starts, so the pill never shows a state that isn't true
    Component.onCompleted: saveKeepAwake()

    // Section: Functions

    // The saveKeepAwake function writes the state for the coffee pill, then tells Waybar to redraw it (signal 8)
    function saveKeepAwake()
    {
        Quickshell.execDetached(["sh", "-c",
            "mkdir -p \"$HOME/.local/state/shrine-waybar\" && printf '%s' \"$1\" > \"$HOME/.local/state/shrine-waybar/keepawake\"; pkill -RTMIN+8 -x waybar",
            "sh", keepAwake ? "on" : "off"]);
    }

    // The refreshNightLight function tells Waybar to redraw the night light pill straight away (signal 9)
    function refreshNightLight()
    {
        Quickshell.execDetached(["pkill", "-RTMIN+9", "-x", "waybar"]);
    }
}
