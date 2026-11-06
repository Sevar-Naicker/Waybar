#!/bin/bash
# This file contains the updates feed for the dynamic island
# Prints one line per check: <restart> <system> <apps>
#   restart: "yes" if a restart is needed to finish updating (a downloaded system update, or a new kernel), otherwise "no"
#   system:  system packages waiting (-1 if this system isn't recognised)
#   apps:    Flatpak apps and runtimes waiting (-1 if Flatpak isn't installed)
# Usage: updates.sh [seconds before the first check]. Checks again every hour after that.

# Section: Settings
. "${XDG_CONFIG_HOME:-$HOME/.config}/shrine-waybar/settings.sh"
FirstCheckDelay=${1:-30}
CheckInterval=3600
CheckTimeout=300

# The count_lines function counts non-empty lines
count_lines()
{
    grep -c . || true
}

# The atomic_restart function says whether rpm-ostree has a downloaded update waiting for a restart
atomic_restart()
{
    rpm-ostree status --json 2>/dev/null | python3 -c '
import json, sys
try:
    Deployments = json.load(sys.stdin)["deployments"]
except Exception:
    print("no")
    sys.exit()
Staged = any(Deployment.get("staged") for Deployment in Deployments)
Pending = bool(Deployments) and not Deployments[0].get("booted", True)
print("yes" if Staged or Pending else "no")
'
}

# The check_system function prints "<restart> <system count>" for this system's package manager
check_system()
{
    local Restart="no"
    local Count=-1

    case "$SHRINE_SYSTEM" in
        atomic)
            # Atomic systems download updates by themselves; they only need a restart to apply
            Restart=$(atomic_restart)
            Count=0
            ;;
        fedora)
            Count=$(timeout "$CheckTimeout" dnf -q check-update 2>/dev/null | grep -E '^[^ ]+\.[^ ]+[[:space:]]+[^ ]+[[:space:]]+[^ ]+' | count_lines)
            # needs-restarting exits with 1 when a restart is needed; it's a plugin, so check it exists first
            if dnf needs-restarting --help >/dev/null 2>&1
            then
                dnf needs-restarting -r >/dev/null 2>&1
                [ $? -eq 1 ] && Restart="yes"
            fi
            ;;
        arch)
            local AurCount=0

            # checkupdates comes with pacman-contrib
            if Has checkupdates
            then
                Count=$(timeout "$CheckTimeout" checkupdates 2>/dev/null | count_lines)
            fi

            # AUR packages, if an AUR helper is installed
            if Has paru
            then
                AurCount=$(timeout "$CheckTimeout" paru -Qua 2>/dev/null | count_lines)
            elif Has yay
            then
                AurCount=$(timeout "$CheckTimeout" yay -Qua 2>/dev/null | count_lines)
            fi

            if [ "$AurCount" -gt 0 ]
            then
                [ "$Count" -lt 0 ] && Count=0
                Count=$(( Count + AurCount ))
            fi

            # Arch removes the running kernel's modules when it updates the kernel
            [ -d "/usr/lib/modules/$(uname -r)" ] || Restart="yes"
            ;;
        debian)
            # Reads the package lists from the last refresh (Discover and unattended upgrades keep them fresh)
            Count=$(apt list --upgradable 2>/dev/null | grep -c 'upgradable from' || true)
            [ -f /var/run/reboot-required ] && Restart="yes"
            ;;
        opensuse)
            Count=$(timeout "$CheckTimeout" zypper --non-interactive --no-refresh list-updates 2>/dev/null | grep -c '^v ' || true)
            zypper needs-rebooting >/dev/null 2>&1
            [ $? -eq 102 ] && Restart="yes"
            ;;
    esac

    echo "$Restart ${Count:--1}"
}

# The count_flatpaks function counts Flatpak updates across the system and user installations
count_flatpaks()
{
    if ! Has flatpak
    then
        echo -1
        return
    fi

    {
        timeout 120 flatpak remote-ls --system --updates --columns=application 2>/dev/null
        timeout 120 flatpak remote-ls --user --updates --columns=application 2>/dev/null
    } | count_lines
}

# Section: Main loop
sleep "$FirstCheckDelay"

while true
do
    echo "$(check_system) $(count_flatpaks)"
    sleep "$CheckInterval"
done
