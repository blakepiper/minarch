#!/usr/bin/env python3
"""Optional real X11 integration tests in a fresh, isolated Xvfb display."""
import os
from pathlib import Path
import shutil
import signal
import struct
import subprocess
import tempfile
import time
import zlib

ROOT = Path(__file__).resolve().parents[1]
required = ["Xvfb", "oxwm", "st", "xdotool", "maim", "slop", "xclip", "clipmenud", "clipmenu"]
for cmd in required:
    if not shutil.which(cmd):
        raise SystemExit(f"Missing optional X11 test tool: {cmd}")

with tempfile.TemporaryDirectory(prefix="minarch-x11-") as temp:
    base = Path(temp)
    log = (base / "x11.log").open("w+")
    processes = []
    try:
        server = subprocess.Popen(["Xvfb", "-displayfd", "1", "-screen", "0", "1280x800x24", "-nolisten", "tcp"],
                                  stdout=subprocess.PIPE, stderr=log, text=True, start_new_session=True)
        processes.append(server)
        display = server.stdout.readline().strip()
        assert display.isdigit(), "Xvfb did not start"
        commands = base / "bin"
        commands.mkdir()
        (base / "runtime").mkdir(mode=0o700)
        env = dict(os.environ, DISPLAY=":" + display, HOME=temp, XDG_CONFIG_HOME=temp + "/config",
                   XDG_RUNTIME_DIR=temp + "/runtime", CM_DIR=temp + "/clipboard", CM_SELECTIONS="clipboard",
                   CM_OWN_CLIPBOARD="0", CM_MAX_CLIPS="100", PATH=str(commands) + ":" + str(ROOT / "lib/clipmenu-text-probe") + ":" + str(ROOT / "bin") + ":" + os.environ["PATH"])
        env.pop("MINARCH_BATTERY", None)

        def run(args, **kwargs):
            if args[0] == "xclip" and "-o" not in args:
                return subprocess.run(args, env=env, stdout=log, stderr=log, check=True, timeout=15, **kwargs)
            return subprocess.run(args, env=env, stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=True, timeout=15, **kwargs)

        def start(args):
            child = subprocess.Popen(args, env=env, stdout=log, stderr=log, start_new_session=True)
            processes.append(child)
            return child

        def clipboard():
            return run(["xclip", "-selection", "clipboard", "-t", "image/png", "-o"]).stdout

        wm = start(["oxwm", "--config", str(ROOT / "config/oxwm/config.lua")])
        time.sleep(.4)
        assert wm.poll() is None, "OXWM exited at startup"
        start(["st", "-e", "sleep", "90"])
        time.sleep(.4)
        # A real full-screen capture, then rectangular selection and cancellation.
        result = run([str(ROOT / "bin/screenshot-region"), "--full"], text=True)
        assert result.stdout.strip(), result.stderr
        image = Path(result.stdout.strip())
        assert image.read_bytes() == clipboard()
        capture = subprocess.Popen([str(ROOT / "bin/screenshot-region")], env=env, stdout=subprocess.PIPE, stderr=log, text=True)
        processes.append(capture)
        time.sleep(.5)
        run(["xdotool", "mousemove", "100", "100", "sleep", "0.2", "mousedown", "1", "sleep", "0.2", "mousemove", "420", "300", "sleep", "0.2", "mouseup", "1"])
        out, _ = capture.communicate(timeout=15)
        assert capture.returncode == 0 and out.strip(), "Region selection failed"
        region = Path(out.strip())
        assert region.read_bytes() == clipboard()
        # PNG's IHDR stores width/height in big endian after the first 16 bytes.
        assert int.from_bytes(region.read_bytes()[16:20], "big") < 1280
        before = clipboard()
        cancel = subprocess.Popen([str(ROOT / "bin/screenshot-region")], env=env, stdout=subprocess.PIPE, stderr=log)
        processes.append(cancel)
        time.sleep(.5)
        run(["xdotool", "key", "Escape"])
        cancel.communicate(timeout=15)
        assert clipboard() == before, "Cancel changed the clipboard"
        assert len(list((base / "Pictures/Screenshots").glob("*.png"))) == 2
        focused = run([str(ROOT / "bin/screenshot-region"), "--window"], text=True)
        assert Path(focused.stdout.strip()).read_bytes() == clipboard()
        print("PASS: real full/region/window PNG save equals X clipboard; Escape preserves clipboard")

        # Event-driven clipmenu integration; dmenu's selection is scripted here.
        dmenu = commands / "dmenu"
        dmenu.write_text("#!/bin/sh\ncat | head -1\n")
        dmenu.chmod(0o755)
        history = start(["clipmenud"])
        time.sleep(.3)
        run(["xclip", "-selection", "clipboard"], input=b"minarch history example")
        time.sleep(.4)
        run([str(ROOT / "bin/clipboard-history")])
        restored = run(["xclip", "-selection", "clipboard", "-o"]).stdout
        assert restored == b"minarch history example", restored
        dmenu.write_text("#!/bin/sh\ncat >/dev/null\nexit 1\n")
        subprocess.run([str(ROOT / "bin/clipboard-history")], env=env, stdout=log, stderr=log, timeout=5)
        assert run(["xclip", "-selection", "clipboard", "-o"]).stdout == restored
        print("PASS: clipmenu restores selected text; cancelling keeps clipboard")

        # Reproduce the old >1 MiB image/xsel failure with the text watcher
        # active. Random pixels keep the PNG larger than xclip's trouble size.
        def chunk(kind, payload):
            return struct.pack(">I", len(payload)) + kind + payload + struct.pack(">I", zlib.crc32(kind + payload))

        width, height = 800, 600
        pixels = b"".join(b"\0" + os.urandom(width * 3) for _ in range(height))
        large_png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0))
        large_png += chunk(b"IDAT", zlib.compress(pixels, 1)) + chunk(b"IEND", b"")
        assert len(large_png) > 1_000_000
        png_path = base / "large.png"
        png_path.write_bytes(large_png)
        run(["xclip", "-selection", "clipboard", "-t", "image/png", "-i", str(png_path)])
        time.sleep(.5)
        assert clipboard() == large_png, "Text history interrupted the large image owner"
        print("PASS: image-only clipboard survives clipmenu's text probe")

        # Layout bindings and the menu's exact quit bridge on the nested WM.
        run(["xdotool", "key", "--clearmodifiers", "super+c"])
        run(["xdotool", "key", "--clearmodifiers", "super+r"])
        time.sleep(.2)
        assert wm.poll() is None
        run(["xdotool", "key", "--clearmodifiers", "super+shift+q"])
        wm.wait(timeout=5)
        assert wm.returncode == 0
        print("PASS: OXWM starts, manages st, switches layouts, and quits through its native action")
    except Exception:
        log.flush()
        log.seek(0)
        print(log.read()[-8000:])
        raise
    finally:
        for process in reversed(processes):
            if process.poll() is None:
                # Only our isolated test children/process groups.
                if process.pid == os.getpgid(process.pid):
                    os.killpg(process.pid, signal.SIGTERM)
                else:
                    process.terminate()
                try:
                    process.wait(timeout=3)
                except subprocess.TimeoutExpired:
                    process.kill()
                    process.wait()
        log.close()
