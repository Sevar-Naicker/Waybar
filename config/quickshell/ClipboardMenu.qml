// This file contains the clipboard menu: everything you've copied (text and images), newest first, with search and pins
// The island's clipboard watcher keeps the history (clipboard-history.py); history and pins live in ~/.local/state/shrine-waybar

import Quickshell
import Quickshell.Io
import QtQuick

// Section: Clipboard menu
MenuWindow
{
    id: clipboard

    side: "centre"
    panelWidth: 560

    // Section: State
    // The history (newest first, each { "text": … } or { "image": path }), your pinned texts, and what's typed in the search box
    property var history: []
    property var pins: []
    property string query: ""

    // A Clear history click waits for a second click for a few seconds
    property bool clearArmed: false

    // Pinned entries first, then the rest of the history, both narrowed by the search
    property var entries:
    {
        const Search = query.trim().toLowerCase();
        const Matches = Text => Search === "" || Text.toLowerCase().includes(Search);
        const List = [];

        for (const Text of pins)
        {
            if (Matches(Text))
            {
                List.push({ "text": Text, "image": "", "pinned": true });
            }
        }

        // Images only show when not searching
        for (const Item of history)
        {
            if (Item.image)
            {
                if (Search === "")
                {
                    List.push({ "text": "", "image": Item.image, "pinned": false });
                }
            }
            else if (typeof Item.text === "string" && !pins.includes(Item.text) && Matches(Item.text))
            {
                List.push({ "text": Item.text, "image": "", "pinned": false });
            }
        }

        return List;
    }

    readonly property string stateDir: Quickshell.env("HOME") + "/.local/state/shrine-waybar"

    readonly property string historyScript: Quickshell.env("HOME") + "/.config/quickshell/clipboard-history.py"

    // The preview function squashes an entry onto one or two short lines for the list
    function preview(Text)
    {
        return Text.replace(/\s+/g, " ").trim().slice(0, 240);
    }

    // The copy function puts an entry back on the clipboard (the watcher then moves it to the top) and closes the menu
    function copy(Entry)
    {
        if (!Entry)
        {
            return;
        }

        if (Entry.image)
        {
            const Extension = (Entry.image.split(".").pop() || "png").toLowerCase();
            const Type = "image/" + (Extension === "jpg" ? "jpeg" : Extension);
            Quickshell.execDetached(["sh", "-c", "wl-copy --type \"$2\" < \"$1\"", "sh", Entry.image, Type]);
        }
        else
        {
            Quickshell.execDetached(["wl-copy", "--", Entry.text]);
        }

        closeMenu();
    }

    // The togglePin function pins or unpins an entry and saves the pins
    function togglePin(Text)
    {
        const Pins = pins.slice();
        const Index = Pins.indexOf(Text);

        if (Index >= 0)
        {
            Pins.splice(Index, 1);
        }
        else
        {
            Pins.unshift(Text);
        }

        pins = Pins;
        Quickshell.execDetached(["sh", "-c", "mkdir -p \"$1\" && printf '%s' \"$2\" > \"$1/clipboard-pins.json\"", "sh", stateDir, JSON.stringify(Pins)]);
    }

    // The clearHistory function empties the history on the second click (pins are kept)
    function clearHistory()
    {
        if (!clearArmed)
        {
            clearArmed = true;
            disarmTimer.restart();
            return;
        }

        clearArmed = false;
        Quickshell.execDetached(["python3", historyScript, "clear"]);
        history = [];
    }

    onShownChanged:
    {
        if (shown)
        {
            searchInput.text = "";
            clearArmed = false;
            entryList.currentIndex = 0;
            searchInput.forceActiveFocus();
            historyProcess.running = true;
            pinsProcess.running = true;
        }
    }

    Timer
    {
        id: disarmTimer
        interval: 3000
        onTriggered: clipboard.clearArmed = false
    }

    // Section: Sources
    // The history file is one line of JSON
    Process
    {
        id: historyProcess

        command: ["cat", clipboard.stateDir + "/clipboard-history.json"]

        stdout: SplitParser
        {
            onRead: (Line) =>
            {
                try
                {
                    const History = JSON.parse(Line);
                    clipboard.history = Array.isArray(History) ? History : [];
                }
                catch (Problem)
                {
                }
            }
        }
    }

    // Your pins, saved as a JSON list of strings
    Process
    {
        id: pinsProcess

        command: ["cat", clipboard.stateDir + "/clipboard-pins.json"]

        stdout: SplitParser
        {
            onRead: (Line) =>
            {
                try
                {
                    clipboard.pins = JSON.parse(Line);
                }
                catch (Problem)
                {
                }
            }
        }
    }

    // Section: Layout
    Column
    {
        width: parent.width
        spacing: 12

        // Section: Search box
        Rectangle
        {
            width: parent.width
            height: 48
            radius: 14
            color: Theme.card
            border.width: 1
            border.color: searchInput.activeFocus ? Theme.pastel : Theme.cardBorder

            Rectangle
            {
                id: searchBadge

                anchors.left: parent.left
                anchors.leftMargin: 7
                anchors.verticalCenter: parent.verticalCenter
                width: 34
                height: 34
                radius: 10
                color: Theme.pastel

                Text
                {
                    anchors.centerIn: parent
                    text: ""
                    color: Theme.pastelText
                    font.family: Theme.font
                    font.pixelSize: 14
                }
            }

            TextInput
            {
                id: searchInput

                anchors.left: searchBadge.right
                anchors.leftMargin: 12
                anchors.right: parent.right
                anchors.rightMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                color: Theme.text
                selectionColor: Theme.accent
                font.family: Theme.font
                font.pixelSize: 14
                clip: true

                onTextChanged:
                {
                    clipboard.query = text;
                    entryList.currentIndex = 0;
                }

                // Arrows move through the list, Enter copies, Ctrl+P pins
                Keys.onPressed: (Event) =>
                {
                    if (Event.key === Qt.Key_Down)
                    {
                        entryList.incrementCurrentIndex();
                        Event.accepted = true;
                    }
                    else if (Event.key === Qt.Key_Up)
                    {
                        entryList.decrementCurrentIndex();
                        Event.accepted = true;
                    }
                    else if (Event.key === Qt.Key_Return || Event.key === Qt.Key_Enter)
                    {
                        clipboard.copy(clipboard.entries[entryList.currentIndex]);
                        Event.accepted = true;
                    }
                    else if (Event.key === Qt.Key_P && (Event.modifiers & Qt.ControlModifier))
                    {
                        const Entry = clipboard.entries[entryList.currentIndex];

                        if (Entry)
                        {
                            clipboard.togglePin(Entry.text);
                        }

                        Event.accepted = true;
                    }
                }

                Text
                {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: searchInput.text === ""
                    text: "Search what you've copied"
                    color: Theme.muted
                    opacity: 0.6
                    font: searchInput.font
                }
            }
        }

        // Section: Heading
        Item
        {
            width: parent.width
            height: 14

            Text
            {
                anchors.left: parent.left
                anchors.leftMargin: 4
                text: clipboard.query.trim() === "" ? "HISTORY · " + clipboard.entries.length : "RESULTS · " + clipboard.entries.length
                color: Theme.muted
                font.family: Theme.font
                font.pixelSize: 10
                font.bold: true
                font.letterSpacing: 1.5
            }

            Text
            {
                anchors.right: parent.right
                anchors.rightMargin: 4
                text: "ENTER COPIES · CTRL+P PINS"
                color: Theme.muted
                opacity: 0.6
                font.family: Theme.font
                font.pixelSize: 9
                font.bold: true
                font.letterSpacing: 1
            }
        }

        // Section: Entries
        ListView
        {
            id: entryList

            width: parent.width
            height: 6 * 58
            spacing: 6
            clip: true
            model: clipboard.entries
            visible: clipboard.entries.length > 0
            boundsBehavior: Flickable.StopAtBounds
            highlightMoveDuration: 120

            delegate: Rectangle
            {
                id: entryCard

                required property var modelData
                required property int index

                property bool isCurrent: ListView.isCurrentItem
                property bool image: modelData.image !== ""

                width: entryList.width
                height: image ? 84 : 52
                radius: 12
                color: isCurrent ? Theme.pastel : (entryHover.containsMouse ? Theme.cardHover : Theme.card)
                border.width: 1
                border.color: isCurrent ? "transparent" : Theme.cardBorder

                Behavior on color
                {
                    ColorAnimation { duration: 110 }
                }

                // Kind of entry: pinned, image, link or text
                Text
                {
                    id: kindIcon

                    anchors.left: parent.left
                    anchors.leftMargin: 14
                    anchors.verticalCenter: parent.verticalCenter
                    width: 16
                    horizontalAlignment: Text.AlignHCenter
                    text:
                    {
                        if (entryCard.modelData.pinned)
                        {
                            return "";
                        }

                        if (entryCard.image)
                        {
                            return "";
                        }

                        return /^https?:\/\//.test(entryCard.modelData.text.trim()) ? "" : "";
                    }
                    color: entryCard.isCurrent ? Theme.pastelText : (entryCard.modelData.pinned ? Theme.accentHover : Theme.muted)
                    font.family: Theme.font
                    font.pixelSize: 13
                }

                Text
                {
                    anchors.left: kindIcon.right
                    anchors.leftMargin: 12
                    anchors.right: pinButton.left
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    visible: !entryCard.image
                    text: clipboard.preview(entryCard.modelData.text)
                    color: entryCard.isCurrent ? Theme.pastelText : Theme.text
                    font.family: Theme.font
                    font.pixelSize: 12
                    wrapMode: Text.Wrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                }

                // A copied image: a small preview of it
                Rectangle
                {
                    anchors.left: kindIcon.right
                    anchors.leftMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    visible: entryCard.image
                    width: 120
                    height: 64
                    radius: 8
                    color: Theme.card
                    clip: true

                    Image
                    {
                        anchors.fill: parent
                        source: entryCard.image ? "file://" + entryCard.modelData.image : ""
                        fillMode: Image.PreserveAspectCrop
                        sourceSize.width: 240
                        sourceSize.height: 128
                        asynchronous: true
                    }
                }

                MouseArea
                {
                    id: entryHover

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: entryList.currentIndex = entryCard.index
                    onClicked: clipboard.copy(entryCard.modelData)
                }

                // Pin button, shown on the highlighted entry and on pinned ones
                Text
                {
                    id: pinButton

                    anchors.right: parent.right
                    anchors.rightMargin: 16
                    anchors.verticalCenter: parent.verticalCenter
                    visible: !entryCard.image && (entryCard.isCurrent || entryCard.modelData.pinned)
                    text: entryCard.modelData.pinned ? "" : ""
                    rotation: entryCard.modelData.pinned ? 0 : 45
                    color: entryCard.isCurrent ? Theme.pastelText : Theme.accentHover
                    opacity: entryCard.modelData.pinned ? 1 : 0.6
                    font.family: Theme.font
                    font.pixelSize: 13

                    MouseArea
                    {
                        anchors.fill: parent
                        anchors.margins: -8
                        cursorShape: Qt.PointingHandCursor
                        onClicked: clipboard.togglePin(entryCard.modelData.text)
                    }
                }
            }
        }

        // Section: Empty or missing
        Rectangle
        {
            visible: !entryList.visible
            width: parent.width
            height: 120
            radius: 14
            color: Theme.card
            border.width: 1
            border.color: Theme.cardBorder

            Text
            {
                anchors.centerIn: parent
                width: parent.width - 40
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                lineHeight: 1.4
                text: clipboard.query.trim() === ""
                      ? "\uf0ea\nNothing copied yet.\nAnything you copy from now on shows up here."
                      : "\uf002\nNothing matches \"" + clipboard.query.trim() + "\"."
                color: Theme.muted
                font.family: Theme.font
                font.pixelSize: 12
            }
        }

        // Section: Clear history
        // Needs a second click; pinned entries stay
        Rectangle
        {
            anchors.right: parent.right
            visible: clipboard.history.length > 0
            width: clearLabel.implicitWidth + 28
            height: 30
            radius: 15
            color: clipboard.clearArmed ? Theme.accent : (clearHover.containsMouse ? Theme.cardHover : Theme.card)
            border.width: 1
            border.color: clipboard.clearArmed ? "transparent" : Theme.cardBorder

            Text
            {
                id: clearLabel

                anchors.centerIn: parent
                text: clipboard.clearArmed ? "  CLICK AGAIN TO CLEAR" : "  CLEAR HISTORY"
                color: clipboard.clearArmed ? Theme.accentText : Theme.muted
                font.family: Theme.font
                font.pixelSize: 10
                font.bold: true
                font.letterSpacing: 1
            }

            MouseArea
            {
                id: clearHover

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: clipboard.clearHistory()
            }
        }
    }
}
