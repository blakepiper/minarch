#!/usr/bin/env python3
"""Isolated integration checks; never installs packages or touches the live home."""
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


def run(args, **kwargs):
    return subprocess.run(args, text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=True, **kwargs)


class Sandbox(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix="minarch-test-")
        self.addCleanup(self.tmp.cleanup)
        self.base = Path(self.tmp.name)
        self.home = self.base / "home"
        self.home.mkdir()
        self.commands = self.base / "bin"
        self.commands.mkdir()
        self.env = dict(os.environ, HOME=str(self.home), XDG_CONFIG_HOME=str(self.home / ".config"),
                        XDG_STATE_HOME=str(self.home / ".local/state"), XDG_RUNTIME_DIR=str(self.base),
                        PATH=str(self.commands) + ":" + os.environ["PATH"])
        self.env.pop("TMUX", None)
        self.env.pop("NVIM_APPNAME", None)

    def command(self, name, body):
        path = self.commands / name
        path.write_text("#!/usr/bin/env bash\nset -euo pipefail\n" + body)
        path.chmod(0o755)


class AurManifestInput(Sandbox):
    def test_child_prompts_cannot_consume_manifest_entries(self):
        repo = self.base / "repo"
        (repo / "install").mkdir(parents=True)
        (repo / "install/packages-aur").write_text(
            "# reviewed recipes\n\nfirst-package recipe-a source-a\n"
            "second-package recipe-b - # inline comment\n")
        (repo / "config/st").mkdir(parents=True)
        for name in ["PKGBUILD", "config.h"]:
            (repo / "config/st" / name).write_text("test fixture\n")
        calls = self.base / "calls"
        self.env["TEST_CALLS"] = str(calls)
        self.command("build-prompt", '''
read -r answer
printf '%s|%s|%s|%s\\n' "$1" "$2" "${3:--}" "$answer" >> "$TEST_CALLS"
''')
        run(["bash", "-euo", "pipefail", "-c", '''
source "$1/install/common.sh"
source "$1/install/packages.sh"
ROOT=$2
build_package() { build-prompt "$@"; }
install_local_packages
''', "test", str(ROOT), str(repo)], env=self.env,
            input="first-answer\nsecond-answer\nst-answer\n")
        rows = calls.read_text().splitlines()
        self.assertEqual(len(rows), 3)
        self.assertEqual(rows[:2], ["first-package|recipe-a|source-a|first-answer",
                                    "second-package|recipe-b|-|second-answer"])
        name, identity, upstream, answer = rows[2].split("|")
        self.assertEqual((name, upstream, answer), ("st-minarch", "-", "st-answer"))
        self.assertTrue(identity)


class ConfigSafety(Sandbox):
    def install(self, source, target, replace=False):
        return run(["bash", "-c", 'source "$1"; install_config "$2" "$3"', "test",
                    str(ROOT / "install/common.sh"), str(source), str(target)],
                   env=dict(self.env, REPLACE_CONFIG=str(replace).lower()))

    def test_copy_preserve_backup_and_rerun(self):
        source = self.base / "source"
        source.mkdir()
        (source / ".hidden").write_text("dotfile")
        (source / "init.lua").write_text("upstream")
        target = self.home / "config with spaces/nvim"
        self.install(source, target)
        self.assertEqual((target / ".hidden").read_text(), "dotfile")
        (target / "init.lua").write_text("user")
        self.install(source, target)
        self.assertEqual((target / "init.lua").read_text(), "user")
        self.install(source, target, replace=True)
        backups = list(target.parent.glob("nvim.backup.*/original/init.lua"))
        self.assertEqual(len(backups), 1)
        self.assertEqual(backups[0].read_text(), "user")
        self.install(source, target, replace=True)
        self.assertEqual(len(list(target.parent.glob("nvim.backup.*"))), 1)
        self.assertFalse(list(target.parent.glob(".minarch-stage.*")))

    def test_dangling_symlink_and_file(self):
        source = self.base / "source"
        source.write_text("new")
        target = self.home / "config"
        target.symlink_to(self.home / "absent")
        self.install(source, target)
        self.assertTrue(target.is_symlink())
        self.install(source, target, replace=True)
        backup = next(self.home.glob("config.backup.*/original"))
        self.assertTrue(backup.is_symlink())
        self.assertEqual(target.read_text(), "new")

    def test_complete_user_seed(self):
        run([str(ROOT / "install.sh"), "--config-only"], env=self.env)
        run([str(ROOT / "install.sh"), "--config-only"], env=self.env)
        self.assertTrue((self.home / ".xinitrc").is_file())
        self.assertTrue((self.home / ".local/bin/dev").stat().st_mode & 0o111)
        self.assertEqual((self.home / ".config/tmux/tmux.conf").read_text(), "set -g mouse on\n")
        run(["diff", "-r", str(ROOT / "config/nvim"), str(self.home / ".config/nvim")])
        self.assertFalse(list(self.home.rglob("*.backup.*")))


class Screenshots(Sandbox):
    def setUp(self):
        super().setUp()
        self.clipboard = self.base / "clipboard"
        self.clipboard.write_bytes(b"previous contents")
        self.env["TEST_CLIPBOARD"] = str(self.clipboard)
        self.command("maim", '[[ ${CANCEL:-0} == 0 ]] || exit 1\nprintf "\\211PNG\\r\\n\\032\\nexact-png-payload" > "${@: -1}"\n')
        self.command("xclip", 'cp -- "${@: -1}" "$TEST_CLIPBOARD"\n')
        self.command("xprop", 'echo "_NET_ACTIVE_WINDOW(WINDOW): window id # 0x123"\n')

    def test_success_exact_clipboard_and_unique_names(self):
        files = []
        for mode in [[], ["--full"], ["--window"]]:
            result = run([str(ROOT / "bin/screenshot-region"), *mode], env=self.env)
            file = Path(result.stdout.strip())
            self.assertTrue(file.exists())
            self.assertEqual(file.read_bytes(), self.clipboard.read_bytes())
            self.assertEqual(file.stat().st_mode & 0o777, 0o600)
            files.append(file)
        self.assertEqual(len(set(files)), 3)

    def test_cancel_preserves_clipboard(self):
        run([str(ROOT / "bin/screenshot-region")], env=dict(self.env, CANCEL="1"))
        self.assertEqual(self.clipboard.read_bytes(), b"previous contents")
        self.assertEqual(list((self.home / "Pictures/Screenshots").iterdir()), [])

    def test_empty_output_rejected(self):
        self.command("maim", 'touch "${@: -1}"\n')
        result = subprocess.run([str(ROOT / "bin/screenshot-region")], env=self.env, capture_output=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.clipboard.read_bytes(), b"previous contents")


class DevWorkspace(Sandbox):
    def setUp(self):
        super().setUp()
        self.real_tmux = shutil.which("tmux")
        if not self.real_tmux:
            self.skipTest("tmux is not installed")
        self.socket = "minarch-test-" + self.base.name
        self.env.update(TEST_TMUX=self.real_tmux, TEST_SOCKET=self.socket,
                        TEST_ATTACH=str(self.base / "attach"), TEST_HYFETCH=str(self.base / "hyfetch"),
                        COLUMNS="160", LINES="48")
        self.command("tmux", '''case $1 in
  attach-session|switch-client) printf '%s\\n' "$*" >> "$TEST_ATTACH"; exit 0 ;;
esac
exec "$TEST_TMUX" -L "$TEST_SOCKET" -f /dev/null "$@"
''')
        self.command("nvim", "exec sleep 120\n")
        self.command("hyfetch", 'pwd -P >> "$TEST_HYFETCH"\n')
        self.addCleanup(lambda: subprocess.run([self.real_tmux, "-L", self.socket, "kill-server"], capture_output=True))

    def tmux(self, *args):
        return run([self.real_tmux, "-L", self.socket, *args]).stdout.strip()

    def test_layout_reuse_paths_and_inside_tmux(self):
        project = self.base / "parent with ' quotes $dollars" / "same project"
        project.mkdir(parents=True)
        run([str(ROOT / "bin/dev")], cwd=project, env=self.env)
        session = self.tmux("list-sessions", "-F", "#{session_name}")
        self.assertTrue(session.endswith(hashlib.sha256(str(project).encode()).hexdigest()[:12]))
        panes = self.tmux("list-panes", "-t", session, "-F", "#{pane_left}|#{pane_top}|#{pane_width}|#{pane_current_path}|#{pane_active}").splitlines()
        self.assertEqual(len(panes), 3)
        left, top, bottom = [p.split("|") for p in panes]
        self.assertEqual(left[0], "0")
        self.assertAlmostEqual(int(left[2]) / 160, .65, delta=.02)
        self.assertEqual(top[0], bottom[0])
        self.assertGreater(int(bottom[1]), int(top[1]))
        self.assertEqual(left[4], "1")
        self.assertTrue(all(p.split("|")[3] == str(project) for p in panes))
        run([str(ROOT / "bin/dev")], cwd=project, env=self.env)
        run([str(ROOT / "bin/dev")], cwd=project, env=dict(self.env, TMUX="already-inside"))
        self.assertEqual(len(self.tmux("list-panes", "-t", session).splitlines()), 3)
        self.assertIn("switch-client", (self.base / "attach").read_text())
        other = self.base / "other" / "same project"
        other.mkdir(parents=True)
        run([str(ROOT / "bin/dev")], cwd=other, env=self.env)
        self.assertEqual(len(self.tmux("list-sessions", "-F", "#{session_name}").splitlines()), 2)


class PowerMenu(Sandbox):
    def setUp(self):
        super().setUp()
        self.env["TEST_QUEUE"] = str(self.base / "queue")
        self.env["TEST_ACTIONS"] = str(self.base / "actions")
        self.command("dmenu", '''cat >/dev/null
[[ -s $TEST_QUEUE ]] || exit 1
head -1 "$TEST_QUEUE"
sed -i '1d' "$TEST_QUEUE"
''')
        for name in ["minarch-lock", "systemctl", "xdotool", "xset"]:
            self.command(name, 'printf "%s %s\\n" "$(basename "$0")" "$*" >> "$TEST_ACTIONS"\n')

    def select(self, *choices):
        (self.base / "queue").write_text("\n".join(choices) + ("\n" if choices else ""))
        run([str(ROOT / "bin/control-menu")], env=self.env)
        actions = self.base / "actions"
        return actions.read_text() if actions.exists() else ""

    def test_cancel_and_confirmation(self):
        self.assertEqual(self.select(), "")
        self.assertEqual(self.select("Reboot", "No"), "")
        self.assertEqual(self.select("Power Off"), "")
        self.assertIn("systemctl reboot", self.select("Reboot", "Yes"))

    def test_suspend_locks_before_request(self):
        self.assertEqual(self.select("Suspend").splitlines(), ["minarch-lock ", "systemctl suspend"])

    def test_logout_native_quit_binding(self):
        self.assertIn("xdotool key --clearmodifiers super+shift+q", self.select("Log Out", "Yes"))


class HardwareSelection(Sandbox):
    def test_vendor_gpu_and_optional_backlight(self):
        sysroot = self.base / "sys"
        gpu = sysroot / "bus/pci/devices/device"
        gpu.mkdir(parents=True)
        (gpu / "class").write_text("0x030000\n")
        (gpu / "vendor").write_text("0x1002\n")
        cpuinfo = self.base / "cpuinfo"
        cpuinfo.write_text("vendor_id : AuthenticAMD\n")
        args = ["bash", "-c", 'source "$1"; hardware_packages "$2" "$3"', "test",
                str(ROOT / "install/hardware.sh"), str(sysroot), str(cpuinfo)]
        self.assertEqual(set(run(args, env=self.env).stdout.splitlines()), {"amd-ucode", "mesa"})
        backlight = sysroot / "class/backlight/panel"
        backlight.mkdir(parents=True)
        (backlight / "brightness").write_text("50\n")
        self.assertIn("brightnessctl", run(args, env=self.env).stdout)
        (gpu / "vendor").write_text("0x10de\n")
        self.command("pacman", "exit 0\n")
        self.assertNotIn("mesa", run(args, env=self.env).stdout)
        self.command("pacman", "exit 1\n")
        self.assertIn("mesa", run(args, env=self.env).stdout)
        cpuinfo.write_text("vendor_id : GenuineIntel\n")
        self.assertIn("intel-ucode", run(args, env=self.env).stdout)


class SessionStartup(Sandbox):
    def test_requires_real_lock_inhibitor(self):
        # Isolate .xinitrc itself too: skip host xinit hooks and sysfs battery
        # discovery by retaining only the post-discovery session setup portion.
        script = (ROOT / "config/session/xinitrc").read_text()
        script = "#!/usr/bin/env bash\n" + script[script.index('if [[ -z ${XDG_SESSION_ID:-}'):]
        session = self.base / "session"
        session.write_text(script)
        self.env["XDG_SESSION_ID"] = "test-session"
        self.command("systemctl", 'if [[ $* == *MainPID* ]]; then echo 1234; fi\n')
        self.command("busctl", "echo '{\"data\":[[[\"sleep\",\"xss-lock\",\"lock\",\"delay\",1000,1234]]]}'\n")
        self.command("oxwm", 'echo "wm-started"\n')
        self.assertIn("wm-started", run(["bash", str(session)], env=self.env).stdout)
        self.command("busctl", "echo '{\"data\":[[]]}'\n")
        self.command("systemctl", 'if [[ $* == *MainPID* ]]; then echo 1234; elif [[ $* == *is-active* ]]; then exit 1; fi\n')
        result = subprocess.run(["bash", str(session)], env=self.env, text=True, capture_output=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertNotIn("wm-started", result.stdout)


class RepositoryPolicy(unittest.TestCase):
    def test_manifest_and_firefox(self):
        packages = {line.split("#")[0].strip() for line in (ROOT / "install/packages").read_text().splitlines()}
        self.assertTrue({"openai-codex", "firefox-ublock-origin", "xsecurelock", "xss-lock"} <= packages)
        banned = {"bluez", "blueman", "cups", "avahi", "networkmanager", "wl-clipboard", "picom", "sddm", "gnome-keyring"}
        self.assertFalse(banned & packages)
        policies = json.loads((ROOT / "etc/firefox/policies/policies.json").read_text())["policies"]
        self.assertEqual(policies["AIControls"]["Default"], {"Value": "blocked", "Locked": True})
        self.assertEqual(set(policies), {"FirefoxHome", "FirefoxSuggest", "AIControls"})


if __name__ == "__main__":
    unittest.main(verbosity=2)
