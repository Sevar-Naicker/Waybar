// This file contains state shared between the island, the menus and the Waybar pills
// Keep awake lives here: Quickshell holds the screen awake, and the coffee pill on Waybar shows and toggles it
// So does the music EQ, so every screen's island shows the same preset

pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// Section: Shell state
Singleton
{
    id: shellState

    // Section: Keep awake
    // While true, every island window asks the compositor not to dim, lock or sleep the screen
    property bool keepAwake: false

    onKeepAwakeChanged: saveKeepAwake()

    // Starts off when the island starts, so the pill never shows a state that isn't true
    Component.onCompleted: saveKeepAwake()

    // Section: Music EQ
    // Whether Easy Effects is installed, which preset is on ("custom" once a slider has been moved), and the 10 band gains in dB
    property bool eqAvailable: false
    property string eqPreset: "flat"
    property var eqGains: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0]

    // Band labels, and the eight presets the music menu shows
    readonly property var eqBands: ["31", "63", "125", "250", "500", "1k", "2k", "4k", "8k", "16k"]
    readonly property var eqPresets: [
        { "name": "flat", "label": "Flat", "gains": [0, 0, 0, 0, 0, 0, 0, 0, 0, 0] },
        { "name": "bass", "label": "Bass", "gains": [6, 5, 4, 2, 0, 0, 0, 0, 0, 0] },
        { "name": "treble", "label": "Treble", "gains": [0, 0, 0, 0, 0, 1, 2, 4, 5, 6] },
        { "name": "vocal", "label": "Vocal", "gains": [-2, -2, -1, 0, 2, 3.5, 4, 3, 1, 0] },
        { "name": "pop", "label": "Pop", "gains": [-1, 1, 3, 4, 3, 0, -1, -1, 1, 2] },
        { "name": "rock", "label": "Rock", "gains": [4, 3, 2, 0, -1, -1, 1, 3, 4, 4] },
        { "name": "jazz", "label": "Jazz", "gains": [3, 2, 1, 2, -1, -1, 0, 1, 2, 3] },
        { "name": "classic", "label": "Classic", "gains": [4, 3, 2, 1, -1, -1, 0, 2, 3, 4] }
    ]

    // The setEqPreset function switches to one of the eight presets
    function setEqPreset(Name)
    {
        const Preset = eqPresets.find(Item => Item.name === Name);

        if (!Preset)
        {
            return;
        }

        eqPreset = Name;
        eqGains = Preset.gains.slice();
        eqSendTimer.stop();
        sendEq();
    }

    // The setEqBand function changes one band (from a slider); it's sent a moment after you stop dragging
    function setEqBand(Index, Gain)
    {
        const Gains = eqGains.slice();
        Gains[Index] = Math.round(Math.max(-12, Math.min(12, Gain)) * 2) / 2;
        eqGains = Gains;
        eqPreset = "custom";
        eqSendTimer.restart();
    }

    // The sendEq function writes the preset and loads it in Easy Effects (output only, so mic presets are untouched)
    function sendEq()
    {
        Quickshell.execDetached(["bash", Quickshell.env("HOME") + "/.config/shrine-waybar/run.sh", "eq-apply", eqPreset].concat(eqGains.map(Gain => String(Gain))));
    }

    Timer
    {
        id: eqSendTimer
        interval: 350
        onTriggered: shellState.sendEq()
    }

    // Asks once at start whether Easy Effects is there, and what was last picked
    Process
    {
        command: ["bash", Quickshell.env("HOME") + "/.config/shrine-waybar/run.sh", "eq-status"]
        running: true

        stdout: SplitParser
        {
            onRead: (Line) =>
            {
                try
                {
                    const Status = JSON.parse(Line);
                    shellState.eqAvailable = Status.available;
                    shellState.eqPreset = Status.saved.preset;
                    shellState.eqGains = Status.saved.gains;
                }
                catch (Problem)
                {
                }
            }
        }
    }

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
