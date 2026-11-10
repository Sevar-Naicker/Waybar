// This file contains the wallpaper picker: a strip of slanted cards that slides along, with colour filters above it
// Picking a wallpaper puts it on every screen and recolours the menus, island and Waybar to match it

import Quickshell
import Quickshell.Io
import QtQuick
import "Palette.js" as Palette

// Section: Wallpaper picker
MenuWindow
{
    id: picker

    bare: true
    side: "centre"
    panelWidth: width

    // Section: Settings
    // Card sizes: the chosen card is wide, the rest are narrow; Slant is how far the top leans right, as a share of the height
    readonly property real stripHeight: 300
    readonly property real wideWidth: 540
    readonly property real narrowWidth: 150
    readonly property real slant: 0.3

    // Section: State
    // The folder, every image in it, and the colour filter in use ("all", or a family like "red")
    property string folder: ""
    property var wallpapers: []
    property string filter: "all"

    // What the colour reader found: each wallpaper's family and colour summary, by path
    property var families: ({})
    property var palettes: ({})

    // Whether the colour reader loaded
    property bool coloursWork: colourLoader.status === Loader.Ready

    // A wallpaper picked before its colours were read gets its colours as soon as they arrive
    property string waitingFor: ""

    // 0 to 1 as the cards rise in when the picker opens
    property real reveal: 0

    // True while a picked wallpaper grows to fill the screen
    property bool applying: false

    // 0 to 1 as the other cards fly out to the sides when a wallpaper is picked
    property real flyOut: 0

    // The wallpapers the filter lets through
    property var filtered: filter === "all" ? wallpapers : wallpapers.filter(Path => families[Path] === filter)

    property string currentPath: strip.currentIndex >= 0 && strip.currentIndex < filtered.length ? filtered[strip.currentIndex] : ""

    // The card whose right-click menu is open ("" when none is)
    property string menuPath: ""

    // The colour families, in rainbow order, with the colour of each dot
    readonly property var familyDots: [
        { "name": "red", "colour": "#E5484D" },
        { "name": "orange", "colour": "#F28C28" },
        { "name": "yellow", "colour": "#F2C94C" },
        { "name": "green", "colour": "#4CAF50" },
        { "name": "blue", "colour": "#3B82F6" },
        { "name": "purple", "colour": "#8B5CF6" },
        { "name": "pink", "colour": "#EC4899" },
        { "name": "grey", "colour": "#9CA3AF" }
    ]

    // The fileName function gives a wallpaper's name without its folder or extension
    function fileName(Path)
    {
        const Name = Path.split("/").pop();
        const Dot = Name.lastIndexOf(".");
        return Dot > 0 ? Name.slice(0, Dot) : Name;
    }

    // The pickFilter function switches the colour filter (picking the one already on goes back to all)
    function pickFilter(Name)
    {
        filter = filter === Name ? "all" : Name;
        strip.currentIndex = 0;
        centre(false);
    }

    // The centre function scrolls the strip so the chosen card sits in the middle of the screen
    // (every other card is narrow, so the chosen card's place is simple to work out, even while the widths are still changing)
    function centre(Animated)
    {
        stripSlide.enabled = Animated;
        strip.contentX = strip.currentIndex * (narrowWidth + strip.spacing) - strip.leftMargin;
        stripSlide.enabled = true;
    }

    // The useWallpaper function sweeps the chosen wallpaper in from the right, then sets it and recolours everything
    function useWallpaper(Path)
    {
        if (Path === "" || applying)
        {
            return;
        }

        wipe.path = Path;
        wipe.progress = 0;
        applying = true;

        // The full-size picture is normally loaded already (it loads while the card is chosen); if not, wait for it
        if (fullPicture.status === Image.Ready && fullPicture.source.toString() === "file://" + Path)
        {
            applyAnimation.start();
        }
        else
        {
            waitForPicture.restart();
        }
    }

    // The finishWallpaper function is the moment the picture fills the screen: set it, and switch the colours behind it
    function finishWallpaper(Path)
    {
        Quickshell.execDetached(["bash", Quickshell.env("HOME") + "/.config/shrine-waybar/run.sh", "set-wallpaper", Path]);

        if (palettes[Path])
        {
            Theme.save(Palette.fromSummary(palettes[Path]), Path);
            waitingFor = "";
        }
        else
        {
            waitingFor = coloursWork ? Path : "";
        }
    }

    // The useForLogin function closes the picker and puts the wallpaper on the login screen (a password box asks first)
    function useForLogin(Path)
    {
        menuPath = "";

        if (Path === "")
        {
            return;
        }

        closeMenu();
        Quickshell.execDetached(["bash", Quickshell.env("HOME") + "/.config/shrine-waybar/run.sh", "set-login-wallpaper", Path]);
    }

    // The jumpToCurrent function puts the wallpaper in use in the middle straight away
    function jumpToCurrent()
    {
        const Index = filtered.indexOf(Theme.wallpaper);
        strip.currentIndex = Math.max(0, Index);
        centre(false);
    }

    // Every time it opens: read the folder again, so new wallpapers show up
    Connections
    {
        target: picker

        function onShownChanged()
        {
            if (picker.shown)
            {
                picker.filter = "all";
                picker.menuPath = "";
                picker.applying = false;
                picker.flyOut = 0;
                wipe.opacity = 0;
                listProcess.found = [];
                listProcess.running = true;

                // The cards rise in
                revealAnimation.restart();
            }
        }
    }

    // Section: Sources
    // run.sh prints "DIR<tab>folder", then one image path per line
    Process
    {
        id: listProcess

        property var found: []

        command: ["bash", Quickshell.env("HOME") + "/.config/shrine-waybar/run.sh", "wallpaper-list"]

        stdout: SplitParser
        {
            onRead: (Line) =>
            {
                if (Line.startsWith("DIR\t"))
                {
                    picker.folder = Line.slice(4);
                }
                else if (Line !== "")
                {
                    listProcess.found.push(Line);
                }
            }
        }

        onExited:
        {
            picker.wallpapers = found;
            picker.jumpToCurrent();
        }
    }

    // Reads each wallpaper's colours (only loaded once the picker has been opened)
    Loader
    {
        id: colourLoader

        source: "WallpaperColours.qml"
        active: picker.wallpapers.length > 0

        onLoaded: item.paths = Qt.binding(() => picker.wallpapers)
    }

    Connections
    {
        target: colourLoader.item
        ignoreUnknownSignals: true

        function onMeasured(Path, Summary)
        {
            const Families = Object.assign({}, picker.families);
            const Palettes = Object.assign({}, picker.palettes);
            Families[Path] = Summary.family;
            Palettes[Path] = Summary;
            picker.families = Families;
            picker.palettes = Palettes;

            // Finish a wallpaper that was picked before its colours were ready
            if (picker.waitingFor === Path)
            {
                Theme.save(Palette.fromSummary(Summary), Path);
                picker.waitingFor = "";
            }
        }
    }

    NumberAnimation
    {
        id: revealAnimation

        target: picker
        property: "reveal"
        from: 0
        to: 1
        duration: 650
        easing.type: Easing.OutCubic
    }

    // Section: Applying
    // The full-size version of the chosen wallpaper, loaded in the background while you browse,
    // so the picture that grows to fill the screen is ready (and sharp) the moment you pick it
    Image
    {
        id: fullPicture

        visible: false
        source: picker.shown && picker.currentPath !== "" ? "file://" + picker.currentPath : ""
        asynchronous: true
        sourceSize.width: picker.width
        sourceSize.height: picker.height
    }

    // Waits for the full-size picture if it wasn't ready yet (at most a second, then goes anyway)
    Timer
    {
        id: waitForPicture

        property int tries: 0

        interval: 50
        repeat: true
        onRunningChanged: if (running) tries = 0
        onTriggered:
        {
            tries += 1;

            if (applyPicture.status === Image.Ready || tries > 20)
            {
                stop();
                applyAnimation.start();
            }
        }
    }

    // Picking a wallpaper:
    //   the cards slide off to the left while the new wallpaper sweeps in from the right behind a slanted, glowing edge,
    //   the wallpaper and colours change behind it once it covers the screen, then it fades away
    SequentialAnimation
    {
        id: applyAnimation

        PropertyAction { target: wipe; property: "opacity"; value: 1 }

        // The wallpaper and colours start changing with the wipe, so the bar and island recolour while it passes
        ScriptAction { script: picker.finishWallpaper(wipe.path) }

        ParallelAnimation
        {
            NumberAnimation { target: picker; property: "flyOut"; from: 0; to: 1; duration: 700; easing.type: Easing.InCubic }

            SequentialAnimation
            {
                PauseAnimation { duration: 120 }
                NumberAnimation { target: wipe; property: "progress"; from: 0; to: 1; duration: 1100; easing.type: Easing.InOutCubic }
            }
        }

        // A moment for Plasma to finish swapping the wallpaper underneath
        PauseAnimation { duration: 450 }

        NumberAnimation { target: wipe; property: "opacity"; to: 0; duration: 600; easing.type: Easing.InOutQuad }

        // Only close: the cards and toolbar stay hidden while the menu finishes closing (opening it again resets them)
        ScriptAction { script: picker.closeMenu() }
    }

    // The sweep, on the full-screen overlay layer
    // A slanted window moves from right to left across the screen; the wallpaper inside it stays put (drifting a little),
    // so it looks like the new wallpaper is being revealed. Only positions change while it moves, which keeps it smooth.
    // It stops short of the top, so Waybar and the island stay visible and recolour as it passes.
    Item
    {
        id: wipe

        property string path: ""

        // 0 waiting off the right edge, 1 covering the whole screen
        property real progress: 0

        // How far the slanted edge leans across the screen's height
        property real leanWidth: picker.slant * height

        // The bar's strip at the top of the screen (Waybar's pills end at about 44px), left uncovered
        readonly property real barSpace: 46

        parent: picker.overlayLayer
        anchors.fill: parent
        opacity: 0
        visible: opacity > 0

        Item
        {
            y: wipe.barSpace
            width: parent.width
            height: parent.height - wipe.barSpace
            clip: true

            Item
            {
                id: wipeWindow

                // Still lined up with the whole screen, so the wallpaper sits exactly where Plasma will draw it
                y: -wipe.barSpace

                // From fully off the right edge to fully covering the screen (the slant needs half its width either side)
                x: (1 - wipe.progress) * (wipe.width + wipe.leanWidth / 2 + 2) - wipe.progress * (wipe.leanWidth / 2 + 2)
                width: wipe.width + wipe.leanWidth + 4
                height: wipe.height
                clip: true

                transform: Matrix4x4
                {
                    matrix: Qt.matrix4x4(1, -picker.slant, 0, wipe.leanWidth / 2,
                                         0, 1, 0, 0,
                                         0, 0, 1, 0,
                                         0, 0, 0, 1)
                }

                // The wallpaper, held still on the screen (and leaned back so it stays straight), drifting in slightly from the right
                Image
                {
                    id: applyPicture

                    x: -wipeWindow.x + 90 * (1 - wipe.progress)
                    width: wipe.width
                    height: wipe.height
                    source: wipe.path !== "" ? "file://" + wipe.path : ""
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    sourceSize.width: picker.width
                    sourceSize.height: picker.height
                    smooth: true
                    mipmap: true

                    transform: Matrix4x4
                    {
                        matrix: Qt.matrix4x4(1, picker.slant, 0, -wipe.leanWidth / 2,
                                             0, 1, 0, 0,
                                             0, 0, 1, 0,
                                             0, 0, 0, 1)
                    }
                }

                // The leading edge: a thin bright line with soft light trailing behind it
                Rectangle
                {
                    width: 140
                    height: parent.height
                    opacity: wipe.progress < 0.97 ? 0.45 : 0

                    Behavior on opacity
                    {
                        NumberAnimation { duration: 200 }
                    }

                    gradient: Gradient
                    {
                        orientation: Gradient.Horizontal

                        GradientStop { position: 0; color: Theme.pastel }
                        GradientStop { position: 1; color: "transparent" }
                    }
                }

                Rectangle
                {
                    width: 3
                    height: parent.height
                    color: "#FFFFFF"
                    opacity: wipe.progress < 0.97 ? 0.9 : 0

                    Behavior on opacity
                    {
                        NumberAnimation { duration: 200 }
                    }
                }
            }
        }
    }

    // Section: Keys
    // Left and right move along, Enter uses the wallpaper in the middle, L puts it on the login screen
    Item
    {
        focus: true

        Keys.onLeftPressed:
        {
            picker.menuPath = "";
            strip.decrementCurrentIndex();
        }
        Keys.onRightPressed:
        {
            picker.menuPath = "";
            strip.incrementCurrentIndex();
        }
        Keys.onReturnPressed: picker.useWallpaper(picker.currentPath)
        Keys.onEnterPressed: picker.useWallpaper(picker.currentPath)
        Keys.onPressed: (Event) =>
        {
            if (Event.key === Qt.Key_L)
            {
                picker.useForLogin(picker.currentPath);
                Event.accepted = true;
            }
        }
    }

    // Section: Layout
    Column
    {
        width: parent.width
        spacing: 16

        // Section: Toolbar
        // Colour dots to filter by, and a button to go back to the Shrine colours
        Rectangle
        {
            anchors.horizontalCenter: parent.horizontalCenter
            width: toolbarRow.implicitWidth + 20
            height: 36
            radius: 18
            color: Theme.panel
            border.width: 1
            border.color: Theme.edge

            // Fades out while a wallpaper is applied
            opacity: picker.applying ? 0 : 1

            Behavior on opacity
            {
                NumberAnimation { duration: 250 }
            }

            Row
            {
                id: toolbarRow

                anchors.centerIn: parent
                spacing: 8

                // All wallpapers
                Rectangle
                {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 46
                    height: 22
                    radius: 11
                    color: picker.filter === "all" ? Theme.pastel : Theme.card

                    Text
                    {
                        anchors.centerIn: parent
                        text: "ALL"
                        color: picker.filter === "all" ? Theme.pastelText : Theme.muted
                        font.family: Theme.font
                        font.pixelSize: 10
                        font.bold: true
                    }

                    MouseArea
                    {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: picker.pickFilter("all")
                    }
                }

                // One dot per colour family (hidden when this Quickshell can't read colours)
                Repeater
                {
                    model: picker.coloursWork ? picker.familyDots : []

                    Item
                    {
                        id: dot

                        required property var modelData

                        property bool active: picker.filter === modelData.name

                        anchors.verticalCenter: parent.verticalCenter
                        width: 22
                        height: 22

                        // Ring round the filter in use
                        Rectangle
                        {
                            anchors.fill: parent
                            radius: width / 2
                            color: "transparent"
                            border.width: 2
                            border.color: Theme.pastel
                            visible: dot.active
                        }

                        Rectangle
                        {
                            anchors.centerIn: parent
                            width: dot.active ? 14 : 16
                            height: width
                            radius: width / 2
                            color: dot.modelData.colour

                            Behavior on width
                            {
                                NumberAnimation { duration: 120 }
                            }
                        }

                        MouseArea
                        {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: picker.pickFilter(dot.modelData.name)
                        }
                    }
                }

                Rectangle
                {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 1
                    height: 16
                    color: Theme.edge
                }

                // Back to the Shrine colours (keeps the wallpaper)
                Text
                {
                    anchors.verticalCenter: parent.verticalCenter
                    text: ""
                    color: Theme.wallpaper === "" ? Theme.outline : Theme.muted
                    font.family: Theme.font
                    font.pixelSize: 13

                    MouseArea
                    {
                        anchors.fill: parent
                        anchors.margins: -6
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Theme.reset()
                    }
                }

                // Opens the wallpaper folder
                Text
                {
                    anchors.verticalCenter: parent.verticalCenter
                    text: ""
                    color: Theme.muted
                    font.family: Theme.font
                    font.pixelSize: 13

                    MouseArea
                    {
                        anchors.fill: parent
                        anchors.margins: -6
                        cursorShape: Qt.PointingHandCursor
                        onClicked:
                        {
                            Quickshell.execDetached(["bash", Quickshell.env("HOME") + "/.config/shrine-waybar/run.sh", "open-folder", picker.folder]);
                            picker.closeMenu();
                        }
                    }
                }
            }
        }

        // Section: Strip
        ListView
        {
            id: strip

            width: parent.width
            height: picker.stripHeight
            orientation: ListView.Horizontal
            spacing: 10
            clip: false
            model: picker.filtered
            visible: picker.filtered.length > 0

            // Room either side so the first and last cards can sit in the middle too
            leftMargin: (width - picker.wideWidth) / 2
            rightMargin: (width - picker.wideWidth) / 2

            // The strip is moved by the picker (centre), not by dragging, so the chosen card never leaves the middle
            interactive: false
            highlightFollowsCurrentItem: false
            cacheBuffer: 1200

            Behavior on contentX
            {
                id: stripSlide

                NumberAnimation { duration: 380; easing.type: Easing.OutCubic }
            }

            onCurrentIndexChanged: picker.centre(true)
            onCountChanged: picker.centre(false)
            onWidthChanged: picker.centre(false)

            // Scrolling moves one card at a time
            WheelHandler
            {
                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                onWheel: (Wheel) =>
                {
                    picker.menuPath = "";

                    if (Wheel.angleDelta.y > 0 || Wheel.angleDelta.x > 0)
                    {
                        strip.decrementCurrentIndex();
                    }
                    else
                    {
                        strip.incrementCurrentIndex();
                    }
                }
            }

            delegate: Item
            {
                id: card

                required property string modelData
                required property int index

                property bool isCurrent: ListView.isCurrentItem

                // Rising in when the picker opens: the middle card first, the ones further out a little later
                property real rise: Math.max(0, Math.min(1, picker.reveal * 1.8 - Math.abs(index - strip.currentIndex) * 0.12))

                // How far it slides left when a wallpaper is picked (cards further right travel further, so they bunch up as they go)
                property real flyDistance: picker.width * 0.75 + (index - strip.currentIndex) * 120

                // The card with its menu open sits above its neighbours, so the menu isn't covered
                z: picker.menuPath === modelData ? 10 : 0

                width: isCurrent ? picker.wideWidth : picker.narrowWidth
                height: picker.stripHeight

                opacity: rise * (1 - picker.flyOut)

                transform: Translate
                {
                    x: -card.flyDistance * picker.flyOut
                    y: (1 - card.rise) * 70
                }

                Behavior on width
                {
                    NumberAnimation { duration: 380; easing.type: Easing.OutCubic }
                }

                // The slanted frame: leaning about its middle keeps the gaps between cards even
                Rectangle
                {
                    id: frame

                    anchors.fill: parent
                    clip: true
                    color: Theme.panel

                    transform: Matrix4x4
                    {
                        matrix: Qt.matrix4x4(1, -picker.slant, 0, picker.slant * picker.stripHeight / 2,
                                             0, 1, 0, 0,
                                             0, 0, 1, 0,
                                             0, 0, 0, 1)
                    }

                    // The picture, leaned back the other way so it stays straight inside the slanted frame
                    Image
                    {
                        anchors.centerIn: parent
                        width: picker.wideWidth + picker.slant * picker.stripHeight
                        height: parent.height
                        source: "file://" + card.modelData
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        sourceSize.width: 1280
                        sourceSize.height: 720
                        smooth: true
                        mipmap: true

                        transform: Matrix4x4
                        {
                            matrix: Qt.matrix4x4(1, picker.slant, 0, -picker.slant * picker.stripHeight / 2,
                                                 0, 1, 0, 0,
                                                 0, 0, 1, 0,
                                                 0, 0, 0, 1)
                        }
                    }

                    // Cards that aren't chosen are dimmed
                    Rectangle
                    {
                        anchors.fill: parent
                        color: "#000000"
                        opacity: card.isCurrent ? 0 : 0.4

                        Behavior on opacity
                        {
                            NumberAnimation { duration: 250 }
                        }
                    }

                    // Edge drawn over the picture: cream round the chosen card
                    Rectangle
                    {
                        anchors.fill: parent
                        color: "transparent"
                        border.width: card.isCurrent ? 2 : 1
                        border.color: card.isCurrent ? Theme.pastel : Theme.edge
                    }
                }

                // Click picks or uses a card; right-click opens its menu
                MouseArea
                {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    onClicked: (Mouse) =>
                    {
                        if (Mouse.button === Qt.RightButton)
                        {
                            strip.currentIndex = card.index;
                            cardMenu.x = Math.min(Mouse.x, card.width - cardMenu.width - 8);
                            cardMenu.y = Math.min(Mouse.y, card.height - cardMenu.height - 8);
                            picker.menuPath = card.modelData;
                            return;
                        }

                        if (picker.menuPath !== "")
                        {
                            picker.menuPath = "";
                            return;
                        }

                        if (card.isCurrent)
                        {
                            picker.useWallpaper(card.modelData);
                        }
                        else
                        {
                            strip.currentIndex = card.index;
                        }
                    }
                }

                // Section: Right-click menu
                // Use it (desktop and lock screen), or put it on the login screen too
                Rectangle
                {
                    id: cardMenu

                    visible: picker.menuPath === card.modelData
                    width: 220
                    height: menuColumn.implicitHeight + 12
                    radius: 12
                    color: Theme.panel
                    border.width: 1
                    border.color: Theme.edge

                    Column
                    {
                        id: menuColumn

                        anchors.fill: parent
                        anchors.margins: 6

                        Repeater
                        {
                            model: [
                                { "name": "use", "icon": "\uf03e", "label": "Use as wallpaper" },
                                { "name": "login", "icon": "\uf023", "label": "Set as login screen" }
                            ]

                            Rectangle
                            {
                                id: menuItem

                                required property var modelData

                                width: menuColumn.width
                                height: 34
                                radius: 8
                                color: itemHover.containsMouse ? Theme.cardHover : "transparent"

                                Text
                                {
                                    id: itemIcon

                                    anchors.left: parent.left
                                    anchors.leftMargin: 12
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 16
                                    text: menuItem.modelData.icon
                                    color: Theme.pastel
                                    font.family: Theme.font
                                    font.pixelSize: 12
                                }

                                Text
                                {
                                    anchors.left: itemIcon.right
                                    anchors.leftMargin: 10
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: menuItem.modelData.label
                                    color: Theme.text
                                    font.family: Theme.font
                                    font.pixelSize: 12
                                }

                                // The login screen one needs your password, so it says so
                                Text
                                {
                                    anchors.right: parent.right
                                    anchors.rightMargin: 10
                                    anchors.verticalCenter: parent.verticalCenter
                                    visible: menuItem.modelData.name === "login"
                                    text: "\uf084"
                                    color: Theme.muted
                                    font.family: Theme.font
                                    font.pixelSize: 10
                                }

                                MouseArea
                                {
                                    id: itemHover

                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked:
                                    {
                                        if (menuItem.modelData.name === "login")
                                        {
                                            picker.useForLogin(card.modelData);
                                        }
                                        else
                                        {
                                            picker.menuPath = "";
                                            picker.useWallpaper(card.modelData);
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // Section: Empty folder
        Rectangle
        {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: picker.filtered.length === 0
            width: 460
            height: 120
            radius: 18
            color: Theme.panel
            border.width: 1
            border.color: Theme.edge

            Text
            {
                anchors.centerIn: parent
                width: parent.width - 40
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                lineHeight: 1.4
                text: picker.wallpapers.length === 0
                      ? "No wallpapers yet.\nAdd images to " + picker.folder.replace(Quickshell.env("HOME"), "~") + " (the folder button above opens it)."
                      : "No " + picker.filter + " wallpapers.\nPick another colour, or ALL."
                color: Theme.muted
                font.family: Theme.font
                font.pixelSize: 12
            }
        }

        // Section: Caption
        // The chosen wallpaper's name, the colours it would give, and how to use it
        Rectangle
        {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: picker.currentPath !== ""
            width: captionRow.implicitWidth + 28
            height: 36
            radius: 18
            color: Theme.panel
            border.width: 1
            border.color: Theme.edge

            // Fades out while a wallpaper is applied
            opacity: picker.applying ? 0 : 1

            Behavior on opacity
            {
                NumberAnimation { duration: 250 }
            }

            Row
            {
                id: captionRow

                anchors.centerIn: parent
                spacing: 12

                Text
                {
                    anchors.verticalCenter: parent.verticalCenter
                    text: picker.fileName(picker.currentPath)
                    color: Theme.text
                    font.family: Theme.font
                    font.pixelSize: 12
                    font.bold: true
                }

                // A preview of the colours this wallpaper would give
                Row
                {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 4
                    visible: picker.palettes[picker.currentPath] !== undefined

                    Repeater
                    {
                        model:
                        {
                            const Colours = picker.palettes[picker.currentPath];

                            if (!Colours)
                            {
                                return [];
                            }

                            const Preview = Palette.fromSummary(Colours);
                            return [Preview.accent, Preview.accentHover, Preview.pastel, Preview.bar];
                        }

                        Rectangle
                        {
                            required property var modelData

                            width: 14
                            height: 14
                            radius: 7
                            color: modelData
                            border.width: 1
                            border.color: Theme.edge
                        }
                    }
                }

                Text
                {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "ENTER OR CLICK TO USE · RIGHT-CLICK OR L FOR LOGIN SCREEN · ESC TO CLOSE"
                    color: Theme.muted
                    opacity: 0.7
                    font.family: Theme.font
                    font.pixelSize: 9
                    font.bold: true
                    font.letterSpacing: 1
                }
            }
        }
    }
}
