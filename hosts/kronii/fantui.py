"""fantui: per-channel fan control for kronii, on top of fanctl.

Targets are saved to /var/lib/fanctl/levels.json ({"pwm1": "curve", "pwm2":
"auto", "pwm3": 60, ...}) and applied by restarting fanctl, whose config is
generated from that file. "curve" (the default for unlisted channels) follows
the temperature curve in fanctl-config.sh, a number is a fixed percentage,
and "auto" hands the channel back to the BIOS curve.
"""

import curses
import glob
import json
import os
import shutil
import subprocess
import sys
import time

STATE = "/var/lib/fanctl"
LEVELS = STATE + "/levels.json"
LABELS = STATE + "/labels.json"
# Only for testing against a fake sysfs tree; also skips the root re-exec.
SYSFS = os.environ.get("FANTUI_SYSFS", "/sys")
# The V100 is passive and lives on case airflow, so no channel goes lower.
MIN_PCT = 20
STEP = 5
REFRESH = 2.0
# selection marker, channel, label, target, current duty, rpm
ROW = "%s %-5s %-14s %6s %4s %6s"


def read(path):
    try:
        with open(path) as f:
            return f.read().strip()
    except OSError:
        return None


def hwmons(prefix):
    for h in sorted(glob.glob(SYSFS + "/class/hwmon/hwmon*")):
        if (read(h + "/name") or "").startswith(prefix):
            yield h


def labelled_temp(h, label):
    for lp in glob.glob(h + "/temp*_label"):
        if read(lp) == label:
            v = read(lp[:-len("_label")] + "_input")
            return int(v) / 1000 if v else None
    return None


def gpu_temp():
    if not shutil.which("nvidia-smi"):
        return None
    try:
        out = subprocess.run(
            ["nvidia-smi", "--query-gpu=temperature.gpu", "--format=csv,noheader,nounits"],
            capture_output=True, text=True, timeout=3,
        ).stdout.split()
        return float(out[0]) if out else None
    except (OSError, subprocess.SubprocessError, ValueError):
        return None


def temps():
    def first(prefix, label):
        return next((t for h in hwmons(prefix) if (t := labelled_temp(h, label)) is not None), None)

    nvme = [t for h in hwmons("nvme") if (t := labelled_temp(h, "Composite")) is not None]
    return [
        ("CPU", first("k10temp", "Tctl")),
        ("V100", gpu_temp()),
        ("B60", first("xe", "pkg")),
        ("NVMe", max(nvme) if nvme else None),
        ("Board", first("nct6", "SYSTIN")),
    ]


def channels(chip):
    pwms = [p for p in glob.glob(chip + "/pwm*") if os.path.basename(p)[3:].isdigit()]
    out = []
    for p in sorted(pwms, key=lambda p: int(os.path.basename(p)[3:])):
        n = os.path.basename(p)
        raw = read(p)
        rpm = read(chip + "/fan" + n[3:] + "_input")
        out.append({
            "name": n,
            "now": round(int(raw) * 100 / 255) if raw else None,
            "rpm": int(rpm) if rpm else None,
        })
    return out


def load(path):
    try:
        with open(path) as f:
            data = json.load(f)
        return data if isinstance(data, dict) else {}
    except (OSError, ValueError):
        return {}


def sane(level):
    # Same rules as fanctl-config.sh: anything else means the curve.
    if level in ("auto", "curve"):
        return level
    if isinstance(level, (int, float)) and not isinstance(level, bool):
        return max(MIN_PCT, min(100, int(level)))
    return "curve"


def save(path, data):
    os.makedirs(STATE, exist_ok=True)
    tmp = path + ".tmp"
    with open(tmp, "w") as f:
        json.dump(data, f, indent=2, sort_keys=True)
        f.write("\n")
    os.replace(tmp, path)


def fanctl_state():
    try:
        return subprocess.run(
            ["systemctl", "is-active", "fanctl"], capture_output=True, text=True, timeout=3,
        ).stdout.strip() or "unknown"
    except (OSError, subprocess.SubprocessError):
        return "unknown"


def apply(levels, labels):
    save(LEVELS, levels)
    save(LABELS, labels)
    r = subprocess.run(["systemctl", "restart", "fanctl"], capture_output=True, text=True)
    if r.returncode != 0:
        return "restart failed: " + (r.stderr.strip() or "see journalctl -u fanctl")
    return "applied"


def temp_attr(t):
    if t is None:
        return curses.A_DIM
    if t >= 80:
        return curses.color_pair(1) | curses.A_BOLD
    if t >= 65:
        return curses.color_pair(2)
    return curses.color_pair(3)


def target_text(level):
    if level == "auto":
        return "BIOS"
    if level == "curve":
        return "CURVE"
    return "%d%%" % level


def bar(level, width):
    if level == "curve":
        return "~" * width
    if level == "auto":
        return "·" * width
    filled = round(level * width / 100)
    return "█" * filled + "░" * (width - filled)


def prompt(scr, y, text):
    scr.move(y, 0)
    scr.clrtoeol()
    scr.addstr(y, 1, text)
    curses.echo()
    curses.curs_set(1)
    scr.timeout(-1)
    try:
        return scr.getstr(y, 1 + len(text), 24).decode(errors="replace").strip()
    finally:
        curses.noecho()
        curses.curs_set(0)


def main(scr):
    curses.curs_set(0)
    curses.use_default_colors()
    curses.init_pair(1, curses.COLOR_RED, -1)
    curses.init_pair(2, curses.COLOR_YELLOW, -1)
    curses.init_pair(3, curses.COLOR_GREEN, -1)
    curses.init_pair(4, curses.COLOR_CYAN, -1)

    chip = next(hwmons("nct6"), None)
    if chip is None:
        raise SystemExit("fantui: no nct6775 hwmon found; is the nct6775 module loaded?")
    saved = load(LEVELS)
    labels = load(LABELS)
    names = [c["name"] for c in channels(chip)]
    levels = {n: sane(saved.get(n, "curve")) for n in names}
    applied = dict(levels)
    sel = 0
    msg = ""
    confirm_quit = False
    sensors, chans, state, last = [], [], "", 0.0

    while True:
        if time.monotonic() - last >= REFRESH:
            sensors, chans, state = temps(), channels(chip), fanctl_state()
            last = time.monotonic()
        dirty = levels != applied

        scr.erase()
        h, w = scr.getmaxyx()
        scr.addstr(0, 1, "kronii fans", curses.A_BOLD)
        status = "fanctl: " + state + ("   · unapplied changes" if dirty else "")
        scr.addstr(0, max(12, w - len(status) - 2), status[:w - 13],
                   curses.color_pair(2) if dirty else curses.A_DIM)
        x = 1
        for name, t in sensors:
            if x >= w - 14:
                break
            scr.addstr(2, x, name + " ")
            scr.addstr(2, x + len(name) + 1, "--" if t is None else "%d°C" % t, temp_attr(t))
            x += len(name) + 9

        scr.addstr(4, 1, (ROW % (" ", "CH", "NAME", "TARGET", "NOW", "RPM"))[:w - 2], curses.A_UNDERLINE)
        bar_w = max(0, min(20, w - 49))
        for i, c in enumerate(chans):
            y = 5 + i
            if y >= h - 3:
                break
            n = c["name"]
            row = ROW % (
                ">" if i == sel else " ",
                n,
                labels.get(n, "-")[:14],
                target_text(levels[n]),
                "--" if c["now"] is None else "%d%%" % c["now"],
                "--" if c["rpm"] is None else c["rpm"],
            )
            attr = curses.A_REVERSE if i == sel else curses.A_NORMAL
            scr.addstr(y, 1, row[:w - 2], attr)
            if bar_w:
                scr.addstr(y, 48, bar(levels[n], bar_w), curses.color_pair(4))

        keys = ("↑↓ select  ←→ ±%d%%  1-9 10-90%%  0 100%%  c curve  b BIOS  A all=this  F all 100%%"
                "  n name  w apply  q quit") % STEP
        scr.addstr(h - 2, 1, keys[:w - 2], curses.A_DIM)
        if msg:
            scr.addstr(h - 1, 1, msg[:w - 2], curses.A_BOLD)
        scr.refresh()

        scr.timeout(500)
        k = scr.getch()
        if k == -1:
            continue
        msg = ""
        if k != ord("q"):
            confirm_quit = False
        n = names[sel]
        cur = 100 if levels[n] in ("auto", "curve") else levels[n]

        if k in (curses.KEY_UP, ord("k")):
            sel = (sel - 1) % len(names)
        elif k in (curses.KEY_DOWN, ord("j")):
            sel = (sel + 1) % len(names)
        elif k in (curses.KEY_LEFT, ord("h")):
            levels[n] = max(MIN_PCT, cur - STEP)
            if cur - STEP < MIN_PCT:
                msg = "minimum is %d%% (the V100 has no fan of its own)" % MIN_PCT
        elif k in (curses.KEY_RIGHT, ord("l")):
            levels[n] = min(100, cur + STEP)
        elif ord("1") <= k <= ord("9"):
            want = (k - ord("0")) * 10
            levels[n] = max(MIN_PCT, want)
            if want < MIN_PCT:
                msg = "minimum is %d%% (the V100 has no fan of its own)" % MIN_PCT
        elif k == ord("0"):
            levels[n] = 100
        elif k == ord("b"):
            levels[n] = "curve" if levels[n] == "auto" else "auto"
        elif k == ord("c"):
            levels[n] = "curve"
        elif k == ord("A"):
            for m in names:
                levels[m] = levels[n]
        elif k == ord("F"):
            for m in names:
                levels[m] = 100
        elif k == ord("n"):
            new = prompt(scr, h - 1, "name for %s (empty clears): " % n)
            if new:
                labels[n] = new
            else:
                labels.pop(n, None)
            save(LABELS, labels)
        elif k in (ord("w"), 10, 13, curses.KEY_ENTER):
            msg = apply(levels, labels)
            applied = dict(levels)
            last = 0.0
        elif k == ord("q"):
            if dirty and not confirm_quit:
                msg = "unapplied changes: w to apply, q again to discard"
                confirm_quit = True
            else:
                return


def run():
    if os.geteuid() != 0 and "FANTUI_SYSFS" not in os.environ:
        # Applying writes /var/lib/fanctl and restarts fanctl.
        for tool in ("run0", "sudo"):
            if shutil.which(tool):
                os.execvp(tool, [tool, sys.executable] + sys.argv)
        raise SystemExit("fantui: needs root (no run0 or sudo found)")
    curses.wrapper(main)


if __name__ == "__main__":
    run()
