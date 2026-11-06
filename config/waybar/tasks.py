#!/usr/bin/env python3
# This file contains the "today's task" module for the Shrine Waybar
# Shows one unfinished task at a time from a plain text list (keep it in a synced folder like Nextcloud to edit it from your phone)
#   no arguments  print the pill
#   --next        scroll to the next task
#   --previous    scroll to the previous task
#   --done        mark the task that's showing as done (it stays in the file, marked "x ")
#   --edit        open the list in Kate

import html
import json
import os
import shutil
import subprocess
import sys
from pathlib import Path


# The read_setting function asks Shrine Waybar's settings.sh for one setting, with a fallback if it can't
def read_setting(Key, Fallback):
    Settings = Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config")) / "shrine-waybar" / "settings.sh"

    try:
        Value = subprocess.run(["bash", str(Settings), "--get", Key], capture_output=True, text=True, timeout=5).stdout.strip()
    except (OSError, subprocess.SubprocessError):
        Value = ""

    return Path(Value) if Value else Fallback


# Section: Settings
# One task per line. Lines starting with "x " are done, lines starting with "#" are ignored
# The list's location comes from shrine.conf (SHRINE_TASKS_FILE)
TasksFile = read_setting("SHRINE_TASKS_FILE", Path.home() / "Tasks.txt")
StateFile = Path.home() / ".local" / "state" / "shrine-waybar" / "tasks.json"
MaxPillLength = 36
TooltipTasks = 8

# Section: Icons and colours
IconTask = ""
IconAllDone = ""
CounterColour = "#86979A"


# The read_lines function returns the file's lines, creating a starter list if it doesn't exist yet
def read_lines():
    if not TasksFile.exists():
        TasksFile.parent.mkdir(parents=True, exist_ok=True)
        TasksFile.write_text("# One task per line. Scroll the pill to pick a task, click to finish it, right-click to edit.\n"
                             "# Finished tasks are marked with \"x \" so they can be undone.\n")

    return TasksFile.read_text(encoding="utf-8").splitlines()


# The is_open function says whether a line is an unfinished task
def is_open(Line):
    Stripped = Line.strip()
    return Stripped != "" and not Stripped.startswith("#") and not Stripped.lower().startswith("x ")


# The open_tasks function lists the unfinished tasks as (line number, text) pairs
def open_tasks(Lines):
    return [(Index, Line.strip()) for Index, Line in enumerate(Lines) if is_open(Line)]


# The load_index function reads which task is showing, kept in range of the current list
def load_index(TaskCount):
    try:
        Index = int(json.loads(StateFile.read_text()).get("index", 0))
    except (OSError, ValueError, AttributeError):
        Index = 0

    return min(max(Index, 0), max(TaskCount - 1, 0))


# The save_index function remembers which task is showing
def save_index(Index):
    StateFile.parent.mkdir(parents=True, exist_ok=True)
    StateFile.write_text(json.dumps({"index": Index}))


# The scroll function moves to the next or previous task, wrapping round at the ends
def scroll(Step):
    Tasks = open_tasks(read_lines())

    if Tasks:
        save_index((load_index(len(Tasks)) + Step) % len(Tasks))


# The mark_done function marks the task that's showing as done
def mark_done():
    Lines = read_lines()
    Tasks = open_tasks(Lines)

    if not Tasks:
        return

    Index = load_index(len(Tasks))
    LineNumber, Text = Tasks[Index]
    Lines[LineNumber] = "x " + Text
    TasksFile.write_text("\n".join(Lines) + "\n", encoding="utf-8")

    # Stay at the same position, which now holds the next task
    save_index(min(Index, max(len(Tasks) - 2, 0)))


# The open_editor function opens the list in Kate, or the default text editor if Kate isn't there
def open_editor():
    read_lines()
    Editor = ["kate", str(TasksFile)] if shutil.which("kate") else ["xdg-open", str(TasksFile)]
    subprocess.Popen(Editor, start_new_session=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


# The shorten function trims a task to fit the pill
def shorten(Text):
    return Text if len(Text) <= MaxPillLength else Text[:MaxPillLength - 1].rstrip() + "…"


# The status function builds the pill: the selected task with its position, or an all-done message
def status():
    Tasks = open_tasks(read_lines())

    if not Tasks:
        return {
            "text": f"{IconAllDone}  All done",
            "tooltip": "No tasks left\nRight-click to add some",
            "class": "empty",
        }

    Index = load_index(len(Tasks))
    Text = f"{IconTask}  {html.escape(shorten(Tasks[Index][1]))}"

    # Only show the position when there's more than one task to scroll through
    if len(Tasks) > 1:
        Text += f"  <span color='{CounterColour}'>{Index + 1}/{len(Tasks)}</span>"

    # The tooltip lists tasks around the selected one, marked with ▸
    Start = max(0, min(Index - TooltipTasks // 2, len(Tasks) - TooltipTasks))
    Shown = Tasks[Start:Start + TooltipTasks]
    Rows = [f"{'▸' if Start + Offset == Index else '  '} {html.escape(Task)}" for Offset, (_, Task) in enumerate(Shown)]
    Left = f"{len(Tasks)} task{'s' if len(Tasks) != 1 else ''} left"

    return {
        "text": Text,
        "tooltip": f"{Left}\n" + "\n".join(Rows) + "\n\nScroll: pick · Click: done · Right-click: edit",
        "class": "task",
    }


# The main function runs the requested action, then prints the pill
def main():
    if "--next" in sys.argv:
        scroll(1)

    if "--previous" in sys.argv:
        scroll(-1)

    if "--done" in sys.argv:
        mark_done()

    if "--edit" in sys.argv:
        open_editor()

    print(json.dumps(status(), ensure_ascii=False))
    sys.stdout.flush()


if __name__ == "__main__":
    main()
