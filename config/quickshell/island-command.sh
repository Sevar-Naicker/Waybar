# This file contains the "island" terminal command for the dynamic island
# Usage: island <any command>   e.g.  island rpm-ostree upgrade
# Runs the command as normal, then pings the island with how it went and how long it took

# The island function runs a command, then tells the dynamic island it finished
island()
{
    local StartTime=$SECONDS

    "$@"
    local ExitCode=$?

    qs ipc call island commandDone "$*" "$ExitCode" "$(( SECONDS - StartTime ))" >/dev/null 2>&1

    return $ExitCode
}
