// This file contains the colours, font and motion every Shrine menu shares
// They start as the Shrine palette; picking a wallpaper swaps them for colours from it (saved in ~/.local/state/shrine-waybar/theme.json)

pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import "Palette.js" as Palette

// Section: Theme
Singleton
{
    id: theme

    // Section: Colours
    // Menu panel fill (darker than the bar, nearly solid), its faint edge, and the grey used for switched-off things
    property color panel: "#F71C1611"
    property color edge: "#1FFFFFFF"
    property color outline: "#86979A"
    property color outlineSoft: "#4D86979A"

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

    // The island and Waybar: bar fill, the island's fill, the deep red behind hovered buttons, and the orange highlight
    property color bar: "#2A1D11"
    property color island: "#EB2A1D11"
    property color deep: "#99931A13"
    property color warm: "#FF8C00"

    // The pop-up tick for a finished command, and the cross for a failed one
    property color success: "#8FBF7F"
    property color failure: "#CB3F27"

    // Which wallpaper the colours came from ("" means the Shrine colours)
    property string wallpaper: ""

    // Section: Colour changes
    // A new wallpaper fades every colour across instead of switching in one jump (as long as the picker's wipe takes)
    readonly property int fadeDuration: 1100

    Behavior on panel
    {
        ColorAnimation { duration: theme.fadeDuration; easing.type: Easing.InOutQuad }
    }

    Behavior on outline
    {
        ColorAnimation { duration: theme.fadeDuration; easing.type: Easing.InOutQuad }
    }

    Behavior on outlineSoft
    {
        ColorAnimation { duration: theme.fadeDuration; easing.type: Easing.InOutQuad }
    }

    Behavior on pastel
    {
        ColorAnimation { duration: theme.fadeDuration; easing.type: Easing.InOutQuad }
    }

    Behavior on pastelText
    {
        ColorAnimation { duration: theme.fadeDuration; easing.type: Easing.InOutQuad }
    }

    Behavior on glowA
    {
        ColorAnimation { duration: theme.fadeDuration; easing.type: Easing.InOutQuad }
    }

    Behavior on glowB
    {
        ColorAnimation { duration: theme.fadeDuration; easing.type: Easing.InOutQuad }
    }

    Behavior on accent
    {
        ColorAnimation { duration: theme.fadeDuration; easing.type: Easing.InOutQuad }
    }

    Behavior on accentHover
    {
        ColorAnimation { duration: theme.fadeDuration; easing.type: Easing.InOutQuad }
    }

    Behavior on text
    {
        ColorAnimation { duration: theme.fadeDuration; easing.type: Easing.InOutQuad }
    }

    Behavior on muted
    {
        ColorAnimation { duration: theme.fadeDuration; easing.type: Easing.InOutQuad }
    }

    Behavior on accentText
    {
        ColorAnimation { duration: theme.fadeDuration; easing.type: Easing.InOutQuad }
    }

    Behavior on soft
    {
        ColorAnimation { duration: theme.fadeDuration; easing.type: Easing.InOutQuad }
    }

    Behavior on softHover
    {
        ColorAnimation { duration: theme.fadeDuration; easing.type: Easing.InOutQuad }
    }

    Behavior on bar
    {
        ColorAnimation { duration: theme.fadeDuration; easing.type: Easing.InOutQuad }
    }

    Behavior on island
    {
        ColorAnimation { duration: theme.fadeDuration; easing.type: Easing.InOutQuad }
    }

    Behavior on deep
    {
        ColorAnimation { duration: theme.fadeDuration; easing.type: Easing.InOutQuad }
    }

    Behavior on success
    {
        ColorAnimation { duration: theme.fadeDuration; easing.type: Easing.InOutQuad }
    }

    Behavior on failure
    {
        ColorAnimation { duration: theme.fadeDuration; easing.type: Easing.InOutQuad }
    }

    Behavior on warm
    {
        ColorAnimation { duration: theme.fadeDuration; easing.type: Easing.InOutQuad }
    }

    // Section: Font
    property string font: "JetBrainsMono Nerd Font"

    // Section: Motion
    // How long the spring takes to open a menu, in milliseconds
    property int openDuration: 380

    // Section: Switching colours
    // The apply function sets every colour from a theme object (anything it leaves out keeps the Shrine colour)
    function apply(Colours)
    {
        const Full = Object.assign(Palette.shrine(), Colours || {});

        for (const Name in Full)
        {
            if (theme[Name] !== undefined && Name !== "wallpaper")
            {
                theme[Name] = Full[Name];
            }
        }
    }

    // The save function applies a theme, remembers it, and recolours Waybar to match
    function save(Colours, Wallpaper)
    {
        apply(Colours);
        wallpaper = Wallpaper || "";

        const Saved = Object.assign({ "wallpaper": wallpaper }, Palette.shrine(), Colours || {});
        saveProcess.command = ["bash", Quickshell.env("HOME") + "/.config/shrine-waybar/run.sh", "apply-theme", JSON.stringify(Saved), Palette.waybarCss(Saved)];
        saveProcess.running = true;
    }

    // The reset function goes back to the Shrine colours everywhere
    function reset()
    {
        save(Palette.shrine(), "");
    }

    Process
    {
        id: saveProcess
    }

    // Loads the saved theme when Quickshell starts
    Process
    {
        command: ["cat", Quickshell.env("HOME") + "/.local/state/shrine-waybar/theme.json"]
        running: true

        stdout: SplitParser
        {
            onRead: (Line) =>
            {
                try
                {
                    const Saved = JSON.parse(Line);
                    theme.apply(Saved);
                    theme.wallpaper = Saved.wallpaper || "";
                }
                catch (Problem)
                {
                }
            }
        }
    }
}
