#!/usr/bin/env python3
# -----------------------------------------------------------------------------
# app_usage.py — shared app list + launch-frequency store for the AwesomeWM
# config. Both the carousel widget (src/widgets/app_launcher.lua) and the rofi
# launcher (src/scripts/app_menu.sh) call this so they share ONE ordering:
# most-used app first, least-used last.
#
# Counts live in $XDG_CACHE_HOME/awesome_app_usage.tsv (lines: "<app_id>\t<n>").
#
# Subcommands:
#   list-tsv            -> "name\tapp_id\texec\ticon" per app, usage-sorted (carousel)
#   list-rofi           -> rofi dmenu rows w/ icon metadata, usage-sorted
#   bump <app_id>       -> increment that app's launch count
#   launch-index <i>    -> bump + gtk-launch the i-th app of the current sort (rofi)
# -----------------------------------------------------------------------------
import sys
import os
import configparser
import subprocess
import tempfile
from pathlib import Path

CACHE = Path(os.environ.get("XDG_CACHE_HOME", str(Path.home() / ".cache"))) / "awesome_app_usage.tsv"
APP_DIRS = [Path("/usr/share/applications"), Path.home() / ".local/share/applications"]


def load_counts():
    counts = {}
    try:
        for line in CACHE.read_text(encoding="utf-8").splitlines():
            if "\t" in line:
                aid, c = line.rsplit("\t", 1)
                try:
                    counts[aid] = int(c)
                except ValueError:
                    pass
    except FileNotFoundError:
        pass
    return counts


def save_counts(counts):
    CACHE.parent.mkdir(parents=True, exist_ok=True)
    fd, tmp = tempfile.mkstemp(dir=str(CACHE.parent), prefix=".app_usage.")
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as f:
            for aid, c in counts.items():
                f.write(f"{aid}\t{c}\n")
        os.replace(tmp, str(CACHE))  # atomic; no half-written file (cf. rules.txt lesson)
    except Exception:
        try:
            os.unlink(tmp)
        except OSError:
            pass
        raise


def scan():
    entries, seen = [], set()
    for root in APP_DIRS:
        if not root.exists():
            continue
        for desktop_file in sorted(root.glob("*.desktop")):
            app_id = desktop_file.name
            if app_id in seen:
                continue
            seen.add(app_id)
            parser = configparser.ConfigParser(interpolation=None, strict=False)
            try:
                parser.read(desktop_file, encoding="utf-8")
            except Exception:
                continue
            if "Desktop Entry" not in parser:
                continue
            e = parser["Desktop Entry"]
            if e.get("Type") != "Application":
                continue
            if e.get("NoDisplay", "false").lower() == "true":
                continue
            if e.get("Hidden", "false").lower() == "true":
                continue
            name = e.get("Name", "").strip()
            exec_line = e.get("Exec", "").strip()
            icon = e.get("Icon", "").strip()
            if not name or not exec_line:
                continue
            entries.append({"name": name, "app_id": app_id, "exec": exec_line, "icon": icon})
    return entries


def sorted_apps():
    counts = load_counts()
    apps = scan()
    # most-used first (-count), ties broken alphabetically.
    apps.sort(key=lambda a: (-counts.get(a["app_id"], 0), a["name"].lower()))
    return apps


def clean(v):
    return v.replace("\t", " ").replace("\n", " ")


def main():
    cmd = sys.argv[1] if len(sys.argv) > 1 else "list-tsv"

    if cmd == "list-tsv":
        for a in sorted_apps():
            print(f"{clean(a['name'])}\t{a['app_id']}\t{clean(a['exec'])}\t{clean(a['icon'])}")

    elif cmd == "list-rofi":
        for a in sorted_apps():
            row = clean(a["name"])
            if a["icon"]:
                row += f"\0icon\x1f{a['icon']}"
            sys.stdout.write(row + "\n")

    elif cmd == "bump":
        if len(sys.argv) > 2:
            aid = sys.argv[2]
            counts = load_counts()
            counts[aid] = counts.get(aid, 0) + 1
            save_counts(counts)

    elif cmd == "launch-index":
        if len(sys.argv) > 2:
            try:
                i = int(sys.argv[2])
            except ValueError:
                return
            apps = sorted_apps()
            if 0 <= i < len(apps):
                a = apps[i]
                counts = load_counts()
                counts[a["app_id"]] = counts.get(a["app_id"], 0) + 1
                save_counts(counts)
                subprocess.Popen(
                    ["gtk-launch", a["app_id"]],
                    stdout=subprocess.DEVNULL,
                    stderr=subprocess.DEVNULL,
                    start_new_session=True,
                )


if __name__ == "__main__":
    main()
