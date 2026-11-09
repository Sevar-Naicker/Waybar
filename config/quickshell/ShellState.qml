// This file contains state shared between the island, the menus and the Waybar pills
// Keep awake lives here: Quickshell holds the screen awake, and the coffee pill on Waybar shows and toggles it
// So does the music EQ, so every screen's island shows the same preset
// And the focus timer, so it keeps counting down while its menu is closed

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

    // Section: Focus timer
    // A Pomodoro timer that keeps running while the menu is closed; the island shows the countdown in place of the time
    // Phases: "idle" (waiting to start), "focus", "short" (short break) and "long" (long break after every fourth round)
    property string focusPhase: "idle"
    property bool focusRunning: false

    // Lengths in minutes, and whether notifications are held back while focusing
    property int focusMinutes: 25
    property int breakMinutes: 5
    property int longMinutes: 15
    property bool focusSilence: true
    readonly property int focusRoundsPerSet: 4

    // Seconds left and seconds in the whole phase
    property int focusLeft: focusMinutes * 60
    property int focusTotal: focusMinutes * 60

    // Focus rounds finished in this set of four
    property int focusRound: 0

    // Today's totals
    property string focusDay: ""
    property int focusTodaySeconds: 0
    property int focusTodayRounds: 0

    // When the running phase ends (ms since 1970), and how much of this focus phase is already in today's total
    property real focusEndsAt: 0
    property int focusCounted: 0

    // Whether notifications are being held back right now
    readonly property bool focusQuiet: focusSilence && focusPhase === "focus" && focusRunning

    // While idle, the countdown follows the focus length
    onFocusMinutesChanged:
    {
        if (focusPhase === "idle")
        {
            focusLeft = focusMinutes * 60;
            focusTotal = focusLeft;
        }
    }

    // The focusClock function shows the seconds left as mm:ss
    function focusClock()
    {
        const Minutes = Math.floor(focusLeft / 60);
        const Seconds = focusLeft % 60;
        return (Minutes < 10 ? "0" : "") + Minutes + ":" + (Seconds < 10 ? "0" : "") + Seconds;
    }

    // The focusToggle function starts, pauses or carries on the timer
    function focusToggle()
    {
        if (focusPhase === "idle")
        {
            focusBegin("focus");
        }
        else if (focusRunning)
        {
            focusTick();
            focusRunning = false;
            saveFocus();
        }
        else
        {
            focusEndsAt = Date.now() + focusLeft * 1000;
            focusRunning = true;
        }
    }

    // The focusBegin function starts a phase from the top
    function focusBegin(Phase)
    {
        const Minutes = Phase === "focus" ? focusMinutes : (Phase === "long" ? longMinutes : breakMinutes);

        focusPhase = Phase;
        focusTotal = Minutes * 60;
        focusLeft = focusTotal;
        focusCounted = 0;
        focusEndsAt = Date.now() + focusTotal * 1000;
        focusRunning = true;
    }

    // The focusReset function stops the timer and starts the set of four again
    function focusReset()
    {
        if (focusRunning)
        {
            focusTick();
        }

        focusPhase = "idle";
        focusRunning = false;
        focusRound = 0;
        focusTotal = focusMinutes * 60;
        focusLeft = focusTotal;
        saveFocus();
    }

    // The focusSkip function ends this phase now and moves on (no notification)
    function focusSkip()
    {
        if (focusPhase === "idle")
        {
            return;
        }

        if (focusRunning)
        {
            focusTick();
        }

        focusFinished(false);
    }

    // The focusTick function counts down, adds focus time to today, and moves on when a phase runs out
    function focusTick()
    {
        rollFocusDay();

        if (!focusRunning)
        {
            return;
        }

        focusLeft = Math.max(0, Math.ceil((focusEndsAt - Date.now()) / 1000));

        if (focusPhase === "focus")
        {
            const Done = focusTotal - focusLeft;
            focusTodaySeconds += Math.max(0, Done - focusCounted);
            focusCounted = Done;
        }

        if (focusLeft === 0)
        {
            focusFinished(true);
        }
    }

    // The focusFinished function moves to the next phase: a focus round leads into a break by itself, a break waits for you
    function focusFinished(Notify)
    {
        if (focusPhase === "focus")
        {
            focusRound += 1;

            // Only rounds that ran to the end count towards today
            if (Notify)
            {
                focusTodayRounds += 1;
            }

            const Long = focusRound >= focusRoundsPerSet;
            focusBegin(Long ? "long" : "short");

            if (Notify)
            {
                focusNotify("Focus round done", Long ? "Four rounds in. Take a " + longMinutes + " minute break." : "Take a " + breakMinutes + " minute break.");
            }
        }
        else
        {
            if (focusPhase === "long")
            {
                focusRound = 0;
            }

            focusPhase = "idle";
            focusRunning = false;
            focusTotal = focusMinutes * 60;
            focusLeft = focusTotal;

            if (Notify)
            {
                focusNotify("Break's over", "Ready for round " + (focusRound + 1) + " when you are.");
            }
        }

        saveFocus();
    }

    // The focusNotify function plays a chime and shows a notification (a moment later, once notifications are let through again)
    function focusNotify(Title, Body)
    {
        Quickshell.execDetached(["sh", "-c",
            "sleep 0.6; notify-send -a Focus -i chronometer \"$1\" \"$2\"; " +
            "canberra-gtk-play -i complete 2>/dev/null || paplay /usr/share/sounds/freedesktop/stereo/complete.oga 2>/dev/null",
            "sh", Title, Body]);
    }

    // The rollFocusDay function starts today's totals afresh after midnight
    function rollFocusDay()
    {
        const Today = Qt.formatDate(new Date(), "yyyy-MM-dd");

        if (focusDay !== Today)
        {
            focusDay = Today;
            focusTodaySeconds = 0;
            focusTodayRounds = 0;
        }
    }

    // The saveFocus function keeps the lengths and today's totals for next time
    function saveFocus()
    {
        const Saved = {
            "focusMinutes": focusMinutes, "breakMinutes": breakMinutes, "longMinutes": longMinutes, "silence": focusSilence,
            "day": focusDay, "seconds": focusTodaySeconds, "rounds": focusTodayRounds
        };

        Quickshell.execDetached(["sh", "-c",
            "mkdir -p \"$HOME/.local/state/shrine-waybar\" && printf '%s' \"$1\" > \"$HOME/.local/state/shrine-waybar/focus.json\"",
            "sh", JSON.stringify(Saved)]);
    }

    // Counts down once a second while running, and saves today's total every minute
    Timer
    {
        interval: 1000
        repeat: true
        running: shellState.focusRunning
        onTriggered: shellState.focusTick()
    }

    Timer
    {
        interval: 60000
        repeat: true
        running: shellState.focusRunning && shellState.focusPhase === "focus"
        onTriggered: shellState.saveFocus()
    }

    // Holds notifications back while focusing (KDE lets them through again as soon as this stops)
    Process
    {
        command: ["python3", Quickshell.env("HOME") + "/.config/quickshell/focus-quiet.py"]
        running: shellState.focusQuiet
    }

    // Loads the saved lengths and today's totals
    Process
    {
        command: ["sh", "-c", "cat \"$HOME/.local/state/shrine-waybar/focus.json\" 2>/dev/null"]
        running: true

        stdout: SplitParser
        {
            onRead: (Line) =>
            {
                try
                {
                    const Saved = JSON.parse(Line);
                    shellState.focusMinutes = Saved.focusMinutes || 25;
                    shellState.breakMinutes = Saved.breakMinutes || 5;
                    shellState.longMinutes = Saved.longMinutes || 15;
                    shellState.focusSilence = Saved.silence !== false;
                    shellState.focusDay = Saved.day || "";
                    shellState.focusTodaySeconds = Saved.seconds || 0;
                    shellState.focusTodayRounds = Saved.rounds || 0;
                    shellState.rollFocusDay();
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
