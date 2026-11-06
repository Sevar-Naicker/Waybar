// This file contains the app launcher that drops down from the launcher pill
// Type to search your apps, use the arrow keys and Enter, or type a sum like 24*7 to get the answer

import Quickshell
import Quickshell.Io
import QtQuick
import "Calculator.js" as Calculator

// Section: Launcher
MenuWindow
{
    id: launcher

    panelWidth: 470
    side: "left"

    // Section: State
    // What's typed in the search box
    property string query: ""

    // How many times each app has been opened, so favourites come first
    property var usage: ({})

    // The answer when the search is a sum, otherwise null
    property var calcResult: Calculator.calculate(query)

    // Every app that should show in a launcher
    property var allApps: DesktopEntries.applications.values.filter(App => !App.noDisplay)

    // The apps matching the search, best match first
    property var results:
    {
        const Text_ = query.trim().toLowerCase();

        if (Text_ === "")
        {
            return allApps.slice().sort((A, B) => launcher.usageOf(B) - launcher.usageOf(A) || A.name.localeCompare(B.name));
        }

        const Scored = [];

        for (const App of allApps)
        {
            const Score = launcher.matchScore(App, Text_);

            if (Score > 0)
            {
                Scored.push({ "app": App, "score": Score });
            }
        }

        Scored.sort((A, B) => B.score - A.score || launcher.usageOf(B.app) - launcher.usageOf(A.app) || A.app.name.localeCompare(B.app.name));
        return Scored.map(Item_ => Item_.app);
    }

    onResultsChanged: appGrid.currentIndex = 0

    // Fresh search box every time it opens
    onShownChanged:
    {
        if (shown)
        {
            searchInput.text = "";
            appGrid.currentIndex = 0;
            searchInput.forceActiveFocus();
        }
    }

    // Section: Functions

    // The usageOf function says how often an app has been opened
    function usageOf(App)
    {
        return usage[App.id] || 0;
    }

    // The matchScore function rates how well an app matches the search (0 means no match)
    function matchScore(App, Text_)
    {
        const Name = (App.name || "").toLowerCase();
        const Extra = [App.genericName || "", App.comment || ""].concat(App.keywords || []).join(" ").toLowerCase();

        if (Name.startsWith(Text_))
        {
            return 4;
        }

        if (Name.split(/[\s\-_.]+/).some(Word => Word.startsWith(Text_)))
        {
            return 3;
        }

        if (Name.includes(Text_))
        {
            return 2;
        }

        if (Extra.includes(Text_))
        {
            return 1;
        }

        return 0;
    }

    // The launch function opens an app, remembers it was used, and closes the launcher
    function launch(App)
    {
        // Terminal apps (like btop) need a terminal around them; execute() alone doesn't open one
        if (App.runInTerminal)
        {
            Quickshell.execDetached({
                "command": ["bash", Quickshell.env("HOME") + "/.config/shrine-waybar/run.sh", "in-terminal"].concat(App.command),
                "workingDirectory": App.workingDirectory || Quickshell.env("HOME")
            });
        }
        else
        {
            App.execute();
        }

        const Updated = Object.assign({}, usage);
        Updated[App.id] = (Updated[App.id] || 0) + 1;
        usage = Updated;

        Quickshell.execDetached(["sh", "-c",
            "mkdir -p \"$HOME/.local/state/shrine-waybar\" && printf '%s' \"$1\" > \"$HOME/.local/state/shrine-waybar/launcher.json\"",
            "sh", JSON.stringify(Updated)]);

        closeMenu();
    }

    // The submit function is what Enter does: copy a sum's answer, open the chosen app, or search the web
    function submit()
    {
        if (calcResult !== null)
        {
            Quickshell.execDetached(["wl-copy", String(calcResult)]);
            closeMenu();
            return;
        }

        if (results.length > 0)
        {
            launch(results[Math.max(0, appGrid.currentIndex)]);
            return;
        }

        if (query.trim() !== "")
        {
            Quickshell.execDetached(["xdg-open", "https://duckduckgo.com/?q=" + encodeURIComponent(query.trim())]);
            closeMenu();
        }
    }

    // Section: Saved usage
    // Reads how often each app has been opened (one line of JSON)
    Process
    {
        command: ["sh", "-c", "cat \"$HOME/.local/state/shrine-waybar/launcher.json\" 2>/dev/null"]
        running: true

        stdout: SplitParser
        {
            onRead: (Line) =>
            {
                try
                {
                    launcher.usage = JSON.parse(Line);
                }
                catch (Problem)
                {
                    launcher.usage = {};
                }
            }
        }
    }

    // Section: Layout
    Column
    {
        width: parent.width
        spacing: 10

        // Section: Search box
        Rectangle
        {
            width: parent.width
            height: 38
            radius: 12
            color: Theme.soft

            Text
            {
                id: searchIcon

                anchors.left: parent.left
                anchors.leftMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                text: ""
                color: Theme.muted
                font.family: Theme.font
                font.pixelSize: 14
            }

            TextInput
            {
                id: searchInput

                anchors.left: searchIcon.right
                anchors.leftMargin: 10
                anchors.right: parent.right
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                color: Theme.text
                selectionColor: Theme.accent
                font.family: Theme.font
                font.pixelSize: 13
                clip: true

                onTextChanged: launcher.query = text

                // Arrows move through the apps, Enter opens, Escape closes
                Keys.onPressed: (Event) =>
                {
                    if (Event.key === Qt.Key_Down)
                    {
                        appGrid.moveCurrentIndexDown();
                        Event.accepted = true;
                    }
                    else if (Event.key === Qt.Key_Up)
                    {
                        appGrid.moveCurrentIndexUp();
                        Event.accepted = true;
                    }
                    else if (Event.key === Qt.Key_Right && searchInput.cursorPosition === searchInput.text.length)
                    {
                        appGrid.moveCurrentIndexRight();
                        Event.accepted = true;
                    }
                    else if (Event.key === Qt.Key_Left && searchInput.cursorPosition === searchInput.text.length)
                    {
                        appGrid.moveCurrentIndexLeft();
                        Event.accepted = true;
                    }
                    else if (Event.key === Qt.Key_Return || Event.key === Qt.Key_Enter)
                    {
                        launcher.submit();
                        Event.accepted = true;
                    }
                    else if (Event.key === Qt.Key_Escape)
                    {
                        launcher.closeMenu();
                        Event.accepted = true;
                    }
                }

                // Hint shown while the box is empty
                Text
                {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: searchInput.text === ""
                    text: "Search apps, or try 24*7"
                    color: Theme.muted
                    opacity: 0.7
                    font.family: Theme.font
                    font.pixelSize: 13
                }
            }
        }

        // Section: Calculator answer
        Rectangle
        {
            width: parent.width
            height: launcher.calcResult !== null ? 34 : 0
            visible: launcher.calcResult !== null
            radius: 12
            color: Theme.accent

            Text
            {
                anchors.left: parent.left
                anchors.leftMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                text: "= " + launcher.calcResult
                color: Theme.accentText
                font.family: Theme.font
                font.pixelSize: 14
                font.bold: true
            }

            Text
            {
                anchors.right: parent.right
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                text: "Enter to copy"
                color: Theme.accentText
                font.family: Theme.font
                font.pixelSize: 11
            }
        }

        // Section: Apps
        GridView
        {
            id: appGrid

            width: parent.width
            height: launcher.results.length > 0 ? 3 * cellHeight : 0
            visible: launcher.results.length > 0
            cellWidth: width / 5
            cellHeight: 90
            clip: true
            model: launcher.results
            boundsBehavior: Flickable.StopAtBounds
            highlightFollowsCurrentItem: false

            delegate: Rectangle
            {
                id: appTile

                required property var modelData
                required property int index

                property bool isCurrent: GridView.isCurrentItem

                width: appGrid.cellWidth - 6
                height: appGrid.cellHeight - 6
                radius: 12
                color: isCurrent ? Theme.accent : (tileHover.containsMouse ? Theme.softHover : "transparent")

                Behavior on color
                {
                    ColorAnimation { duration: 120 }
                }

                Image
                {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 12
                    width: 36
                    height: 36
                    sourceSize.width: 72
                    sourceSize.height: 72
                    source: Quickshell.iconPath(appTile.modelData.icon, "application-x-executable")

                    // Icon-theme images must load on the main thread; loading them in the background makes Qt warn
                }

                Text
                {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 54
                    width: parent.width - 8
                    horizontalAlignment: Text.AlignHCenter
                    text: appTile.modelData.name
                    wrapMode: Text.Wrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                    color: appTile.isCurrent ? Theme.accentText : Theme.text
                    font.family: Theme.font
                    font.pixelSize: 11
                }

                MouseArea
                {
                    id: tileHover

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: appGrid.currentIndex = appTile.index
                    onClicked: launcher.launch(appTile.modelData)
                }
            }
        }

        // Section: Nothing found
        Text
        {
            width: parent.width
            visible: launcher.results.length === 0 && launcher.calcResult === null
            text: "No apps match. Press Enter to search the web."
            color: Theme.muted
            font.family: Theme.font
            font.pixelSize: 12
            topPadding: 6
            bottomPadding: 6
        }
    }
}
