// This file contains the colours, font and motion every Shrine menu shares
// They start as the Shrine palette; the wallpaper picker will later replace them with colours from your wallpaper

pragma Singleton

import Quickshell
import QtQuick

// Section: Theme
Singleton
{
    // Section: Colours
    // Panel fill and outline, matching the Waybar pills
    property color panel: "#F22A1D11"
    property color outline: "#86979A"

    // Maple red for selected things, gold for hover outlines
    property color accent: "#CB3F27"
    property color accentHover: "#E18A42"

    // Text on the panel, softer text, and text sitting on the accent colour
    property color text: "#F1EFE8"
    property color muted: "#E5D3B3"
    property color accentText: "#FFF6EC"

    // Faint fills for tiles and the search box, and a stronger one for hover
    property color soft: "#1AE5D3B3"
    property color softHover: "#2EE5D3B3"

    // Section: Font
    property string font: "JetBrainsMono Nerd Font"

    // Section: Motion
    // How long the spring takes to open a menu, in milliseconds
    property int openDuration: 380
}
