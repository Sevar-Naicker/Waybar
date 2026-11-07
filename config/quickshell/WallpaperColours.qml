// This file contains the wallpaper colour reader
// It draws each wallpaper onto a tiny hidden canvas, reads its pixels, and works out which colours really cover it (Palette.js)

import QtQuick
import "Palette.js" as Palette

// Section: Colour reader
Canvas
{
    id: colourReader

    // The wallpapers to read, as plain file paths
    property var paths: []

    // Sent once per wallpaper with its summary: { colourful, main, second, family }
    signal measured(string path, var summary)

    // Wallpapers already read, and the one being read now
    property var done: ({})
    property string reading: ""

    width: 64
    height: 64
    opacity: 0
    renderTarget: Canvas.Image
    renderStrategy: Canvas.Immediate

    onPathsChanged: next()
    onAvailableChanged: next()

    // The next function starts on the next wallpaper that hasn't been read yet
    function next()
    {
        if (reading !== "" || !available)
        {
            return;
        }

        const Path = paths.find(Item => !(Item in done));

        if (Path === undefined)
        {
            return;
        }

        reading = Path;
        const Url = "file://" + Path;

        if (isImageLoaded(Url))
        {
            read(Url);
        }
        else
        {
            loadImage(Url);
        }
    }

    // The read function shrinks the picture to 64×64, reads its pixels, and sends the summary
    function read(Url)
    {
        const Path = reading;
        const Context = getContext("2d");
        let Summary = null;

        try
        {
            Context.clearRect(0, 0, width, height);
            Context.drawImage(Url, 0, 0, width, height);
            Summary = Palette.summarise(Context.getImageData(0, 0, width, height).data);
        }
        catch (Problem)
        {
        }

        unloadImage(Url);

        const Done = Object.assign({}, done);
        Done[Path] = true;
        done = Done;
        reading = "";

        if (Summary)
        {
            measured(Path, Summary);
        }

        next();
    }

    // The skip function gives up on the wallpaper being read (unreadable, or never finished loading)
    function skip()
    {
        const Done = Object.assign({}, done);
        Done[reading] = true;
        done = Done;
        reading = "";
        next();
    }

    Timer
    {
        interval: 4000
        running: colourReader.reading !== ""
        onTriggered: colourReader.skip()
    }

    onImageLoaded:
    {
        if (reading !== "" && isImageLoaded("file://" + reading))
        {
            read("file://" + reading);
        }
        else if (reading !== "" && isImageError("file://" + reading))
        {
            skip();
        }
    }
}
