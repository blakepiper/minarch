import argparse
import json
import os
import sys

from core import nightlight_settings, set_nightlight, SettingsError, command, power_profiles, set_power_profile, run_nightlight, apply_saved_display, apply_session_preferences, prepare_picom_configuration, preview_display, apply_input_preferences


def main(gui=True):
    parser = argparse.ArgumentParser(description="Blix desktop settings")
    parser.add_argument("action", nargs="?", choices=["display-hotplug", "apply-session", "apply-input", "display-preview", "prepare-picom", "nightlight", "nightlight-level", "power-mode", "power-modes"])
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
        if (args.action == "power-mode" and args.profile) or args.action == "nightlight-level":
            try:
                command("notify-send", "--urgency=critical", "Setting could not be changed", str(error))
            except SettingsError:
                pass
        sys.exit(1)


if __name__ == "__main__":
    runtime = "--runtime" in sys.argv
    if runtime:
        sys.argv.remove("--runtime")
    main(gui=not runtime)
