// This file contains the dynamic island that replaces the centre of the Shrine Waybar

import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import Quickshell.Services.Mpris
import Quickshell.Io
import Quickshell.Services.Pipewire
import Quickshell.Services.SystemTray
import QtQuick
import QtQuick.Effects

// Section: Shell root
ShellRoot
{
    // Section: Clock source
    SystemClock
    {
        id: systemClock
        precision: SystemClock.Minutes
    }

    // Section: Visualiser source
    // One cava process shared by every monitor, only running while something plays
    Process
    {
        id: cavaProcess

        // Twelve bar heights from 0 to 1
        property var levels: []

        command: ["sh", "-c", "exec cava -p \"$HOME/.config/quickshell/cava.conf\""]
        running: Mpris.players.values.some(Player => Player.isPlaying)

        // Flatten the bars when cava stops
        onRunningChanged:
        {
            if (!running)
            {
                levels = [];
            }
        }

        stdout: SplitParser
        {
            onRead: (Line) =>
            {
                cavaProcess.levels = Line.split(";").filter(Value => Value !== "").map(Value => parseInt(Value) / 100);
            }
        }
    }

    // Section: System stats source
    // Reads one line from stats.sh every 2 seconds; -1 means that sensor isn't available
    Process
    {
        id: statsProcess

        property int cpuUsage: 0
        property int cpuTemp: -1
        property int gpuUsage: -1
        property int gpuTemp: -1
        property real ramUsed: 0
        property real ramTotal: 0

        command: ["sh", "-c", "exec bash \"$HOME/.config/quickshell/stats.sh\""]
        running: true

        stdout: SplitParser
        {
            onRead: (Line) =>
            {
                const Parts = Line.trim().split(/\s+/).map(Number);

                if (Parts.length < 6)
                {
                    return;
                }

                statsProcess.cpuUsage = Parts[0];
                statsProcess.cpuTemp = Parts[1];
                statsProcess.gpuUsage = Parts[2];
                statsProcess.gpuTemp = Parts[3];
                statsProcess.ramUsed = Parts[4];
                statsProcess.ramTotal = Parts[5];
            }
        }
    }

    // Section: Downloads source
    // Reads one JSON line per second from downloads.py
    Process
    {
        id: downloadsProcess

        property real speed: 0
        property var activeDownloads: []
        property var recentFiles: []
        property string downloadsFolder: ""

        // Fired once for each finished download or new screenshot
        signal fileArrived(var File)

        command: ["sh", "-c", "exec python3 \"$HOME/.config/quickshell/downloads.py\""]
        running: true

        stdout: SplitParser
        {
            onRead: (Line) =>
            {
                let Data;

                try
                {
                    Data = JSON.parse(Line);
                }
                catch (ParseError)
                {
                    return;
                }

                downloadsProcess.speed = Data.speed;
                downloadsProcess.activeDownloads = Data.active;
                downloadsProcess.recentFiles = Data.recent;
                downloadsProcess.downloadsFolder = Data.downloadsFolder;

                if (Data.arrival)
                {
                    downloadsProcess.fileArrived(Data.arrival);
                }
            }
        }
    }

    // Section: Clipboard source
    // Prints a file path every time an image is copied (needs wl-paste)
    Process
    {
        id: clipboardProcess

        // Fired once for each copied image
        signal imageCopied(string Path)

        command: ["sh", "-c", "exec bash \"$HOME/.config/quickshell/clipboard.sh\""]
        running: true

        stdout: SplitParser
        {
            onRead: (Line) =>
            {
                if (Line.trim() !== "")
                {
                    clipboardProcess.imageCopied(Line.trim());
                }
            }
        }
    }

    // Section: Command pings
    // Lets the terminal tell the island a command finished:  qs ipc call island commandDone "<command>" <exit code> <seconds>
    // Carries a finished command to every monitor's island
    // (kept outside the IpcHandler, which only allows one-argument signals)
    QtObject
    {
        id: commandRelay

        signal commandFinished(string CommandText, int ExitCode, int Seconds)
    }

    IpcHandler
    {
        id: islandIpc

        target: "island"

        // The commandDone function is what the terminal calls
        function commandDone(CommandText: string, ExitCode: int, Seconds: int): void
        {
            commandRelay.commandFinished(CommandText, ExitCode, Seconds);

            // Check for updates again straight after an update finishes
            if (CommandText.includes("update"))
            {
                updatesProcess.recheck();
            }
        }
    }

    // Section: Updates source
    // Reads "<restart yes/no> <system count> <app count>" from updates.sh at login and then hourly
    // A count of -1 means it couldn't be checked on this system (the island then leaves it out)
    Process
    {
        id: updatesProcess

        property bool restartNeeded: false
        property int systemCount: 0
        property int flatpakCount: 0
        property bool updatesWaiting: restartNeeded || systemCount > 0 || flatpakCount > 0

        // Seconds before the first check; shortened when rechecking after an update
        property int firstDelay: 30

        // Fired when updates appear that weren't waiting before
        signal updatesFound()

        command: ["sh", "-c", "exec bash \"$HOME/.config/quickshell/updates.sh\" " + firstDelay]
        running: true

        // The recheck function restarts the feed so it checks again in a couple of seconds
        function recheck()
        {
            firstDelay = 2;
            running = false;
            updatesRestartTimer.restart();
        }

        stdout: SplitParser
        {
            onRead: (Line) =>
            {
                const Parts = Line.trim().split(/\s+/);

                if (Parts.length < 3)
                {
                    return;
                }

                const WasWaiting = updatesProcess.updatesWaiting;
                updatesProcess.restartNeeded = Parts[0] === "yes";
                updatesProcess.systemCount = parseInt(Parts[1]);
                updatesProcess.flatpakCount = parseInt(Parts[2]);

                if (!WasWaiting && updatesProcess.updatesWaiting)
                {
                    updatesProcess.updatesFound();
                }
            }
        }
    }

    // Starts the updates feed again shortly after a recheck stops it
    Timer
    {
        id: updatesRestartTimer
        interval: 300
        onTriggered: updatesProcess.running = true
    }

    // Section: Menus
    // Each menu lives in its own file next to this one (Launcher.qml, PowerMenu.qml)
    Launcher
    {
        id: launcherMenu
    }

    PowerMenu
    {
        id: powerMenu
    }

    // Lets Waybar pills and keyboard shortcuts open the menus:  qs ipc call menus toggle launcher
    IpcHandler
    {
        target: "menus"

        // The toggle function opens a menu by name, or closes it if it's already open; only one menu is open at a time
        function toggle(Name: string): void
        {
            const Menus = { "launcher": launcherMenu, "power": powerMenu };
            const Wanted = Menus[Name];

            if (!Wanted)
            {
                return;
            }

            const WasOpen = Wanted.shown;

            for (const Key in Menus)
            {
                Menus[Key].shown = false;
            }

            Wanted.shown = !WasOpen;
        }
    }

    // Section: Audio source
    // PipeWire only fills in a device's volume and name once something tracks it
    PwObjectTracker
    {
        objects: [Pipewire.defaultAudioSink].concat(Pipewire.nodes.values.filter(Node => Node.isSink && !Node.isStream && Node.audio))
    }

    // Section: One island per monitor
    Variants
    {
        model: Quickshell.screens

        // Section: Island window
        PanelWindow
        {
            id: islandWindow

            // The monitor this island belongs to
            required property var modelData
            screen: modelData

            // Pin to the top edge only, so the compositor centres it horizontally
            anchors.top: true

            // Sit over Waybar instead of being pushed below it
            exclusionMode: ExclusionMode.Ignore

            // Leave room for the island to grow when expanded
            implicitWidth: 420
            implicitHeight: 240

            color: "transparent"
            WlrLayershell.namespace: "dynamic-island"

            // Only the pill catches clicks; the rest of the window lets them through
            mask: Region { item: islandPill }

            // Section: Island state
            property string currentSection: "clock"
            property var sectionOrder: ["clock", "music", "vol", "stats", "dl", "sync", "updates"]
            property bool expanded: false

            // Section: Pop-up state
            // A pop-up temporarily covers whichever section is showing
            property var popupFile: null

            // A message pop-up: { "icon", "colour", "title", "subtitle", "action" }
            property var popupMessage: null

            property bool popupActive: popupFile !== null || popupMessage !== null

            // Show a pop-up whenever a download finishes or a screenshot lands
            Connections
            {
                target: downloadsProcess

                function onFileArrived(File)
                {
                    islandWindow.showFilePopup(File);
                }
            }

            // Show a pop-up whenever an image is copied
            Connections
            {
                target: clipboardProcess

                function onImageCopied(Path)
                {
                    islandWindow.showFilePopup({
                        "name": Path.split("/").pop(),
                        "path": Path,
                        "image": true,
                        "screenshot": false,
                        "copied": true
                    });
                }
            }

            // Show a tick or a cross when a command run with "island" finishes
            Connections
            {
                target: commandRelay

                function onCommandFinished(CommandText, ExitCode, Seconds)
                {
                    const Succeeded = ExitCode === 0;

                    islandWindow.showMessagePopup({
                        "icon": Succeeded ? "\uf058" : "\uf057",
                        "colour": Succeeded ? "#8FBF7F" : "#CB3F27",
                        "title": CommandText,
                        "subtitle": Succeeded
                                    ? "Done in " + islandWindow.formatDuration(Seconds)
                                    : "Failed (exit " + ExitCode + ") after " + islandWindow.formatDuration(Seconds),
                        "action": "none"
                    });
                }
            }

            // The formatDuration function turns seconds into 42s, 3m 12s or 1h 4m
            function formatDuration(Seconds)
            {
                if (Seconds < 60)
                {
                    return Seconds + "s";
                }

                if (Seconds < 3600)
                {
                    return Math.floor(Seconds / 60) + "m " + (Seconds % 60) + "s";
                }

                return Math.floor(Seconds / 3600) + "h " + Math.floor((Seconds % 3600) / 60) + "m";
            }

            // The saveCopiedImage function copies a clipboard image into the Screenshots folder
            function saveCopiedImage(Path)
            {
                Quickshell.execDetached(["sh", "-c", "exec bash \"$HOME/.config/shrine-waybar/run.sh\" save-image \"$1\"", "sh", Path]);
            }

            // The showFilePopup function pops the island out with a new file for 5 seconds
            function showFilePopup(File)
            {
                expanded = false;
                popupMessage = null;
                popupFile = File;
                popupTimer.restart();
            }

            // The showMessagePopup function pops the island out with an icon, title and subtitle for 5 seconds
            function showMessagePopup(Message)
            {
                expanded = false;
                popupFile = null;
                popupMessage = Message;
                popupTimer.restart();
            }

            // The dismissPopup function closes the pop-up and returns to the section underneath
            function dismissPopup()
            {
                popupFile = null;
                popupMessage = null;
                popupTimer.stop();
            }

            // The openFile function opens a file in its default app
            function openFile(Path)
            {
                Quickshell.execDetached(["xdg-open", Path]);
            }

            // The showInDolphin function opens Dolphin with the file highlighted
            function showInDolphin(Path)
            {
                Quickshell.execDetached(["sh", "-c", "exec bash \"$HOME/.config/shrine-waybar/run.sh\" show-file \"$1\"", "sh", Path]);
            }

            // The formatBytes function turns a byte count into KB, MB or GB
            function formatBytes(Bytes)
            {
                if (Bytes >= 1073741824)
                {
                    return (Bytes / 1073741824).toFixed(1) + " GB";
                }

                if (Bytes >= 1048576)
                {
                    return (Bytes / 1048576).toFixed(1) + " MB";
                }

                return Math.round(Bytes / 1024) + " KB";
            }

            // Section: Nextcloud state
            // The Nextcloud client's tray icon, if it's running
            property var syncItem: SystemTray.items.values.find(Item => ((Item.id || "") + " " + (Item.title || "")).toLowerCase().includes("nextcloud")) ?? null

            // Whatever status text Nextcloud is showing, with any formatting tags removed
            property string syncText:
            {
                if (!syncItem)
                {
                    return "";
                }

                const Parts = [syncItem.tooltipTitle, syncItem.tooltipDescription].filter(Part => Part && Part.trim() !== "");
                const Joined = Parts.length > 0 ? Parts.join(" — ") : (syncItem.title || "");
                return Joined.replace(/<[^>]*>/g, " ").replace(/\s+/g, " ").trim();
            }

            // Reads Nextcloud's status text and sorts it into one of five states
            property string syncState:
            {
                if (!syncItem)
                {
                    return "none";
                }

                const Lower = syncText.toLowerCase();

                if (/error|fail|conflict|problem|could not|couldn't/.test(Lower))
                {
                    return "error";
                }

                if (/disconnect|offline|no connection|not connected|signed out|log in|unavailable/.test(Lower))
                {
                    return "offline";
                }

                if (/paus/.test(Lower))
                {
                    return "paused";
                }

                if (/up to date|synced|all files|success|last sync/.test(Lower))
                {
                    return "ok";
                }

                // Only phrases that mean files are moving right now, not any mention of "sync"
                if (/syncing|sync is running|preparing|checking|uploading|downloading|\d+ of \d+|%/.test(Lower))
                {
                    return "syncing";
                }

                return "ok";
            }

            // Fall back to the clock if Nextcloud closes while its section is showing
            onSyncItemChanged:
            {
                if (syncItem === null && currentSection === "sync")
                {
                    currentSection = "clock";
                }
            }

            // Pop up when syncing goes wrong
            onSyncStateChanged:
            {
                if (syncState === "error" && !startupGuard.running)
                {
                    showMessagePopup({
                        "icon": "\uf071",
                        "colour": "#CB3F27",
                        "title": "Nextcloud sync problem",
                        "subtitle": "Click to open Nextcloud",
                        "action": "nextcloud"
                    });
                }
            }

            // The syncLabel function gives a short word for the current sync state
            function syncLabel()
            {
                switch (syncState)
                {
                    case "syncing": return "Syncing";
                    case "paused": return "Paused";
                    case "offline": return "Offline";
                    case "error": return "Sync error";
                    default: return "Synced";
                }
            }

            // The syncIcon function picks a glyph for the current sync state
            function syncIcon()
            {
                switch (syncState)
                {
                    case "syncing": return "\uf021";
                    case "paused": return "\uf04c";
                    case "offline": return "\uf127";
                    case "error": return "\uf071";
                    default: return "\uf0c2";
                }
            }

            // The syncColour function colours the icon: red for problems, grey for paused/offline, white otherwise
            function syncColour()
            {
                if (syncState === "error")
                {
                    return "#CB3F27";
                }

                if (syncState === "paused" || syncState === "offline")
                {
                    return "#86979A";
                }

                return "#ffffff";
            }

            // The openNextcloud function brings up the Nextcloud client window
            function openNextcloud()
            {
                if (syncItem)
                {
                    syncItem.activate();
                }

                expanded = false;
            }

            // Section: Updates state

            // Pop up when updates appear; clicking opens the updates card
            Connections
            {
                target: updatesProcess

                function onUpdatesFound()
                {
                    const Counts = islandWindow.countsLabel();

                    islandWindow.showMessagePopup({
                        "icon": Counts === "" ? "\uf01e" : "\uf0ed",
                        "colour": "#E5D3B3",
                        "title": Counts === "" ? "Restart to finish updating" : "Updates available",
                        "subtitle": (updatesProcess.restartNeeded && Counts !== "" ? "Restart needed · " : "") + (Counts !== "" ? Counts + " · " : "") + "click for details",
                        "action": "updates"
                    });
                }
            }

            // Fall back to the clock once everything's updated
            Connections
            {
                target: updatesProcess

                function onUpdatesWaitingChanged()
                {
                    if (!updatesProcess.updatesWaiting && islandWindow.currentSection === "updates")
                    {
                        islandWindow.currentSection = "clock";
                    }
                }
            }

            // The countsLabel function words what's waiting, e.g. "3 app updates" or "12 system · 3 app updates"
            function countsLabel()
            {
                const Parts = [];
                let Total = 0;

                if (updatesProcess.systemCount > 0)
                {
                    Parts.push(updatesProcess.systemCount + " system");
                    Total += updatesProcess.systemCount;
                }

                if (updatesProcess.flatpakCount > 0)
                {
                    Parts.push(updatesProcess.flatpakCount + " app");
                    Total += updatesProcess.flatpakCount;
                }

                if (Total === 0)
                {
                    return "";
                }

                return Parts.join(" · ") + (Total === 1 ? " update" : " updates");
            }

            // The updatesSummary function gives the short collapsed text for the updates section
            function updatesSummary()
            {
                const Counts = countsLabel();

                if (updatesProcess.restartNeeded)
                {
                    return Counts === "" ? "Restart to update" : "Restart · " + Counts;
                }

                return Counts;
            }

            // The updateRowText function words one row of the updates card: 0 is the system, 1 is apps
            function updateRowText(Row)
            {
                const Count = Row === 0 ? updatesProcess.systemCount : updatesProcess.flatpakCount;
                const Restart = Row === 0 && updatesProcess.restartNeeded;

                if (Count < 0 && !Restart)
                {
                    return "Not checked on this system";
                }

                if (Count > 0)
                {
                    return Count + " waiting" + (Restart ? " · restart needed" : "");
                }

                return Restart ? "Restart to apply" : "Up to date";
            }

            // The runUpdate function runs this system's update in a terminal; the island pings when it's done
            function runUpdate()
            {
                Quickshell.execDetached(["sh", "-c", "exec bash \"$HOME/.config/shrine-waybar/run.sh\" update"]);
                expanded = false;
            }

            // The promptRestart function opens KDE's own restart dialog, which asks before doing anything
            function promptRestart()
            {
                Quickshell.execDetached(["gdbus", "call", "--session", "--dest", "org.kde.LogoutPrompt",
                                         "--object-path", "/LogoutPrompt", "--method", "org.kde.LogoutPrompt.promptReboot"]);
                expanded = false;
            }

            // Section: Volume state
            property var audioSink: Pipewire.defaultAudioSink
            property real sinkVolume: audioSink && audioSink.audio ? audioSink.audio.volume : 0
            property bool sinkMuted: audioSink && audioSink.audio ? audioSink.audio.muted : false

            // Every real output device (speakers, headphones, HDMI), not app streams
            property var outputDevices: Pipewire.nodes.values.filter(Node => Node.isSink && !Node.isStream && Node.audio)

            // Where to go back to after the volume pop-up
            property string sectionBeforeVolume: "clock"

            // Flip to volume briefly when it changes from anywhere (keyboard keys, other apps)
            onSinkVolumeChanged: showVolumePopup()
            onSinkMutedChanged: showVolumePopup()

            // The showVolumePopup function flips to the volume section for two seconds
            function showVolumePopup()
            {
                // Ignore the burst of changes while PipeWire connects at startup
                if (startupGuard.running)
                {
                    return;
                }

                // Already looking at volume, so just keep it open
                if (currentSection === "vol")
                {
                    idleTimer.restart();
                    return;
                }

                // Don't pull an open card out from under the mouse
                if (expanded)
                {
                    return;
                }

                sectionBeforeVolume = currentSection;
                currentSection = "vol";
                volumeReturnTimer.restart();
                idleTimer.restart();
            }

            // The setVolume function clamps and applies a new volume (0 to 1)
            function setVolume(NewVolume)
            {
                if (audioSink && audioSink.audio)
                {
                    audioSink.audio.muted = false;
                    audioSink.audio.volume = Math.max(0, Math.min(1, NewVolume));
                }
            }

            // The deviceName function picks the friendliest name a device offers
            function deviceName(Node)
            {
                return Node.nickname || Node.description || Node.name;
            }

            // The tempColour function turns a temperature maple red at 80°C, matching the Waybar threshold
            function tempColour(Temp)
            {
                return Temp >= 80 ? "#CB3F27" : "#ffffff";
            }

            // The statRow function returns the label, fill, colour and reading for one stats row
            function statRow(Index)
            {
                if (Index === 0)
                {
                    return {
                        "label": "CPU",
                        "fill": statsProcess.cpuUsage / 100,
                        "colour": "#CB3F27",
                        "show": true,
                        "reading": statsProcess.cpuUsage + "%" + (statsProcess.cpuTemp >= 0 ? " · " + statsProcess.cpuTemp + "°" : "")
                    };
                }

                if (Index === 1)
                {
                    return {
                        "label": "GPU",
                        "fill": statsProcess.gpuUsage / 100,
                        "colour": "#FF8C00",
                        "show": statsProcess.gpuUsage >= 0 || statsProcess.gpuTemp >= 0,
                        "reading": (statsProcess.gpuUsage >= 0 ? statsProcess.gpuUsage + "%" : "") + (statsProcess.gpuTemp >= 0 ? " · " + statsProcess.gpuTemp + "°" : "")
                    };
                }

                return {
                    "label": "RAM",
                    "fill": statsProcess.ramTotal > 0 ? statsProcess.ramUsed / statsProcess.ramTotal : 0,
                    "colour": "#E5D3B3",
                    "show": true,
                    "reading": statsProcess.ramUsed.toFixed(1) + " / " + Math.round(statsProcess.ramTotal) + "G"
                };
            }

            // The openSystemMonitor function launches KDE's System Monitor, independent of the island
            function openSystemMonitor()
            {
                Quickshell.execDetached(["sh", "-c", "exec bash \"$HOME/.config/shrine-waybar/run.sh\" system-monitor"]);
                expanded = false;
            }

            // The volumeIcon function picks a speaker glyph for the current level
            function volumeIcon()
            {
                if (sinkMuted || sinkVolume === 0)
                {
                    return "\uf026";
                }

                return sinkVolume < 0.5 ? "\uf027" : "\uf028";
            }

            // The last player that was actually playing, so pausing doesn't hand control to another tab
            property var lastPlayedPlayer: null

            // Prefer what's playing, then what was last playing, then anything that can play
            property var activePlayer:
            {
                const AllPlayers = Mpris.players.values;
                const Playing = AllPlayers.find(Player => Player.isPlaying);

                if (Playing)
                {
                    return Playing;
                }

                if (lastPlayedPlayer && AllPlayers.includes(lastPlayedPlayer))
                {
                    return lastPlayedPlayer;
                }

                return AllPlayers.find(Player => Player.canPlay) ?? AllPlayers[0] ?? null;
            }

            property bool musicPlaying: activePlayer ? activePlayer.isPlaying : false

            // Jump to music when something starts playing, and remember that player
            onMusicPlayingChanged:
            {
                if (musicPlaying)
                {
                    lastPlayedPlayer = activePlayer;
                    currentSection = "music";
                    idleTimer.restart();
                }
            }

            // Track player switches, and fall back to the clock if the player closes
            onActivePlayerChanged:
            {
                if (activePlayer && activePlayer.isPlaying)
                {
                    lastPlayedPlayer = activePlayer;
                }

                if (activePlayer === null && currentSection === "music")
                {
                    currentSection = "clock";
                }
            }

            // The togglePlayback function plays or pauses, but only if the player allows it
            function togglePlayback()
            {
                if (activePlayer && activePlayer.canTogglePlaying)
                {
                    activePlayer.togglePlaying();
                }
            }

            // Section: Section logic

            // The isSectionAvailable function says whether a section has anything to show
            function isSectionAvailable(SectionName)
            {
                if (SectionName === "music")
                {
                    return activePlayer !== null;
                }

                if (SectionName === "sync")
                {
                    return syncItem !== null;
                }

                if (SectionName === "updates")
                {
                    return updatesProcess.updatesWaiting;
                }

                return true;
            }

            // The switchSection function moves one section left or right, skipping empty ones
            function switchSection(Direction)
            {
                dismissPopup();
                const Available = sectionOrder.filter(Name => isSectionAvailable(Name));
                const CurrentIndex = Available.indexOf(currentSection);
                currentSection = Available[(CurrentIndex + Direction + Available.length) % Available.length];
                idleTimer.restart();
            }

            // The formatTime function turns seconds into m:ss
            function formatTime(Seconds)
            {
                const Whole = Math.max(0, Math.floor(Seconds));
                const Minutes = Math.floor(Whole / 60);
                const Rest = Whole % 60;
                return Minutes + ":" + (Rest < 10 ? "0" : "") + Rest;
            }

            // Section: Island pill
            Rectangle
            {
                id: islandPill

                // Waybar margin-top (5) + module margin (4) lines it up with the other pills
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                anchors.topMargin: 9

                // How wide the current section's collapsed content is
                property real collapsedContentWidth:
                {
                    if (islandWindow.currentSection === "music")
                    {
                        return musicRow.implicitWidth;
                    }

                    if (islandWindow.currentSection === "vol")
                    {
                        return volumeRow.implicitWidth;
                    }

                    if (islandWindow.currentSection === "stats")
                    {
                        return statsRow.implicitWidth;
                    }

                    if (islandWindow.currentSection === "dl")
                    {
                        return downloadsRow.implicitWidth;
                    }

                    if (islandWindow.currentSection === "sync")
                    {
                        return syncRow.implicitWidth;
                    }

                    if (islandWindow.currentSection === "updates")
                    {
                        return updatesRow.implicitWidth;
                    }

                    return clockLabel.implicitWidth;
                }

                // Card size per section when expanded; volume grows with the number of devices
                property var expandedSize:
                {
                    if (islandWindow.currentSection === "music")
                    {
                        return [380, 140];
                    }

                    if (islandWindow.currentSection === "vol")
                    {
                        return [320, volumeCard.implicitHeight + 28];
                    }

                    if (islandWindow.currentSection === "stats")
                    {
                        return [340, statsCard.implicitHeight + 28];
                    }

                    if (islandWindow.currentSection === "dl")
                    {
                        return [360, downloadsCard.implicitHeight + 28];
                    }

                    if (islandWindow.currentSection === "sync")
                    {
                        return [320, syncCard.implicitHeight + 28];
                    }

                    if (islandWindow.currentSection === "updates")
                    {
                        return [320, updatesCard.implicitHeight + 28];
                    }

                    return [280, 96];
                }

                // Collapsed: never narrower than 130px. Expanded: the section's card size
                // Pop-up first, then the open card, then the collapsed pill
                width: islandWindow.popupActive ? 350 : (islandWindow.expanded ? expandedSize[0] : Math.max(130, collapsedContentWidth + 48))
                height: islandWindow.popupActive ? 58 : (islandWindow.expanded ? expandedSize[1] : 26)
                radius: islandWindow.popupActive ? 20 : (islandWindow.expanded ? 22 : 13)
                clip: true

                // Shrine "dark wood" pill with the blue outline
                // On hover it copies the Waybar pills: red background, orange outline, orange glow
                // (open cards and pop-ups keep the wood background so their text stays easy to read)
                color: islandHover.hovered && !islandWindow.expanded && !islandWindow.popupActive ? "#99931A13" : "#EB2A1D11"
                border.width: 1
                border.color: islandHover.hovered ? "#E18A42" : "#86979A"

                // Same 0.3s fade as the Waybar transition
                Behavior on color { ColorAnimation { duration: 300 } }
                Behavior on border.color { ColorAnimation { duration: 300 } }

                // Section: Hover glow
                // Matches the Waybar box-shadow: 0 0 10px rgba(225, 138, 66, 0.4)
                layer.enabled: true
                layer.effect: MultiEffect
                {
                    autoPaddingEnabled: true
                    shadowEnabled: true
                    shadowColor: "#E18A42"
                    shadowBlur: 0.6
                    shadowHorizontalOffset: 0
                    shadowVerticalOffset: 0
                    shadowOpacity: islandHover.hovered ? 0.4 : 0

                    Behavior on shadowOpacity { NumberAnimation { duration: 300 } }
                }

                // Springy resize with a little overshoot
                Behavior on width
                {
                    NumberAnimation { duration: 450; easing.type: Easing.OutBack; easing.overshoot: 1.4 }
                }

                Behavior on height
                {
                    NumberAnimation { duration: 450; easing.type: Easing.OutBack; easing.overshoot: 1.2 }
                }

                Behavior on radius
                {
                    NumberAnimation { duration: 300 }
                }

                // Section: Hover tracking
                HoverHandler
                {
                    id: islandHover

                    // Start the auto-collapse countdown when the mouse leaves
                    onHoveredChanged:
                    {
                        if (hovered)
                        {
                            collapseTimer.stop();
                        }
                        else if (islandWindow.expanded)
                        {
                            collapseTimer.restart();
                        }
                    }
                }

                // Section: Timers

                // Closes the file pop-up after 5 seconds, unless the mouse is on it
                Timer
                {
                    id: popupTimer
                    interval: 5000
                    onTriggered:
                    {
                        if (islandHover.hovered)
                        {
                            restart();
                            return;
                        }

                        islandWindow.dismissPopup();
                    }
                }

                // Stops one scroll flick from skipping several sections
                Timer
                {
                    id: wheelCooldown
                    interval: 350
                }

                // Closes the card shortly after the mouse leaves it
                Timer
                {
                    id: collapseTimer
                    interval: 900
                    onTriggered: islandWindow.expanded = false
                }

                // Returns to music or the clock after 10 seconds of no interaction
                Timer
                {
                    id: idleTimer
                    interval: 10000
                    onTriggered:
                    {
                        if (islandHover.hovered)
                        {
                            restart();
                            return;
                        }

                        islandWindow.expanded = false;
                        islandWindow.currentSection = islandWindow.musicPlaying ? "music" : "clock";
                    }
                }

                // Ignores volume changes for the first two seconds while PipeWire connects
                Timer
                {
                    id: startupGuard
                    interval: 2000
                    running: true
                }

                // Hands back to the previous section two seconds after the volume pop-up
                Timer
                {
                    id: volumeReturnTimer
                    interval: 2000
                    onTriggered:
                    {
                        if (islandHover.hovered || islandWindow.expanded)
                        {
                            return;
                        }

                        if (islandWindow.currentSection === "vol")
                        {
                            islandWindow.currentSection = islandWindow.sectionBeforeVolume;
                        }
                    }
                }

                // Media players don't push their position, so ask for it every second while the card is open
                Timer
                {
                    interval: 1000
                    repeat: true
                    running: islandWindow.expanded && islandWindow.currentSection === "music" && islandWindow.musicPlaying
                    onTriggered: islandWindow.activePlayer.positionChanged()
                }

                // Section: Mouse handling
                // Sits underneath the content, so buttons inside the card get their clicks first
                MouseArea
                {
                    id: islandArea

                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton | Qt.RightButton

                    property real pressX: 0
                    property bool dragged: false

                    onPressed: (Mouse) =>
                    {
                        pressX = Mouse.x;
                        dragged = false;
                    }

                    // A sideways drag of 30px switches section
                    onPositionChanged: (Mouse) =>
                    {
                        if (pressed && !dragged && Math.abs(Mouse.x - pressX) > 30)
                        {
                            dragged = true;
                            islandWindow.switchSection(Mouse.x < pressX ? 1 : -1);
                        }
                    }

                    // On a pop-up: click opens the file, right-click shows it in Dolphin. Otherwise a click opens or closes the card
                    onClicked: (Mouse) =>
                    {
                        if (dragged)
                        {
                            return;
                        }

                        // Message pop-up: click runs its action, if it has one
                        if (islandWindow.popupMessage !== null)
                        {
                            if (islandWindow.popupMessage.action === "nextcloud")
                            {
                                islandWindow.openNextcloud();
                            }

                            // Updates pop-up opens the updates card
                            if (islandWindow.popupMessage.action === "updates")
                            {
                                islandWindow.dismissPopup();
                                islandWindow.currentSection = "updates";
                                islandWindow.expanded = true;
                                idleTimer.restart();
                                return;
                            }

                            islandWindow.dismissPopup();
                            return;
                        }

                        // Copied image: click saves it, right-click opens it
                        if (islandWindow.popupActive && islandWindow.popupFile.copied)
                        {
                            if (Mouse.button === Qt.RightButton)
                            {
                                islandWindow.openFile(islandWindow.popupFile.path);
                            }
                            else
                            {
                                islandWindow.saveCopiedImage(islandWindow.popupFile.path);
                            }

                            islandWindow.dismissPopup();
                            return;
                        }

                        if (islandWindow.popupActive)
                        {
                            if (Mouse.button === Qt.RightButton)
                            {
                                islandWindow.showInDolphin(islandWindow.popupFile.path);
                            }
                            else
                            {
                                islandWindow.openFile(islandWindow.popupFile.path);
                            }

                            islandWindow.dismissPopup();
                            return;
                        }

                        if (Mouse.button === Qt.RightButton)
                        {
                            return;
                        }

                        islandWindow.expanded = !islandWindow.expanded;
                        idleTimer.restart();
                    }

                    // Scrolling switches section, one step per flick; on the open volume card it changes the level
                    onWheel: (Wheel) =>
                    {
                        if (islandWindow.expanded && islandWindow.currentSection === "vol")
                        {
                            islandWindow.setVolume(islandWindow.sinkVolume + (Wheel.angleDelta.y > 0 ? 0.05 : -0.05));
                            idleTimer.restart();
                            return;
                        }

                        if (wheelCooldown.running)
                        {
                            return;
                        }

                        wheelCooldown.start();
                        islandWindow.switchSection(Wheel.angleDelta.y < 0 ? 1 : -1);
                    }
                }

                // Section: Clock, collapsed
                Text
                {
                    id: clockLabel

                    anchors.centerIn: parent
                    text: islandHover.hovered
                          ? Qt.formatDateTime(systemClock.date, "ddd d MMM")
                          : Qt.formatDateTime(systemClock.date, "HH:mm")
                    color: "#ffffff"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 13
                    font.bold: true

                    opacity: islandWindow.currentSection === "clock" && !islandWindow.expanded && !islandWindow.popupActive ? 1 : 0
                    visible: opacity > 0
                    Behavior on opacity { NumberAnimation { duration: 200 } }
                }

                // Section: Clock, expanded
                Column
                {
                    anchors.centerIn: parent
                    spacing: 2

                    opacity: islandWindow.currentSection === "clock" && islandWindow.expanded && !islandWindow.popupActive ? 1 : 0
                    visible: opacity > 0
                    Behavior on opacity { NumberAnimation { duration: 250 } }

                    Text
                    {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: Qt.formatDateTime(systemClock.date, "HH:mm")
                        color: "#ffffff"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 34
                        font.bold: true
                    }

                    Text
                    {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: Qt.formatDateTime(systemClock.date, "dddd d MMMM yyyy")
                        color: "#E5D3B3"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 12
                    }
                }

                // Section: Music, collapsed
                Row
                {
                    id: musicRow

                    anchors.centerIn: parent
                    spacing: 10

                    opacity: islandWindow.currentSection === "music" && !islandWindow.expanded && !islandWindow.popupActive ? 1 : 0
                    visible: opacity > 0
                    Behavior on opacity { NumberAnimation { duration: 200 } }

                    // Album art; clicking it plays or pauses
                    ClippingRectangle
                    {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 18
                        height: 18
                        radius: 4
                        color: "#86979A"

                        Image
                        {
                            anchors.fill: parent
                            source: islandWindow.activePlayer ? islandWindow.activePlayer.trackArtUrl : ""
                            fillMode: Image.PreserveAspectCrop
                            sourceSize.width: 36
                            sourceSize.height: 36
                        }

                        // Dim the art and show a play sign while paused
                        Rectangle
                        {
                            anchors.fill: parent
                            color: "#99000000"
                            visible: !islandWindow.musicPlaying

                            Text
                            {
                                anchors.centerIn: parent
                                text: "▶"
                                color: "#ffffff"
                                font.pixelSize: 9
                            }
                        }

                        MouseArea
                        {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: islandWindow.togglePlayback()
                        }
                    }

                    // Track title, cut off with "…" if it's too long
                    Text
                    {
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.min(implicitWidth, 200)
                        elide: Text.ElideRight
                        text: islandWindow.activePlayer ? islandWindow.activePlayer.trackTitle : ""
                        color: "#ffffff"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 13
                    }

                    // Small visualiser, growing up from the bottom
                    Row
                    {
                        anchors.verticalCenter: parent.verticalCenter
                        height: 14
                        spacing: 1.5

                        Repeater
                        {
                            model: 12

                            Rectangle
                            {
                                required property int index

                                anchors.bottom: parent.bottom
                                width: 2
                                radius: 1
                                height: Math.max(2, (cavaProcess.levels[index] ?? 0) * 14)
                                color: "#CB3F27"
                            }
                        }
                    }
                }

                // Section: Music, expanded
                Column
                {
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 10

                    opacity: islandWindow.currentSection === "music" && islandWindow.expanded && !islandWindow.popupActive ? 1 : 0
                    visible: opacity > 0
                    Behavior on opacity { NumberAnimation { duration: 250 } }

                    // Art, title and artist
                    Row
                    {
                        width: parent.width
                        spacing: 12

                        ClippingRectangle
                        {
                            width: 56
                            height: 56
                            radius: 8
                            color: "#86979A"

                            Image
                            {
                                anchors.fill: parent
                                source: islandWindow.activePlayer ? islandWindow.activePlayer.trackArtUrl : ""
                                fillMode: Image.PreserveAspectCrop
                                sourceSize.width: 112
                                sourceSize.height: 112
                            }
                        }

                        Column
                        {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - 68 - 70
                            spacing: 2

                            Text
                            {
                                width: parent.width
                                elide: Text.ElideRight
                                text: islandWindow.activePlayer ? islandWindow.activePlayer.trackTitle : ""
                                color: "#ffffff"
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 14
                                font.bold: true
                            }

                            Text
                            {
                                width: parent.width
                                elide: Text.ElideRight
                                text: islandWindow.activePlayer ? islandWindow.activePlayer.trackArtist : ""
                                color: "#E5D3B3"
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 12
                            }
                        }

                        // Larger visualiser beside the title
                        Row
                        {
                            anchors.verticalCenter: parent.verticalCenter
                            height: 24
                            spacing: 2

                            Repeater
                            {
                                model: 12

                                Rectangle
                                {
                                    required property int index

                                    anchors.bottom: parent.bottom
                                    width: 3
                                    radius: 1.5
                                    height: Math.max(2, (cavaProcess.levels[index] ?? 0) * 24)
                                    color: "#CB3F27"
                                }
                            }
                        }
                    }

                    // Progress bar with times either side; click the bar to jump
                    Item
                    {
                        width: parent.width
                        height: 14

                        Text
                        {
                            id: positionLabel
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            text: islandWindow.activePlayer ? islandWindow.formatTime(islandWindow.activePlayer.position) : "0:00"
                            color: "#E5D3B3"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 11
                        }

                        Text
                        {
                            id: lengthLabel
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            text: islandWindow.activePlayer ? islandWindow.formatTime(islandWindow.activePlayer.length) : "0:00"
                            color: "#E5D3B3"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 11
                        }

                        Rectangle
                        {
                            id: progressTrack

                            anchors.left: positionLabel.right
                            anchors.right: lengthLabel.left
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            height: 4
                            radius: 2
                            color: "#4D86979A"

                            // Maple red fill to match your cava bars
                            Rectangle
                            {
                                height: parent.height
                                radius: 2
                                color: "#CB3F27"
                                width: islandWindow.activePlayer && islandWindow.activePlayer.length > 0
                                       ? parent.width * Math.min(1, islandWindow.activePlayer.position / islandWindow.activePlayer.length)
                                       : 0
                            }

                            MouseArea
                            {
                                anchors.fill: parent
                                anchors.topMargin: -6
                                anchors.bottomMargin: -6
                                cursorShape: Qt.PointingHandCursor
                                onClicked: (Mouse) =>
                                {
                                    const Player = islandWindow.activePlayer;

                                    if (Player && Player.canSeek && Player.length > 0)
                                    {
                                        Player.position = (Mouse.x / progressTrack.width) * Player.length;
                                    }
                                }
                            }
                        }
                    }

                    // Previous, play/pause, next
                    Row
                    {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 34

                        Text
                        {
                            text: "\uf048"
                            color: "#ffffff"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 16

                            MouseArea
                            {
                                anchors.fill: parent
                                anchors.margins: -6
                                cursorShape: Qt.PointingHandCursor
                                onClicked: islandWindow.activePlayer.previous()
                            }
                        }

                        Text
                        {
                            text: islandWindow.musicPlaying ? "\uf04c" : "\uf04b"
                            color: "#ffffff"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 16

                            MouseArea
                            {
                                anchors.fill: parent
                                anchors.margins: -6
                                cursorShape: Qt.PointingHandCursor
                                onClicked: islandWindow.togglePlayback()
                            }
                        }

                        Text
                        {
                            text: "\uf051"
                            color: "#ffffff"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 16

                            MouseArea
                            {
                                anchors.fill: parent
                                anchors.margins: -6
                                cursorShape: Qt.PointingHandCursor
                                onClicked: islandWindow.activePlayer.next()
                            }
                        }
                    }
                }

                // Section: Volume, collapsed
                Row
                {
                    id: volumeRow

                    anchors.centerIn: parent
                    spacing: 8

                    opacity: islandWindow.currentSection === "vol" && !islandWindow.expanded && !islandWindow.popupActive ? 1 : 0
                    visible: opacity > 0
                    Behavior on opacity { NumberAnimation { duration: 200 } }

                    Text
                    {
                        anchors.verticalCenter: parent.verticalCenter
                        text: islandWindow.volumeIcon()
                        color: islandWindow.sinkMuted ? "#86979A" : "#ffffff"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 13
                    }

                    // Thin level bar, the same maple red as the visualiser
                    Rectangle
                    {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 46
                        height: 4
                        radius: 2
                        color: "#4D86979A"

                        Rectangle
                        {
                            height: parent.height
                            radius: 2
                            width: parent.width * islandWindow.sinkVolume
                            color: islandWindow.sinkMuted ? "#86979A" : "#CB3F27"
                        }
                    }

                    Text
                    {
                        anchors.verticalCenter: parent.verticalCenter
                        text: islandWindow.sinkMuted ? "Muted" : Math.round(islandWindow.sinkVolume * 100) + "%"
                        color: "#ffffff"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 13
                        font.bold: true
                    }
                }

                // Section: Volume, expanded
                Column
                {
                    id: volumeCard

                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.margins: 14
                    spacing: 12

                    opacity: islandWindow.currentSection === "vol" && islandWindow.expanded && !islandWindow.popupActive ? 1 : 0
                    visible: opacity > 0
                    Behavior on opacity { NumberAnimation { duration: 250 } }

                    // Mute button, slider, percentage
                    Item
                    {
                        width: parent.width
                        height: 20

                        // Click the speaker to mute or unmute
                        Text
                        {
                            id: muteButton

                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            width: 18
                            text: islandWindow.volumeIcon()
                            color: islandWindow.sinkMuted ? "#86979A" : "#ffffff"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 15

                            MouseArea
                            {
                                anchors.fill: parent
                                anchors.margins: -6
                                cursorShape: Qt.PointingHandCursor
                                onClicked:
                                {
                                    if (islandWindow.audioSink && islandWindow.audioSink.audio)
                                    {
                                        islandWindow.audioSink.audio.muted = !islandWindow.sinkMuted;
                                    }
                                }
                            }
                        }

                        Text
                        {
                            id: volumePercent

                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            width: 36
                            horizontalAlignment: Text.AlignRight
                            text: Math.round(islandWindow.sinkVolume * 100) + "%"
                            color: "#E5D3B3"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 12
                        }

                        // Click or drag anywhere on the track to set the level
                        Rectangle
                        {
                            id: volumeTrack

                            anchors.left: muteButton.right
                            anchors.right: volumePercent.left
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            height: 6
                            radius: 3
                            color: "#4D86979A"

                            Rectangle
                            {
                                height: parent.height
                                radius: 3
                                width: parent.width * islandWindow.sinkVolume
                                color: islandWindow.sinkMuted ? "#86979A" : "#CB3F27"
                            }

                            // Round handle at the end of the fill
                            Rectangle
                            {
                                anchors.verticalCenter: parent.verticalCenter
                                x: parent.width * islandWindow.sinkVolume - width / 2
                                width: 12
                                height: 12
                                radius: 6
                                color: "#ffffff"
                            }

                            MouseArea
                            {
                                anchors.fill: parent
                                anchors.topMargin: -8
                                anchors.bottomMargin: -8
                                cursorShape: Qt.PointingHandCursor

                                onPressed: (Mouse) => islandWindow.setVolume(Mouse.x / volumeTrack.width)
                                onPositionChanged: (Mouse) => islandWindow.setVolume(Mouse.x / volumeTrack.width)
                            }
                        }
                    }

                    // One chip per output device; the active one is filled in
                    Flow
                    {
                        width: parent.width
                        spacing: 6

                        Repeater
                        {
                            model: islandWindow.outputDevices

                            Rectangle
                            {
                                required property var modelData

                                property bool isActive: modelData === islandWindow.audioSink

                                width: Math.min(chipLabel.implicitWidth + 20, 260)
                                height: 24
                                radius: 12
                                color: isActive ? "#E5D3B3" : "#4D86979A"
                                border.width: 1
                                border.color: isActive ? "#E5D3B3" : "#86979A"

                                Text
                                {
                                    id: chipLabel

                                    anchors.centerIn: parent
                                    width: Math.min(implicitWidth, 240)
                                    elide: Text.ElideRight
                                    text: islandWindow.deviceName(modelData)
                                    color: isActive ? "#2A1D11" : "#ffffff"
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 11
                                }

                                MouseArea
                                {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: Pipewire.preferredDefaultAudioSink = modelData
                                }
                            }
                        }
                    }
                }

                // Section: Stats, collapsed
                Row
                {
                    id: statsRow

                    anchors.centerIn: parent
                    spacing: 12

                    opacity: islandWindow.currentSection === "stats" && !islandWindow.expanded && !islandWindow.popupActive ? 1 : 0
                    visible: opacity > 0
                    Behavior on opacity { NumberAnimation { duration: 200 } }

                    // CPU usage
                    Text
                    {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "\uf2db " + statsProcess.cpuUsage + "%"
                        color: "#ffffff"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 13
                    }

                    // CPU temperature
                    Text
                    {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: statsProcess.cpuTemp >= 0
                        text: "\uf2c9 " + statsProcess.cpuTemp + "°"
                        color: islandWindow.tempColour(statsProcess.cpuTemp)
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 13
                    }

                    // GPU temperature, hidden if there's no GPU sensor
                    Text
                    {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: statsProcess.gpuTemp >= 0
                        text: "GPU " + statsProcess.gpuTemp + "°"
                        color: statsProcess.gpuTemp >= 80 ? "#CB3F27" : "#E5D3B3"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 12
                    }
                }

                // Section: Stats, expanded
                Column
                {
                    id: statsCard

                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.margins: 14
                    spacing: 10

                    opacity: islandWindow.currentSection === "stats" && islandWindow.expanded && !islandWindow.popupActive ? 1 : 0
                    visible: opacity > 0
                    Behavior on opacity { NumberAnimation { duration: 250 } }

                    // One row per component: label, bar, reading
                    Repeater
                    {
                        model: 3

                        Item
                        {
                            required property int index

                            // Live values for this row, updated in place so the bars can slide
                            property var modelData: islandWindow.statRow(index)

                            width: statsCard.width
                            height: modelData.show ? 16 : 0
                            visible: modelData.show

                            Text
                            {
                                id: statLabel

                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                width: 36
                                text: modelData.label
                                color: "#E5D3B3"
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 12
                            }

                            Text
                            {
                                id: statReading

                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                width: 104
                                horizontalAlignment: Text.AlignRight
                                text: modelData.reading
                                color: "#ffffff"
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 12
                            }

                            Rectangle
                            {
                                anchors.left: statLabel.right
                                anchors.right: statReading.left
                                anchors.rightMargin: 10
                                anchors.verticalCenter: parent.verticalCenter
                                height: 5
                                radius: 2.5
                                color: "#4D86979A"

                                Rectangle
                                {
                                    height: parent.height
                                    radius: 2.5
                                    width: parent.width * Math.max(0, Math.min(1, modelData.fill))
                                    color: modelData.colour

                                    Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
                                }
                            }
                        }
                    }

                    // Opens KDE's System Monitor
                    Rectangle
                    {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: monitorLabel.implicitWidth + 28
                        height: 26
                        radius: 13
                        color: monitorButtonArea.containsMouse ? "#99931A13" : "#4D86979A"
                        border.width: 1
                        border.color: monitorButtonArea.containsMouse ? "#E18A42" : "#86979A"

                        Text
                        {
                            id: monitorLabel

                            anchors.centerIn: parent
                            text: "\uf080  Open System Monitor"
                            color: "#ffffff"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 12
                        }

                        MouseArea
                        {
                            id: monitorButtonArea

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: islandWindow.openSystemMonitor()
                        }
                    }
                }

                // Section: Downloads, collapsed
                Row
                {
                    id: downloadsRow

                    anchors.centerIn: parent
                    spacing: 8

                    opacity: islandWindow.currentSection === "dl" && !islandWindow.expanded && !islandWindow.popupActive ? 1 : 0
                    visible: opacity > 0
                    Behavior on opacity { NumberAnimation { duration: 200 } }

                    Text
                    {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "\uf019"
                        color: downloadsProcess.activeDownloads.length > 0 ? "#CB3F27" : "#ffffff"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 13
                    }

                    Text
                    {
                        anchors.verticalCenter: parent.verticalCenter
                        text: islandWindow.formatBytes(downloadsProcess.speed) + "/s"
                        color: "#ffffff"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 13
                    }

                    // Only shows while something is downloading
                    Text
                    {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: downloadsProcess.activeDownloads.length > 0
                        text: "· " + downloadsProcess.activeDownloads.length + " active"
                        color: "#E5D3B3"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 12
                    }
                }

                // Section: Downloads, expanded
                Column
                {
                    id: downloadsCard

                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.margins: 14
                    spacing: 8

                    opacity: islandWindow.currentSection === "dl" && islandWindow.expanded && !islandWindow.popupActive ? 1 : 0
                    visible: opacity > 0
                    Behavior on opacity { NumberAnimation { duration: 250 } }

                    // Title and live speed
                    Item
                    {
                        width: parent.width
                        height: 18

                        Text
                        {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Downloads"
                            color: "#ffffff"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 13
                            font.bold: true
                        }

                        Text
                        {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            text: "\uf019 " + islandWindow.formatBytes(downloadsProcess.speed) + "/s"
                            color: "#E5D3B3"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 12
                        }
                    }

                    // In progress: name and size so far (browsers don't share the total)
                    Repeater
                    {
                        model: downloadsProcess.activeDownloads

                        Item
                        {
                            required property var modelData

                            width: downloadsCard.width
                            height: 20

                            Text
                            {
                                id: activeIcon

                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                width: 22
                                text: "\uf110"
                                color: "#CB3F27"
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 13

                                RotationAnimation on rotation
                                {
                                    from: 0
                                    to: 360
                                    duration: 1200
                                    loops: Animation.Infinite
                                    running: activeIcon.visible
                                }
                            }

                            Text
                            {
                                id: activeSize

                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                text: islandWindow.formatBytes(modelData.size) + " so far"
                                color: "#E5D3B3"
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 11
                            }

                            Text
                            {
                                anchors.left: activeIcon.right
                                anchors.right: activeSize.left
                                anchors.rightMargin: 10
                                anchors.verticalCenter: parent.verticalCenter
                                elide: Text.ElideMiddle
                                text: modelData.name
                                color: "#ffffff"
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 12
                            }
                        }
                    }

                    // Recent files: click to open, right-click to show in Dolphin
                    Repeater
                    {
                        model: downloadsProcess.recentFiles

                        Rectangle
                        {
                            required property var modelData

                            width: downloadsCard.width
                            height: 26
                            radius: 6
                            color: recentArea.containsMouse ? "#4D86979A" : "transparent"

                            // Thumbnail for images, file icon for everything else
                            ClippingRectangle
                            {
                                id: recentThumb

                                anchors.left: parent.left
                                anchors.leftMargin: 2
                                anchors.verticalCenter: parent.verticalCenter
                                width: 20
                                height: 20
                                radius: 4
                                color: "#4D86979A"

                                Image
                                {
                                    anchors.fill: parent
                                    visible: modelData.image
                                    source: modelData.image ? "file://" + modelData.path : ""
                                    fillMode: Image.PreserveAspectCrop
                                    sourceSize.width: 40
                                    sourceSize.height: 40
                                    asynchronous: true
                                }

                                Text
                                {
                                    anchors.centerIn: parent
                                    visible: !modelData.image
                                    text: "\uf15b"
                                    color: "#E5D3B3"
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 11
                                }
                            }

                            Text
                            {
                                id: recentSize

                                anchors.right: parent.right
                                anchors.rightMargin: 4
                                anchors.verticalCenter: parent.verticalCenter
                                text: islandWindow.formatBytes(modelData.size)
                                color: "#E5D3B3"
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 11
                            }

                            Text
                            {
                                anchors.left: recentThumb.right
                                anchors.right: recentSize.left
                                anchors.leftMargin: 10
                                anchors.rightMargin: 10
                                anchors.verticalCenter: parent.verticalCenter
                                elide: Text.ElideMiddle
                                text: modelData.name
                                color: "#ffffff"
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 12
                            }

                            MouseArea
                            {
                                id: recentArea

                                anchors.fill: parent
                                hoverEnabled: true
                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                cursorShape: Qt.PointingHandCursor
                                onClicked: (Mouse) =>
                                {
                                    if (Mouse.button === Qt.RightButton)
                                    {
                                        islandWindow.showInDolphin(modelData.path);
                                    }
                                    else
                                    {
                                        islandWindow.openFile(modelData.path);
                                    }

                                    islandWindow.expanded = false;
                                }
                            }
                        }
                    }

                    // Opens the Downloads folder in Dolphin
                    Rectangle
                    {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: dolphinLabel.implicitWidth + 28
                        height: 26
                        radius: 13
                        color: dolphinButtonArea.containsMouse ? "#99931A13" : "#4D86979A"
                        border.width: 1
                        border.color: dolphinButtonArea.containsMouse ? "#E18A42" : "#86979A"

                        Text
                        {
                            id: dolphinLabel

                            anchors.centerIn: parent
                            text: "\uf07c  Open in Dolphin"
                            color: "#ffffff"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 12
                        }

                        MouseArea
                        {
                            id: dolphinButtonArea

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked:
                            {
                                Quickshell.execDetached(["sh", "-c", "exec bash \"$HOME/.config/shrine-waybar/run.sh\" downloads-folder"]);
                                islandWindow.expanded = false;
                            }
                        }
                    }
                }

                // Section: File pop-up
                Row
                {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: 10
                    anchors.rightMargin: 16
                    spacing: 12

                    opacity: islandWindow.popupFile !== null ? 1 : 0
                    visible: opacity > 0
                    Behavior on opacity { NumberAnimation { duration: 250 } }

                    // Thumbnail for images, a big file icon otherwise
                    ClippingRectangle
                    {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 52
                        height: 38
                        radius: 6
                        color: "#4D86979A"

                        Image
                        {
                            anchors.fill: parent
                            visible: islandWindow.popupFile !== null && islandWindow.popupFile.image
                            source: islandWindow.popupFile && islandWindow.popupFile.image ? "file://" + islandWindow.popupFile.path : ""
                            fillMode: Image.PreserveAspectCrop
                            sourceSize.width: 104
                            sourceSize.height: 76
                            asynchronous: true
                        }

                        Text
                        {
                            anchors.centerIn: parent
                            visible: islandWindow.popupFile !== null && !islandWindow.popupFile.image
                            text: "\uf15b"
                            color: "#E5D3B3"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 18
                        }
                    }

                    Column
                    {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 64
                        spacing: 2

                        Text
                        {
                            text:
                            {
                                if (!islandWindow.popupFile)
                                {
                                    return "";
                                }

                                if (islandWindow.popupFile.copied)
                                {
                                    return "Image copied";
                                }

                                return islandWindow.popupFile.screenshot ? "Screenshot saved" : "Download complete";
                            }
                            color: "#ffffff"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 13
                            font.bold: true
                        }

                        Text
                        {
                            width: parent.width
                            elide: Text.ElideMiddle
                            text: islandWindow.popupFile
                                  ? (islandWindow.popupFile.copied ? "Click to save · right-click to open" : islandWindow.popupFile.name)
                                  : ""
                            color: "#E5D3B3"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 11
                        }
                    }
                }

                // Section: Message pop-up
                Row
                {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: 18
                    anchors.rightMargin: 16
                    spacing: 14

                    opacity: islandWindow.popupMessage !== null ? 1 : 0
                    visible: opacity > 0
                    Behavior on opacity { NumberAnimation { duration: 250 } }

                    Text
                    {
                        anchors.verticalCenter: parent.verticalCenter
                        text: islandWindow.popupMessage ? islandWindow.popupMessage.icon : ""
                        color: islandWindow.popupMessage ? islandWindow.popupMessage.colour : "#ffffff"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 20
                    }

                    Column
                    {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 40
                        spacing: 2

                        Text
                        {
                            width: parent.width
                            elide: Text.ElideRight
                            text: islandWindow.popupMessage ? islandWindow.popupMessage.title : ""
                            color: "#ffffff"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 13
                            font.bold: true
                        }

                        Text
                        {
                            width: parent.width
                            elide: Text.ElideRight
                            text: islandWindow.popupMessage ? islandWindow.popupMessage.subtitle : ""
                            color: "#E5D3B3"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 11
                        }
                    }
                }

                // Section: Sync, collapsed
                Row
                {
                    id: syncRow

                    anchors.centerIn: parent
                    spacing: 8

                    opacity: islandWindow.currentSection === "sync" && !islandWindow.expanded && !islandWindow.popupActive ? 1 : 0
                    visible: opacity > 0
                    Behavior on opacity { NumberAnimation { duration: 200 } }

                    Text
                    {
                        id: syncSpinner

                        anchors.verticalCenter: parent.verticalCenter
                        text: islandWindow.syncIcon()
                        color: islandWindow.syncColour()
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 13

                        // Spins while files are moving, then snaps back upright
                        RotationAnimation on rotation
                        {
                            from: 0
                            to: 360
                            duration: 1400
                            loops: Animation.Infinite
                            running: islandWindow.syncState === "syncing" && syncSpinner.visible
                            onRunningChanged:
                            {
                                if (!running)
                                {
                                    syncSpinner.rotation = 0;
                                }
                            }
                        }
                    }

                    Text
                    {
                        anchors.verticalCenter: parent.verticalCenter
                        text: islandWindow.syncLabel()
                        color: "#ffffff"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 13
                    }
                }

                // Section: Sync, expanded
                Column
                {
                    id: syncCard

                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.margins: 14
                    spacing: 12

                    opacity: islandWindow.currentSection === "sync" && islandWindow.expanded && !islandWindow.popupActive ? 1 : 0
                    visible: opacity > 0
                    Behavior on opacity { NumberAnimation { duration: 250 } }

                    // Big icon with the state and Nextcloud's own status text
                    Row
                    {
                        width: parent.width
                        spacing: 14

                        Text
                        {
                            anchors.verticalCenter: parent.verticalCenter
                            text: islandWindow.syncIcon()
                            color: islandWindow.syncColour()
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 28
                        }

                        Column
                        {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - 48
                            spacing: 2

                            Text
                            {
                                text: islandWindow.syncLabel()
                                color: "#ffffff"
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 14
                                font.bold: true
                            }

                            Text
                            {
                                width: parent.width
                                wrapMode: Text.Wrap
                                maximumLineCount: 2
                                elide: Text.ElideRight
                                text: islandWindow.syncText !== "" ? islandWindow.syncText : "Nextcloud"
                                color: "#E5D3B3"
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 11
                            }
                        }
                    }

                    // Open the client, or the synced folder
                    Row
                    {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 8

                        Repeater
                        {
                            model:
                            [
                                { "label": "\uf0c2  Open Nextcloud", "action": "client" },
                                { "label": "\uf07c  Open folder", "action": "folder" }
                            ]

                            Rectangle
                            {
                                required property var modelData

                                width: syncButtonLabel.implicitWidth + 24
                                height: 26
                                radius: 13
                                color: syncButtonArea.containsMouse ? "#99931A13" : "#4D86979A"
                                border.width: 1
                                border.color: syncButtonArea.containsMouse ? "#E18A42" : "#86979A"

                                Text
                                {
                                    id: syncButtonLabel

                                    anchors.centerIn: parent
                                    text: modelData.label
                                    color: "#ffffff"
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 12
                                }

                                MouseArea
                                {
                                    id: syncButtonArea

                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked:
                                    {
                                        if (modelData.action === "client")
                                        {
                                            islandWindow.openNextcloud();
                                        }
                                        else
                                        {
                                            // The folder set as SHRINE_NEXTCLOUD_DIR in shrine.conf
                                            Quickshell.execDetached(["sh", "-c", "exec bash \"$HOME/.config/shrine-waybar/run.sh\" nextcloud-folder"]);
                                            islandWindow.expanded = false;
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // Section: Updates, collapsed
                Row
                {
                    id: updatesRow

                    anchors.centerIn: parent
                    spacing: 8

                    opacity: islandWindow.currentSection === "updates" && !islandWindow.expanded && !islandWindow.popupActive ? 1 : 0
                    visible: opacity > 0
                    Behavior on opacity { NumberAnimation { duration: 200 } }

                    Text
                    {
                        anchors.verticalCenter: parent.verticalCenter
                        text: islandWindow.countsLabel() === "" ? "\uf01e" : "\uf0ed"
                        color: "#E5D3B3"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 13
                    }

                    Text
                    {
                        anchors.verticalCenter: parent.verticalCenter
                        text: islandWindow.updatesSummary()
                        color: "#ffffff"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 13
                    }
                }

                // Section: Updates, expanded
                Column
                {
                    id: updatesCard

                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.margins: 14
                    spacing: 10

                    opacity: islandWindow.currentSection === "updates" && islandWindow.expanded && !islandWindow.popupActive ? 1 : 0
                    visible: opacity > 0
                    Behavior on opacity { NumberAnimation { duration: 250 } }

                    // One row each for the system and Flatpak apps
                    Repeater
                    {
                        model: 2

                        Item
                        {
                            required property int index

                            // The apps row is left out where Flatpak isn't installed
                            property bool shown: index === 0 || updatesProcess.flatpakCount >= 0

                            width: updatesCard.width
                            height: shown ? 18 : 0
                            visible: shown

                            Text
                            {
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                text: index === 0 ? "System" : "Apps"
                                color: "#E5D3B3"
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 12
                            }

                            Text
                            {
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                text: islandWindow.updateRowText(index)
                                color: (index === 0 ? (updatesProcess.restartNeeded || updatesProcess.systemCount > 0) : updatesProcess.flatpakCount > 0) ? "#ffffff" : "#86979A"
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 12
                            }
                        }
                    }

                    // Update now, plus Restart when a restart is needed
                    Row
                    {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 8

                        Repeater
                        {
                            model: updatesProcess.restartNeeded
                                   ? [{ "label": "\uf0ed  Update now", "action": "update" }, { "label": "\uf01e  Restart", "action": "restart" }]
                                   : [{ "label": "\uf0ed  Update now", "action": "update" }]

                            Rectangle
                            {
                                required property var modelData

                                width: updatesButtonLabel.implicitWidth + 24
                                height: 26
                                radius: 13
                                color: updatesButtonArea.containsMouse ? "#99931A13" : "#4D86979A"
                                border.width: 1
                                border.color: updatesButtonArea.containsMouse ? "#E18A42" : "#86979A"

                                Text
                                {
                                    id: updatesButtonLabel

                                    anchors.centerIn: parent
                                    text: modelData.label
                                    color: "#ffffff"
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 12
                                }

                                MouseArea
                                {
                                    id: updatesButtonArea

                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked:
                                    {
                                        if (modelData.action === "restart")
                                        {
                                            islandWindow.promptRestart();
                                        }
                                        else
                                        {
                                            islandWindow.runUpdate();
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
