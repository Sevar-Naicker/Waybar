#!/usr/bin/env bash
# This file contains the login screen wallpaper helper
# It runs as root (run.sh starts it through pkexec, which asks for your password) and puts one picture on Plasma Login Manager's screen
#   login-wallpaper.sh <picture>
# Exit codes: 0 done, 2 not a picture, 3 Plasma Login Manager isn't in use

set -u

# Section: Settings
Config=/etc/plasmalogin.conf
Folder=/var/lib/plasmalogin/wallpapers
Picture=${1:-}

# Section: Checks
if [ -z "$Picture" ] || [ ! -f "$Picture" ]
then
    echo "login-wallpaper: no picture at '$Picture'" >&2
    exit 2
fi

# Asks file what it is, or goes by the name if file isn't installed
if command -v file >/dev/null 2>&1
then
    Kind=$(file -b --mime-type -- "$Picture")
else
    Kind="image/${Picture##*.}"
fi

case "$Kind" in
    image/*) ;;
    *)
        echo "login-wallpaper: '$Picture' isn't a picture" >&2
        exit 2
        ;;
esac

# Plasma Login Manager runs its screen as its own plasmalogin user
if ! id plasmalogin >/dev/null 2>&1
then
    echo "login-wallpaper: Plasma Login Manager isn't installed, so there's no login screen this can change" >&2
    exit 3
fi

# Section: Copy the picture
# It lives in the login screen's own folder (it can't read your home folder), under one fixed name so old ones don't pile up
Extension=${Picture##*.}
Extension=${Extension,,}
Target="$Folder/ukishima.$Extension"

mkdir -p "$Folder"
rm -f "$Folder"/ukishima.*
install -m 644 -o plasmalogin -g plasmalogin -- "$Picture" "$Target"
chown plasmalogin:plasmalogin "$Folder"
chmod 755 "$Folder"

# Section: Point the login screen at it
# Keeps a copy of the original settings the first time
[ -f "$Config" ] && [ ! -f "$Config.ukishima-backup" ] && cp -a "$Config" "$Config.ukishima-backup"

kwriteconfig6 --file "$Config" --group Greeter --key WallpaperPluginId org.kde.image
kwriteconfig6 --file "$Config" --group Greeter --group Wallpaper --group org.kde.image --group General --key Image "file://$Target"
chmod 644 "$Config"
