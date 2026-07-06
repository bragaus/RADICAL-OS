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


# Store lines: "<app_id>\t<count>\t<last>". `last` is a monotonic launch sequence
# (bigger = opened more recently) so the carousel can put the LAST-OPENED app first,
# then fall back to most-used, then alphabetical. Old 2-field lines parse as last=0.
def load_store():
    store = {}
    try:
        for line in CACHE.read_text(encoding="utf-8").splitlines():
            parts = line.split("\t")
            if len(parts) >= 2:
                aid = parts[0]
                try:
                    count = int(parts[1])
                except ValueError:
                    count = 0
                try:
                    last = int(parts[2]) if len(parts) >= 3 else 0
                except ValueError:
                    last = 0
                store[aid] = {"count": count, "last": last}
    except FileNotFoundError:
        pass
    return store


def save_store(store):
    CACHE.parent.mkdir(parents=True, exist_ok=True)
    fd, tmp = tempfile.mkstemp(dir=str(CACHE.parent), prefix=".app_usage.")
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as f:
            for aid, rec in store.items():
                f.write(f"{aid}\t{rec['count']}\t{rec['last']}\n")
        os.replace(tmp, str(CACHE))  # atomic; no half-written file (cf. rules.txt lesson)
    except Exception:
        try:
            os.unlink(tmp)
        except OSError:
            pass
        raise


def bump_app(aid):
    store = load_store()
    nxt = max((r["last"] for r in store.values()), default=0) + 1
    rec = store.get(aid, {"count": 0, "last": 0})
    store[aid] = {"count": rec["count"] + 1, "last": nxt}
    save_store(store)


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
    store = load_store()
    apps = scan()
    # LAST-OPENED first (-last, MRU), then most-used (-count), ties alphabetical.
    def key(a):
        r = store.get(a["app_id"], {"count": 0, "last": 0})
        return (-r["last"], -r["count"], a["name"].lower())
    apps.sort(key=key)
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
            bump_app(sys.argv[2])

    elif cmd == "launch-index":
        if len(sys.argv) > 2:
            try:
                i = int(sys.argv[2])
            except ValueError:
                return
            apps = sorted_apps()
            if 0 <= i < len(apps):
                a = apps[i]
                bump_app(a["app_id"])
                subprocess.Popen(
                    ["gtk-launch", a["app_id"]],
                    stdout=subprocess.DEVNULL,
                    stderr=subprocess.DEVNULL,
                    start_new_session=True,
                )


if __name__ == "__main__":
    main()
