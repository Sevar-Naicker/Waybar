// This file contains the window every Shrine menu opens in
// It covers the screen so a click anywhere outside the menu closes it, closes on Escape too, and springs the menu open below the bar

import Quickshell
import Quickshell.Wayland
import QtQuick

// Section: Menu window
PanelWindow
{
    id: menuWindow

    // Section: Settings each menu sets
    // Whether the menu is open
    property bool shown: false

    // Panel width, and which side of the screen it drops down on: "left", "centre" or "right"
    property real panelWidth: 400
    property string side: "left"

    // Whatever the menu puts inside goes into the panel
    default property alias content: contentArea.data

    // Stays visible just long enough for the closing animation to finish
    visible: shown || closeTimer.running

    anchors
    {
        top: true
        bottom: true
        left: true
        right: true
    }

    exclusionMode: ExclusionMode.Ignore
    color: "transparent"

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "shrine-menu"

    // Takes the keyboard while open, so typing goes to the menu
    WlrLayershell.keyboardFocus: shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    // The closeMenu function hides the menu (the animation plays, then the window goes away)
    function closeMenu()
    {
        shown = false;
    }

    // Section: Closing
    Timer
    {
        id: closeTimer
        interval: 220
    }

    Connections
    {
        target: menuWindow

        function onShownChanged()
        {
            if (!menuWindow.shown)
            {
                closeTimer.restart();
            }
        }
    }

    Shortcut
    {
        sequence: "Escape"
        onActivated: menuWindow.closeMenu()
    }

    // A click anywhere outside the panel closes the menu
    MouseArea
    {
        anchors.fill: parent
        onClicked: menuWindow.closeMenu()
    }

    // Section: Panel
    Rectangle
    {
        id: panelBox

        // Waybar pills sit 9px down and are 26px tall, so the panel starts just under them
        y: 42
        x:
        {
            if (menuWindow.side === "right")
            {
                return parent.width - width - 10;
            }

            if (menuWindow.side === "centre")
            {
                return (parent.width - width) / 2;
            }

            return 10;
        }

        width: menuWindow.panelWidth
        height: contentArea.childrenRect.height + 28
        radius: 20
        color: Theme.panel
        border.width: 1
        border.color: Theme.outline

        // Springs down from the bar when opening, shrinks back when closing
        transformOrigin: menuWindow.side === "right" ? Item.TopRight : (menuWindow.side === "centre" ? Item.Top : Item.TopLeft)
        opacity: menuWindow.shown ? 1 : 0
        scale: menuWindow.shown ? 1 : 0.94

        Behavior on opacity
        {
            NumberAnimation { duration: 180 }
        }

        Behavior on scale
        {
            NumberAnimation { duration: Theme.openDuration; easing.type: Easing.OutBack; easing.overshoot: 1.3 }
        }

        // Clicks on the panel itself stay in the panel instead of closing the menu
        MouseArea
        {
            anchors.fill: parent
        }

        Item
        {
            id: contentArea

            x: 14
            y: 14
            width: parent.width - 28
            height: childrenRect.height
        }
    }
}
