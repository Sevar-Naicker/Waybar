#!/bin/bash
# This file contains the updates feed for the dynamic island
# Prints one line per check: <staged> <flatpak count>
#   staged: "yes" if Bazzite has already downloaded a system update that applies on restart, otherwise "no"
#   flatpak count: Flatpak apps and runtimes with updates waiting
# Usage: updates.sh [seconds before the first check]. Checks again every hour after that.

# Section: Settings
FirstCheckDelay=${1:-30}
CheckInterval=3600

# The check_staged function says whether a downloaded system update is waiting for a restart
# Reading rpm-ostree's status needs no password, unlike a live update check
check_staged()
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

# The count_flatpaks function counts Flatpak updates across the system and user installations
count_flatpaks()
{
    {
        timeout 120 flatpak remote-ls --system --updates --columns=application 2>/dev/null
        timeout 120 flatpak remote-ls --user --updates --columns=application 2>/dev/null
    } | grep -c .
}

# Section: Main loop
sleep "$FirstCheckDelay"

while true
do
    echo "$(check_staged) $(count_flatpaks)"
    sleep "$CheckInterval"
done
