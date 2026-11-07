// This file contains the colour maths for wallpaper-matched themes
// It reads a wallpaper's pixels, finds the colours that really cover it, turns them into a full Shrine theme, and sorts wallpapers into colour families

.pragma library

// Section: Shrine palette
// The original colours, used until a wallpaper is picked and whenever you reset
const ShrineTheme = {
    "panel": "#F71C1611",
    "edge": "#1FFFFFFF",
    "outline": "#86979A",
    "outlineSoft": "#4D86979A",
    "card": "#0DFFFFFF",
    "cardBorder": "#14FFFFFF",
    "cardHover": "#1AFFFFFF",
    "pastel": "#E5D3B3",
    "pastelText": "#1C1611",
    "glowA": "#CB3F27",
    "glowB": "#E18A42",
    "accent": "#CB3F27",
    "accentHover": "#E18A42",
    "text": "#F1EFE8",
    "muted": "#E5D3B3",
    "accentText": "#FFF6EC",
    "soft": "#1AE5D3B3",
    "softHover": "#2EE5D3B3",
    "bar": "#2A1D11",
    "island": "#EB2A1D11",
    "deep": "#99931A13",
    "warm": "#FF8C00",
    "success": "#8FBF7F",
    "failure": "#CB3F27"
};

// The shrine function gives a fresh copy of the original colours
function shrine()
{
    return Object.assign({}, ShrineTheme);
}

// Section: Colour helpers
// The clamp function keeps a number between two limits
function clamp(Value, Low, High)
{
    return Math.max(Low, Math.min(High, Value));
}

// The toHsl function turns red, green and blue (0 to 1) into hue (0 to 360), saturation and lightness (0 to 1)
function toHsl(Red, Green, Blue)
{
    const High = Math.max(Red, Green, Blue);
    const Low = Math.min(Red, Green, Blue);
    const Lightness = (High + Low) / 2;
    let Hue = 0;
    let Saturation = 0;

    if (High !== Low)
    {
        const Range = High - Low;
        Saturation = Lightness > 0.5 ? Range / (2 - High - Low) : Range / (High + Low);

        if (High === Red)
        {
            Hue = (Green - Blue) / Range + (Green < Blue ? 6 : 0);
        }
        else if (High === Green)
        {
            Hue = (Blue - Red) / Range + 2;
        }
        else
        {
            Hue = (Red - Green) / Range + 4;
        }

        Hue *= 60;
    }

    return { "h": Hue, "s": Saturation, "l": Lightness };
}

// The hex function turns hue, saturation, lightness and an optional alpha into "#RRGGBB" or "#AARRGGBB"
function hex(Hue, Saturation, Lightness, Alpha)
{
    const Chroma = (1 - Math.abs(2 * Lightness - 1)) * Saturation;
    const Part = Chroma * (1 - Math.abs(((Hue / 60) % 2) - 1));
    const Base = Lightness - Chroma / 2;
    const Sector = Math.floor(((Hue % 360) + 360) % 360 / 60);
    const Mixes = [[Chroma, Part, 0], [Part, Chroma, 0], [0, Chroma, Part], [0, Part, Chroma], [Part, 0, Chroma], [Chroma, 0, Part]];
    const Mix = Mixes[Sector];

    // The byte function turns 0 to 1 into two hex digits
    function byte(Value)
    {
        return Math.round(clamp(Value, 0, 1) * 255).toString(16).padStart(2, "0").toUpperCase();
    }

    const Colour = byte(Mix[0] + Base) + byte(Mix[1] + Base) + byte(Mix[2] + Base);

    return Alpha === undefined || Alpha >= 1 ? "#" + Colour : "#" + byte(Alpha) + Colour;
}

// Section: Contrast
// The luminance function gives how bright a "#RRGGBB" colour looks to the eye (0 black to 1 white)
function luminance(Colour)
{
    const Plain = Colour.slice(-6);
    const Channels = [0, 2, 4].map(Start => parseInt(Plain.slice(Start, Start + 2), 16) / 255)
                              .map(Value => Value <= 0.03928 ? Value / 12.92 : Math.pow((Value + 0.055) / 1.055, 2.4));
    return 0.2126 * Channels[0] + 0.7152 * Channels[1] + 0.0722 * Channels[2];
}

// The contrast function gives the contrast ratio between two colours (1 to 21; 3 is the usual minimum for icons)
function contrast(First, Second)
{
    const A = luminance(First);
    const B = luminance(Second);
    return (Math.max(A, B) + 0.05) / (Math.min(A, B) + 0.05);
}

// The readable function lightens a colour (keeping its hue) until it stands out clearly against a dark background
function readable(Hue, Saturation, Lightness, Background, Needed)
{
    let Light = Lightness;

    while (Light < 0.9 && contrast(hex(Hue, Saturation, Light), Background) < Needed)
    {
        Light += 0.02;
    }

    return hex(Hue, Saturation, Light);
}

// The towards function moves a hue part of the way towards another, the short way round
function towards(Hue, Target, Share)
{
    let Gap = ((Target - Hue + 540) % 360) - 180;
    return (Hue + Gap * Share + 360) % 360;
}

// Section: Reading a wallpaper
// Hues are counted in 24 slices of 15°, weighted by how colourful each pixel is, so the colours that cover the picture win
const HueSlices = 24;

// The summarise function reads RGBA pixel data (from a small copy of the image) and returns
// { colourful, main: {h, s, l}, second: {h, s, l} or null, family }
function summarise(Pixels)
{
    const Slices = [];
    let Total = 0;
    let Colourful = 0;

    for (let Index = 0; Index < HueSlices; Index++)
    {
        Slices.push({ "weight": 0, "h": 0, "s": 0, "l": 0, "x": 0, "y": 0 });
    }

    for (let Index = 0; Index + 3 < Pixels.length; Index += 4)
    {
        if (Pixels[Index + 3] < 128)
        {
            continue;
        }

        Total += 1;
        const Hsl = toHsl(Pixels[Index] / 255, Pixels[Index + 1] / 255, Pixels[Index + 2] / 255);

        // Greys, near-blacks and near-whites don't count towards a colour
        if (Hsl.s < 0.25 || Hsl.l < 0.12 || Hsl.l > 0.88)
        {
            continue;
        }

        Colourful += 1;

        const Weight = Hsl.s * (1 - Math.abs(Hsl.l - 0.5) * 1.4);
        const Slice = Slices[Math.floor(Hsl.h / (360 / HueSlices)) % HueSlices];
        const Angle = Hsl.h * Math.PI / 180;

        Slice.weight += Weight;
        Slice.s += Hsl.s * Weight;
        Slice.l += Hsl.l * Weight;

        // Hues are averaged as directions, so 355° and 5° average to 0°, not 180°
        Slice.x += Math.cos(Angle) * Weight;
        Slice.y += Math.sin(Angle) * Weight;
    }

    // Less than 4% colourful pixels: a black, white or grey wallpaper
    if (Total === 0 || Colourful / Total < 0.04)
    {
        return { "colourful": false, "main": null, "second": null, "family": "grey" };
    }

    // The colour of a slice and its two neighbours together, so a hue sitting on a slice edge isn't split in two
    function around(Centre)
    {
        let Weight = 0;
        let X = 0;
        let Y = 0;
        let Saturation = 0;
        let Lightness = 0;

        for (const Offset of [-1, 0, 1])
        {
            const Slice = Slices[(Centre + Offset + HueSlices) % HueSlices];
            Weight += Slice.weight;
            X += Slice.x;
            Y += Slice.y;
            Saturation += Slice.s;
            Lightness += Slice.l;
        }

        return {
            "weight": Weight,
            "h": (Math.atan2(Y, X) * 180 / Math.PI + 360) % 360,
            "s": Weight > 0 ? Saturation / Weight : 0,
            "l": Weight > 0 ? Lightness / Weight : 0
        };
    }

    let MainSlice = 0;

    for (let Index = 1; Index < HueSlices; Index++)
    {
        if (around(Index).weight > around(MainSlice).weight)
        {
            MainSlice = Index;
        }
    }

    const Main = around(MainSlice);

    // A second colour only if the wallpaper really has one: at least 45° away and a fifth as strong as the main one
    let Second = null;

    for (let Index = 0; Index < HueSlices; Index++)
    {
        const Gap = Math.min(Math.abs(Index - MainSlice), HueSlices - Math.abs(Index - MainSlice));
        const Candidate = around(Index);

        if (Gap >= 3 && Candidate.weight >= Main.weight * 0.2 && (!Second || Candidate.weight > Second.weight))
        {
            Second = Candidate;
        }
    }

    return { "colourful": true, "main": Main, "second": Second, "family": familyOf(Main.h) };
}

// Section: Families
// The familyOf function names the colour family of a hue, for the picker's filters
function familyOf(Hue)
{
    if (Hue < 15 || Hue >= 345)
    {
        return "red";
    }

    if (Hue < 40)
    {
        return "orange";
    }

    if (Hue < 66)
    {
        return "yellow";
    }

    if (Hue < 170)
    {
        return "green";
    }

    if (Hue < 255)
    {
        return "blue";
    }

    if (Hue < 290)
    {
        return "purple";
    }

    return "pink";
}

// Section: Themes
// The fromSummary function builds a full theme from a wallpaper summary; every colour comes from the wallpaper's own hues
function fromSummary(Summary)
{
    if (!Summary)
    {
        return shrine();
    }

    // Black, white and grey wallpapers get a quiet, neutral theme instead of an invented colour
    if (!Summary.colourful)
    {
        return {
            "panel": hex(0, 0, 0.075, 0.97),
            "edge": "#1FFFFFFF",
            "outline": hex(0, 0, 0.58),
            "outlineSoft": hex(0, 0, 0.58, 0.3),
            "card": "#0DFFFFFF",
            "cardBorder": "#14FFFFFF",
            "cardHover": "#1AFFFFFF",
            "pastel": hex(0, 0, 0.84),
            "pastelText": hex(0, 0, 0.09),
            "glowA": hex(0, 0, 0.6),
            "glowB": hex(0, 0, 0.75),
            "accent": hex(0, 0, 0.62),
            "accentHover": hex(0, 0, 0.76),
            "text": hex(0, 0, 0.94),
            "muted": hex(0, 0, 0.8),
            "accentText": hex(0, 0, 0.08),
            "soft": hex(0, 0, 0.8, 0.1),
            "softHover": hex(0, 0, 0.8, 0.18),
            "bar": hex(0, 0, 0.12),
            "island": hex(0, 0, 0.12, 0.92),
            "deep": hex(0, 0, 0.3, 0.6),
            "warm": hex(0, 0, 0.82),
            "success": hex(130, 0.3, 0.65),
            "failure": hex(5, 0.55, 0.6)
        };
    }

    const Main = Summary.main;
    const Hue = Main.h;

    // The second colour is the wallpaper's own second colour, or else a lighter shade of the main one
    const Second = Summary.second || { "h": Hue, "s": Main.s, "l": Math.min(0.72, Main.l + 0.2) };

    const MainSaturation = clamp(Main.s, 0.45, 0.9);
    const SecondSaturation = clamp(Second.s, 0.4, 0.9);

    // The bar everything sits on; accents are lightened (same hue) until they're clearly visible on it
    const Bar = hex(Hue, 0.32, 0.12);
    const Accent = readable(Hue, MainSaturation, clamp(Main.l, 0.4, 0.55), Bar, 3.5);
    const AccentHover = readable(Second.h, SecondSaturation, clamp(Second.l, 0.5, 0.65), Bar, 4.5);

    return {
        "panel": hex(Hue, 0.28, 0.075, 0.97),
        "edge": "#1FFFFFFF",
        "outline": hex(Hue, 0.1, 0.58),
        "outlineSoft": hex(Hue, 0.1, 0.58, 0.3),
        "card": "#0DFFFFFF",
        "cardBorder": "#14FFFFFF",
        "cardHover": "#1AFFFFFF",
        "pastel": hex(Hue, 0.45, 0.82),
        "pastelText": hex(Hue, 0.35, 0.09),
        "glowA": Accent,
        "glowB": AccentHover,
        "accent": Accent,
        "accentHover": AccentHover,
        "text": hex(Hue, 0.18, 0.94),
        "muted": hex(Hue, 0.38, 0.8),
        "accentText": hex(Hue, 0.4, 0.97),
        "soft": hex(Hue, 0.38, 0.8, 0.1),
        "softHover": hex(Hue, 0.38, 0.8, 0.18),
        "bar": Bar,
        "island": hex(Hue, 0.32, 0.12, 0.92),
        "deep": hex(Hue, 0.7, 0.3, 0.6),
        "warm": readable(Second.h, clamp(Second.s, 0.6, 0.95), 0.55, Bar, 4.5),

        // The pop-up tick and cross: green and red, nudged a third of the way towards the wallpaper's colour
        "success": readable(towards(130, Hue, 0.33), 0.45, 0.62, Bar, 4.5),
        "failure": readable(towards(5, Hue, 0.2), 0.65, 0.58, Bar, 4.5)
    };
}

// Section: Waybar
// The waybarCss function writes the theme as GTK colour names for Waybar's colours.css
function waybarCss(Theme)
{
    // The plain function drops the alpha from "#AARRGGBB"
    function plain(Colour)
    {
        return Colour.length === 9 ? "#" + Colour.slice(3) : Colour;
    }

    const Names = ["accent", "accentHover", "muted", "outline", "bar", "deep", "warm"];
    let Css = "/* This file contains the colours Waybar uses, written by the wallpaper picker (its reset button goes back to the Shrine colours) */\n";

    for (const Name of Names)
    {
        Css += "@define-color " + Name + " " + plain(Theme[Name]) + ";\n";
    }

    return Css;
}
