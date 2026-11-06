// This file contains the colours, font and motion every Shrine menu shares
// They start as the Shrine palette; the wallpaper picker will later replace them with colours from your wallpaper

pragma Singleton

import Quickshell
import QtQuick

// Section: Theme
Singleton
{
    // Section: Colours
    // Menu panel fill (darker than the bar, nearly solid), its faint edge, and the grey used for switched-off things
    property color panel: "#F71C1611"
    property color edge: "#1FFFFFFF"
    property color outline: "#86979A"

    // Cards inside a panel: a slightly lighter fill with a faint border, brighter on hover
    property color card: "#0DFFFFFF"
    property color cardBorder: "#14FFFFFF"
    property color cardHover: "#1AFFFFFF"

    // The soft fill for whatever's selected or switched on, and the dark text that sits on it
    property color pastel: "#E5D3B3"
    property color pastelText: "#1C1611"

    // Colours of the glow in each panel's corners
    property color glowA: "#CB3F27"
    property color glowB: "#E18A42"

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
