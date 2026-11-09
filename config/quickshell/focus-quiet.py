#!/usr/bin/env python3
# This file contains the focus timer's Do Not Disturb
# It asks the notification server to hold notifications back, then waits; stopping it (the timer does) lets them through again

# Section: Imports
import signal
import sys

try:
    from gi.repository import Gio, GLib
except ImportError:
    sys.exit("focus-quiet: PyGObject (python3-gobject) isn't installed, so notifications can't be held back")

# Section: Settings
Service = "org.freedesktop.Notifications"
ObjectPath = "/org/freedesktop/Notifications"


# The Call function calls one method on the notification server
def Call(Bus, Method, Arguments, Reply):
    return Bus.call_sync(Service, ObjectPath, Service, Method, Arguments, Reply, Gio.DBusCallFlags.NONE, 3000, None)


# The Main function holds notifications back until it's told to stop
def Main():
    Bus = Gio.bus_get_sync(Gio.BusType.SESSION, None)

    try:
        Cookie = Call(Bus, "Inhibit", GLib.Variant("(ssa{sv})", ("shrine-focus", "Focus time", {})), GLib.VariantType("(u)")).unpack()[0]
    except GLib.Error as Problem:
        sys.exit("focus-quiet: the notification server didn't allow it (" + Problem.message + ")")

    Loop = GLib.MainLoop()

    for Signal in (signal.SIGTERM, signal.SIGINT, signal.SIGHUP):
        GLib.unix_signal_add(GLib.PRIORITY_DEFAULT, Signal, Loop.quit)

    Loop.run()

    # Hand it back straight away (KDE would also do this once the process is gone)
    try:
        Call(Bus, "UnInhibit", GLib.Variant("(u)", (Cookie,)), None)
    except GLib.Error:
        pass


Main()
