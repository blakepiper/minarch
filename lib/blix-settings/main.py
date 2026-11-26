import argparse
import json
import os
import subprocess
import sys

from core import POWER_PROFILES, nightlight_settings, set_nightlight, SettingsError, command, power_profiles, set_power_profile, run_nightlight, apply_saved_display, apply_session_preferences, prepare_picom_configuration, preview_display, apply_input_preferences


def power_menu():
    state = power_profiles()
    choices = {POWER_PROFILES[profile][0]: profile for profile in state["profiles"]}
    current = POWER_PROFILES[state["active"]][0]
    result = subprocess.run(["dmenu", "-i", "-p", f"Power mode ({current})"],
                            input="\n".join(choices) + "\n", stdout=subprocess.PIPE, text=True)
    selection = choices.get(result.stdout.strip())
    if result.returncode == 0 and selection:
        set_power_profile(selection)


def main(gui=True):
    parser = argparse.ArgumentParser(description="Blix desktop settings")
    parser.add_argument("action", nargs="?", choices=["display-hotplug", "apply-session", "apply-input", "display-preview", "prepare-picom", "nightlight", "nightlight-level", "power-menu", "power-mode", "power-modes"])
    parser.add_argument("profile", nargs="?", choices=["performance", "balanced", "power-saver"])
    parser.add_argument("--intensity", type=int, help="Night light warmth from 0 (off) to 100")
    parser.add_argument("--demo", action="store_true", help="Preview the interface with simulated devices; changes stay in memory")
    parser.add_argument("--page", choices=["display", "audio", "network", "bluetooth", "power", "input", "shortcuts", "about"])
    args = parser.parse_args()
    try:
        if gui:
            from ui import Application
            sys.exit(Application(demo=args.demo).run([sys.argv[0]] + ([args.page] if args.page else [])))
        if args.action == "display-hotplug":
            sys.exit(apply_saved_display())
        elif args.action == "apply-session":
            if os.environ.get("DISPLAY"):
                apply_session_preferences()
        elif args.action == "apply-input":
            if os.environ.get("DISPLAY"):
                apply_input_preferences()
        elif args.action == "display-preview":
            preview_display(json.loads(sys.stdin.readline()))
        elif args.action == "nightlight":
            run_nightlight()
        elif args.action == "nightlight-level":
            if args.intensity is None:
                value = nightlight_settings()
                print(value["intensity"] if value["enabled"] else 0)
            else:
                # Zero means off, not forgetting the warmth to restore next time.
                intensity = args.intensity if args.intensity != 0 else nightlight_settings()["intensity"] or 50
                set_nightlight(args.intensity > 0, intensity)
        elif args.action == "prepare-picom":
            print(prepare_picom_configuration())
        elif args.action == "power-menu":
            power_menu()
        elif args.action == "power-mode":
            if args.profile:
                set_power_profile(args.profile)
            else:
                print(power_profiles()["active"])
        elif args.action == "power-modes":
            print(" ".join(power_profiles()["profiles"]))
        else:
            parser.error("a runtime action is required")
    except (SettingsError, ValueError, OSError) as error:
        print(str(error), file=sys.stderr)
        failure_title = {
            "power-menu": "Power mode unavailable",
            "power-mode": "Power mode change failed" if args.profile else None,
            "nightlight-level": "Night Light change failed" if args.intensity is not None else None,
        }.get(args.action)
        if failure_title:
            try:
                command("notify-send", "--app-name=Minarch", "--urgency=critical", "--", failure_title, str(error))
            except SettingsError:
                pass
        sys.exit(1)


if __name__ == "__main__":
    runtime = "--runtime" in sys.argv
    if runtime:
        sys.argv.remove("--runtime")
    main(gui=not runtime)
