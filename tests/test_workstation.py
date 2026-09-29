#!/usr/bin/env python3
"""Isolated integration checks; never installs packages or touches the live home."""
import hashlib
import json
import os
from pathlib import Path
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
        self.env.pop("NVIM_APPNAME", None)

    def command(self, name, body):
        path = self.commands / name
        path.write_text("#!/usr/bin/env bash\nset -euo pipefail\n" + body)
        path.chmod(0o755)


class TerminalShell(Sandbox):
    def test_preserved_bashrc_and_existing_blesh(self):
        ble = self.base / "ble.sh"
        ble.write_text('BLE_VERSION=test\nprintf "loaded\\n"\n'
                       'ble-attach() { printf "attached\\n"; }\n')
        rc = self.base / "st.bashrc"
        rc.write_text((ROOT / "config/st/bashrc").read_text().replace(
            "/usr/share/blesh/ble.sh", str(ble)))
        for existing in (False, True):
            with self.subTest(existing_blesh=existing):
                user_rc = 'PS1="custom> "\nalias retained="echo retained"\n'
                if existing:
                    user_rc += f'source "{ble}"\nble-attach\n'
                (self.home / ".bashrc").write_text(user_rc)
                result = run(["bash", "--noprofile", "--rcfile", str(rc), "-ic",
                              'printf "%s\\n" "$PS1"; retained'], env=self.env)
                self.assertEqual(result.stdout.splitlines(),
                                 ["loaded", "attached", "custom> ", "retained"])
                self.assertEqual((self.home / ".bashrc").read_text(), user_rc)

    def test_missing_user_bashrc_and_noninteractive_guard(self):
        ble = self.base / "ble.sh"
        ble.write_text('BLE_VERSION=test\nble-attach() { echo attached; }\n')
        rc = self.base / "st.bashrc"
        rc.write_text((ROOT / "config/st/bashrc").read_text().replace(
            "/usr/share/blesh/ble.sh", str(ble)))
        result = run(["bash", "--noprofile", "--rcfile", str(rc), "-ic", ":"], env=self.env)
        self.assertEqual(result.stdout.strip(), "attached")
        result = run(["bash", "-c", 'source "$1"', "test", str(rc)], env=self.env)
        self.assertEqual(result.stdout, "")


class AurManifestInput(Sandbox):
    def test_child_prompts_cannot_consume_manifest_entries(self):
        repo = self.base / "repo"
        (repo / "install").mkdir(parents=True)
        (repo / "install/packages-aur").write_text(
            "# reviewed recipes\n\nfirst-package recipe-a source-a\n"
            "second-package recipe-b - # inline comment\n")
        (repo / "config/st").mkdir(parents=True)
        for name in ["PKGBUILD", "config.h", "0001-scrollback-and-urls.patch", "minarch-shell", "bashrc"]:
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
        self.assertTrue((self.home / ".local/bin/nvimide").stat().st_mode & 0o111)
        self.assertTrue((self.home / ".local/bin/minarch-hardware-hotplug").stat().st_mode & 0o111)
        self.assertTrue((self.home / ".local/bin/xsecurelock-without-picom").stat().st_mode & 0o111)
        self.assertTrue((self.home / ".local/lib/clipmenu-text-probe/xsel").stat().st_mode & 0o111)
        self.assertTrue((self.home / ".config/picom/picom.conf").is_file())
        self.assertTrue((self.home / ".config/minarch/hardware.conf").is_file())
        self.assertTrue((self.home / ".config/xfe/xferc").is_file())
        self.assertTrue((self.home / ".config/fastfetch/config.jsonc").is_file())
        run(["diff", "-r", str(ROOT / "config/nvim"), str(self.home / ".config/nvim")])
        self.assertFalse(list(self.home.rglob("*.backup.*")))


class LocalBuildCache(Sandbox):
    def setUp(self):
        super().setUp()
        self.calls = self.base / "build-calls"
        self.env["TEST_CALLS"] = str(self.calls)
        self.state = self.base / "state"
        self.stamp = self.state / "builds/st-minarch"
        self.command("sudo", 'exec "$@"\n')
        self.command("makepkg", '''
if [[ $1 == --packagelist ]]; then
  printf '%s/package.pkg.tar.zst\\n' "$PWD"
else
  echo build >> "$TEST_CALLS"
  touch package.pkg.tar.zst
fi
''')
        self.command("pacman", '''
case $1 in
  -Q) echo 'st-minarch 0.9.3-4' ;;
  -U)
    printf '%s\\n' "$*" >> "$TEST_CALLS"
    [[ ${FAIL_INSTALL:-0} == 0 ]] || exit 1
    ;;
  *) exit 2 ;;
esac
''')

    def build(self, identity, fail=False):
        return subprocess.run(["bash", "-euo", "pipefail", "-c", '''
ROOT=$1 STATE=$2
source "$ROOT/install/common.sh"
source "$ROOT/install/packages.sh"
build_package st-minarch "$3"
''', "test", str(ROOT), str(self.state), identity],
            env=dict(self.env, FAIL_INSTALL=str(int(fail))), text=True, capture_output=True)

    def test_changed_same_version_reinstalls_and_legacy_stamp_expires(self):
        self.stamp.parent.mkdir(parents=True)
        self.stamp.write_text('recipe-a:- st-minarch 0.9.3-4\n')
        for identity in ['recipe-a', 'recipe-a', 'recipe-b']:
            result = self.build(identity)
            self.assertEqual(result.returncode, 0, result.stderr)
        rows = self.calls.read_text().splitlines()
        self.assertEqual(rows.count('build'), 2)
        installs = [row for row in rows if row.startswith('-U ')]
        self.assertEqual(len(installs), 2)
        self.assertTrue(all(row.startswith('-U -- ') for row in installs))
        self.assertNotIn('--needed', '\n'.join(installs))
        self.assertIn('recipe-b', self.stamp.read_text())

    def test_failed_install_keeps_stamp_and_retries(self):
        self.assertEqual(self.build('recipe-a').returncode, 0)
        previous = self.stamp.read_text()
        self.assertNotEqual(self.build('recipe-b', fail=True).returncode, 0)
        self.assertEqual(self.stamp.read_text(), previous)
        self.assertEqual(self.build('recipe-b').returncode, 0)
        self.assertIn('recipe-b', self.stamp.read_text())
        self.assertEqual(self.calls.read_text().splitlines().count('build'), 3)


class ConfigPaths(Sandbox):
    def test_installed_picom_launcher_uses_config_home_with_spaces(self):
        custom = self.home / 'custom config'
        self.env['XDG_CONFIG_HOME'] = str(custom)
        run([str(ROOT / 'install.sh'), '--config-only'], env=self.env)
        unit = (custom / 'systemd/user/minarch-picom.service').read_text()
        launcher = next(line.removeprefix('ExecStart=') for line in unit.splitlines()
                        if line.startswith('ExecStart=')).replace('%h', str(self.home))
        self.command('picom', 'printf "%s\\n" "$@"\n')
        result = run([launcher], env=self.env)
        self.assertEqual(result.stdout.splitlines(), ['--config', str(custom / 'picom/picom.conf')])
        self.assertTrue((custom / 'picom/picom.conf').is_file())
        env = dict(self.env)
        env.pop('XDG_CONFIG_HOME')
        result = run([launcher], env=env)
        self.assertEqual(result.stdout.splitlines(), ['--config', str(self.home / '.config/picom/picom.conf')])


class RetiredFiles(Sandbox):
    def setUp(self):
        super().setUp()
        self.repo = self.base / 'repo'
        (self.repo / 'install').mkdir(parents=True)
        self.original = b'old managed helper\n'
        digest = hashlib.sha256(self.original).hexdigest()
        (self.repo / 'install/retired-files').write_text(f'home .local/bin/dev {digest}\n')
        self.target = self.home / '.local/bin/dev'
        self.target.parent.mkdir(parents=True)

    def migrate(self):
        return run(['bash', '-euo', 'pipefail', '-c', '''
source "$1/install/common.sh"
source "$1/install/migrations.sh"
ROOT=$2
cleanup_retired
''', 'test', str(ROOT), str(self.repo)], env=self.env)

    def test_matching_file_retired_with_backup_and_idempotent_rerun(self):
        self.target.write_bytes(self.original)
        self.migrate()
        self.assertFalse(self.target.exists())
        backups = list(self.target.parent.glob('dev.retired.*/original'))
        self.assertEqual(len(backups), 1)
        self.assertEqual(backups[0].read_bytes(), self.original)
        self.migrate()
        self.assertEqual(len(list(self.target.parent.glob('dev.retired.*'))), 1)

    def test_modified_files_directories_and_symlinks_are_preserved(self):
        self.target.write_text('my own helper\n')
        self.assertIn('modified or unknown', self.migrate().stdout)
        self.assertEqual(self.target.read_text(), 'my own helper\n')
        self.target.unlink()
        self.target.mkdir()
        self.migrate()
        self.assertTrue(self.target.is_dir())
        self.target.rmdir()
        outside = self.base / 'outside'
        outside.write_bytes(self.original)
        self.target.symlink_to(outside)
        self.migrate()
        self.assertTrue(self.target.is_symlink())
        self.assertEqual(outside.read_bytes(), self.original)
        self.target.unlink()
        self.target.parent.rmdir()
        external_dir = self.base / 'external bin'
        external_dir.mkdir()
        (external_dir / 'dev').write_bytes(self.original)
        self.target.parent.symlink_to(external_dir, target_is_directory=True)
        self.migrate()
        self.assertEqual(self.target.read_bytes(), self.original)
        self.assertFalse(list(self.home.rglob('*.retired.*')))

    def test_cleanup_requires_explicit_installer_flag(self):
        old_config = self.home / '.config/tmux/tmux.conf'
        old_config.parent.mkdir(parents=True)
        old_config.write_text('set -g mouse on\n')
        run([str(ROOT / 'install.sh'), '--config-only'], env=self.env)
        self.assertTrue(old_config.exists())
        run([str(ROOT / 'install.sh'), '--config-only', '--cleanup-retired'], env=self.env)
        self.assertFalse(old_config.exists())
        backup = next(old_config.parent.glob('tmux.conf.retired.*/original'))
        self.assertEqual(backup.read_text(), 'set -g mouse on\n')


class HardwareProfile(Sandbox):
    def setUp(self):
        super().setUp()
        self.env.update(DISPLAY=':88', XDG_DATA_HOME=str(self.base / 'data'))
        self.calls = self.base / 'hardware-calls'
        self.outputs = self.base / 'outputs'
        self.env.update(TEST_CALLS=str(self.calls), TEST_OUTPUTS=str(self.outputs))
        self.profile = self.home / '.config/minarch/hardware.conf'
        self.profile.parent.mkdir(parents=True)
        self.profile.write_text('''keyboard_name='Board [rev.2]'
keyboard_vendor=abcd
keyboard_product=1234
keyboard_layout=gb
keyboard_options=(altwin:swap_alt_win)
keyboard_interfaces=1
mirror_output=DP-3
mirror_source=eDP-2
mirror_mode=2560x1440
mirror_rate=75
''')
        log = self.base / 'data/xorg/Xorg.88.log'
        log.parent.mkdir(parents=True)
        log.write_text('''XINPUT: Adding extended input device "Board [rev.2]" (type: KEYBOARD, id 21)
XINPUT: Adding extended input device "Board [rev.2]" (type: KEYBOARD, id 22)
XINPUT: Adding extended input device "Board revX2" (type: KEYBOARD, id 99)
''')
        self.outputs.write_text('DP-3 connected\neDP-2 connected primary\n')
        self.command('xrandr', '''
if [[ $1 == --query ]]; then cat "$TEST_OUTPUTS"; else echo "xrandr $*" >> "$TEST_CALLS"; fi
''')
        self.command('setxkbmap', 'echo "setxkbmap $*" >> "$TEST_CALLS"\n')
        self.command('xkbcomp', 'cat >/dev/null\n')
        self.command('sleep', 'exit 0\n')
        self.command('udevadm', '''
case $* in
  *subsystem-match=input*)
    printf 'ACTION=add\\nID_VENDOR_ID=abcd\\nID_MODEL_ID=1234\\n\\n'
    printf 'ACTION=add\\nID_VENDOR_ID=ffff\\nID_MODEL_ID=1234\\n\\n' ;;
  *subsystem-match=drm*) printf 'ACTION=change\\nHOTPLUG=1\\n\\n' ;;
esac
''')

    def test_custom_keyboard_and_monitor_settings_on_startup_and_hotplug(self):
        run([str(ROOT / 'bin/minarch-hardware-hotplug')], env=self.env)
        rows = self.calls.read_text().splitlines()
        keyboard = 'setxkbmap -device 22 -option  -option altwin:swap_alt_win gb -print'
        monitor = 'xrandr --output DP-3 --mode 2560x1440 --rate 75 --same-as eDP-2'
        self.assertEqual(rows.count(keyboard), 2)
        self.assertEqual(rows.count(monitor), 2)
        self.assertEqual(len(rows), 4)

    def test_missing_source_monitor_and_disabled_features(self):
        self.outputs.write_text('DP-3 connected\neDP-2 disconnected\n')
        run([str(ROOT / 'bin/minarch-hardware-hotplug'), '--once'], env=self.env)
        self.assertNotIn('xrandr', self.calls.read_text())
        self.calls.unlink()
        self.profile.write_text("keyboard_name=''\nmirror_output=''\n")
        run([str(ROOT / 'bin/minarch-hardware-hotplug')], env=self.env)
        self.assertFalse(self.calls.exists())
        self.profile.unlink()
        run([str(ROOT / 'bin/minarch-hardware-hotplug'), '--once'], env=self.env)
        self.assertFalse(self.calls.exists())


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
        (gpu / "vendor").write_text("0x8086\n")
        (gpu / "device").write_text("0x3ea0\n")
        self.assertTrue({"intel-media-driver", "libva-utils"} <= set(run(args, env=self.env).stdout.splitlines()))
        (gpu / "device").write_text("0x1234\n")
        self.assertNotIn("intel-media-driver", run(args, env=self.env).stdout)


class SessionStartup(Sandbox):
    def test_requires_real_lock_inhibitor(self):
        # Isolate .xinitrc itself too: skip host xinit hooks and sysfs battery
        # discovery by retaining only the post-discovery session setup portion.
        script = (ROOT / "config/session/xinitrc").read_text()
        script = "#!/usr/bin/env bash\n" + script[script.index('if [[ -z ${XDG_SESSION_ID:-}'):]
        session = self.base / "session"
        session.write_text(script)
        self.env["XDG_SESSION_ID"] = "test-session"
        self.env['XDG_CONFIG_HOME'] = str(self.home / 'custom config')
        self.env['XDG_DATA_HOME'] = str(self.home / 'custom data')
        self.env.pop('XDG_CACHE_HOME', None)
        imported = self.base / 'imported-env'
        self.env['TEST_IMPORTED'] = str(imported)
        self.command("systemctl", '''
if [[ $* == *MainPID* ]]; then echo 1234; fi
if [[ ${2:-} == import-environment ]]; then
  printf '%s\\n' "$*" "$XDG_CONFIG_HOME" "$XDG_DATA_HOME" "$XDG_CACHE_HOME" > "$TEST_IMPORTED"
fi
''')
        self.command("busctl", "echo '{\"data\":[[[\"sleep\",\"xss-lock\",\"lock\",\"delay\",1000,1234]]]}'\n")
        self.command("oxwm", 'echo "wm-started"\n')
        self.assertIn("wm-started", run(["bash", str(session)], env=self.env).stdout)
        imported_lines = imported.read_text().splitlines()
        self.assertTrue({'XDG_CONFIG_HOME', 'XDG_DATA_HOME', 'XDG_STATE_HOME', 'XDG_CACHE_HOME'}
                        <= set(imported_lines[0].split()))
        self.assertEqual(imported_lines[1:], [self.env['XDG_CONFIG_HOME'],
                         self.env['XDG_DATA_HOME'], str(self.home / '.cache')])
        self.command("busctl", "echo '{\"data\":[[]]}'\n")
        self.command("systemctl", 'if [[ $* == *MainPID* ]]; then echo 1234; elif [[ $* == *is-active* ]]; then exit 1; fi\n')
        result = subprocess.run(["bash", str(session)], env=self.env, text=True, capture_output=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertNotIn("wm-started", result.stdout)


class RepositoryPolicy(unittest.TestCase):
    def test_manifest_and_firefox(self):
        packages = {line.split("#")[0].strip() for line in (ROOT / "install/packages").read_text().splitlines()}
        self.assertTrue({"openai-codex", "firefox-ublock-origin", "xsecurelock", "xss-lock"} <= packages)
        banned = {"bluez", "blueman", "cups", "avahi", "networkmanager", "wl-clipboard", "sddm", "gnome-keyring"}
        self.assertFalse(banned & packages)
        self.assertTrue({"picom", "fastfetch", "xorg-xkbcomp"} <= packages)
        policies = json.loads((ROOT / "etc/firefox/policies/policies.json").read_text())["policies"]
        self.assertEqual(policies["AIControls"]["Default"], {"Value": "blocked", "Locked": True})
        self.assertEqual(policies["EnableTrackingProtection"]["Category"], "strict")
        self.assertTrue(policies["Preferences"]["privacy.globalprivacycontrol.enabled"]["Value"])
        self.assertTrue(policies["DisableTelemetry"])
        self.assertTrue(policies["DisableFirefoxStudies"])
        self.assertFalse(policies["SearchSuggestEnabled"])
        self.assertFalse(policies["NetworkPrediction"])
        self.assertEqual(policies["HttpsOnlyMode"], "enabled")
        extensions = policies["ExtensionSettings"]
        self.assertEqual(set(extensions), {"addon@darkreader.org",
                         "enhancerforyoutube@maximerf.addons.mozilla.org"})
        for guid, settings in extensions.items():
            self.assertEqual(settings["installation_mode"], "normal_installed")
            self.assertEqual(settings["install_url"],
                             f"https://addons.mozilla.org/firefox/downloads/latest/{guid}/latest.xpi")
        # Hardening must retain Firefox's built-in security mechanisms.
        for key in ["DisableAppUpdate", "DisableSystemAddonUpdate", "DisableFormHistory",
                    "PasswordManagerEnabled", "OfferToSaveLogins", "AutofillAddressEnabled",
                    "AutofillCreditCardEnabled", "SanitizeOnShutdown", "Cookies"]:
            self.assertNotIn(key, policies)
        for key in ["xpinstall.signatures.required", "browser.safebrowsing.malware.enabled",
                    "browser.safebrowsing.phishing.enabled"]:
            self.assertNotIn(key, policies["Preferences"])


if __name__ == "__main__":
    unittest.main(verbosity=2)
