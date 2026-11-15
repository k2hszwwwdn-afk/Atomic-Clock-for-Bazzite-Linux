#!/usr/bin/env python3

import json
import math
import os
from pathlib import Path
import subprocess
import tempfile

import gi

gi.require_version("Gtk", "4.0")
gi.require_version("WebKit", "6.0")

from gi.repository import GLib, Gtk, WebKit

APPLET_ID = "io.github.atomicclock.plasma"
APPLET_PATH = Path(__file__).parent / "plasma" / "atomic-time"


class AtomicTimeApplication(Gtk.Application):
    def __init__(self) -> None:
        super().__init__(application_id="io.github.atomicclock.AtomicTime")
        self.clock_state_path = Path(GLib.get_user_data_dir()) / "atomic-time" / "clock-state.json"

    def save_clock_state(self, _manager: WebKit.UserContentManager, message) -> None:
        try:
            state = json.loads(message.to_string())
        except (AttributeError, TypeError, ValueError) as error:
            GLib.warning(f"Ignoring invalid Atomic Time widget state: {error}")
            return

        if not isinstance(state, dict):
            GLib.warning("Ignoring invalid Atomic Time widget state: expected an object")
            return

        numeric_fields = ("clockOffsetMs", "timeZoneOffsetMs", "updatedAt")
        if (
            state.get("version") != 1
            or not isinstance(state.get("timeZone"), str)
            or type(state.get("hourFormat")) is not int
            or state["hourFormat"] not in (12, 24)
            or type(state.get("synced")) is not bool
            or any(
                isinstance(state.get(field), bool)
                or not isinstance(state.get(field), (int, float))
                or not math.isfinite(state[field])
                for field in numeric_fields
            )
        ):
            GLib.warning("Ignoring invalid Atomic Time widget state: fields failed validation")
            return

        temporary_path = None
        try:
            self.clock_state_path.parent.mkdir(parents=True, exist_ok=True)
            with tempfile.NamedTemporaryFile(
                mode="w",
                encoding="utf-8",
                dir=self.clock_state_path.parent,
                prefix=".clock-state-",
                delete=False,
            ) as temporary_file:
                temporary_path = Path(temporary_file.name)
                json.dump(
                    {
                        "version": 1,
                        "timeZone": state["timeZone"],
                        "hourFormat": state["hourFormat"],
                        "clockOffsetMs": state["clockOffsetMs"],
                        "timeZoneOffsetMs": state["timeZoneOffsetMs"],
                        "synced": state["synced"],
                        "updatedAt": state["updatedAt"],
                    },
                    temporary_file,
                )
            os.replace(temporary_path, self.clock_state_path)
            temporary_path = None
        except OSError as error:
            GLib.warning(f"Could not publish Atomic Time state for the widget: {error}")
        finally:
            if temporary_path is not None:
                try:
                    temporary_path.unlink()
                except FileNotFoundError:
                    pass
                except OSError as error:
                    GLib.warning(f"Could not remove temporary Atomic Time state file: {error}")

    def do_activate(self) -> None:
        window = self.get_active_window()
        if window is None:
            window = Gtk.ApplicationWindow(application=self)
            window.set_title("Atomic Time")
            window.set_default_size(760, 560)

            header = Gtk.HeaderBar()
            header.set_title_widget(Gtk.Label(label="Atomic Time"))
            add_widget_button = Gtk.Button(label="Add widget")
            add_widget_button.connect("clicked", self.add_widget, window)
            header.pack_end(add_widget_button)
            window.set_titlebar(header)

            content_manager = WebKit.UserContentManager()
            content_manager.register_script_message_handler("atomicTimeState")
            content_manager.connect(
                "script-message-received::atomicTimeState",
                self.save_clock_state,
            )
            clock = WebKit.WebView(user_content_manager=content_manager)
            clock.load_uri(Path(__file__).with_name("index.html").resolve().as_uri())
            window.set_child(clock)

        window.present()

    def add_widget(self, _button: Gtk.Button, window: Gtk.ApplicationWindow) -> None:
        try:
            package = subprocess.run(
                ["kpackagetool6", "--type", "Plasma/Applet", "--show", APPLET_ID],
                capture_output=True,
                check=False,
                text=True,
            )
            package_action = "--upgrade" if package.returncode == 0 else "--install"
            subprocess.run(
                ["kpackagetool6", "--type", "Plasma/Applet", package_action, str(APPLET_PATH)],
                capture_output=True,
                check=True,
                text=True,
            )
            layout = subprocess.run(
                [
                    "qdbus-qt6",
                    "org.kde.plasmashell",
                    "/PlasmaShell",
                    "org.kde.PlasmaShell.dumpCurrentLayoutJS",
                ],
                capture_output=True,
                check=True,
                text=True,
            ).stdout
            if f'"plugin": "{APPLET_ID}"' in layout:
                message = "Atomic Time is already on your desktop."
            else:
                subprocess.run(
                    [
                        "qdbus-qt6",
                        "org.kde.plasmashell",
                        "/PlasmaShell",
                        "org.kde.PlasmaShell.evaluateScript",
                        f'desktops()[0].addWidget("{APPLET_ID}")',
                    ],
                    capture_output=True,
                    check=True,
                    text=True,
                )
                message = "Atomic Time widget added to your desktop."
        except (FileNotFoundError, subprocess.CalledProcessError) as error:
            detail = error.stderr.strip() if isinstance(error, subprocess.CalledProcessError) and error.stderr else str(error)
            self.show_message(window, "Could not add the Plasma widget.", detail, Gtk.MessageType.ERROR)
            return

        self.show_message(window, message, "", Gtk.MessageType.INFO)

    @staticmethod
    def show_message(
        window: Gtk.ApplicationWindow,
        message: str,
        detail: str,
        message_type: Gtk.MessageType,
    ) -> None:
        dialog = Gtk.MessageDialog(
            transient_for=window,
            modal=True,
            message_type=message_type,
            buttons=Gtk.ButtonsType.OK,
            text=message,
        )
        if detail:
            dialog.format_secondary_text(detail)
        dialog.connect("response", lambda current_dialog, _response: current_dialog.destroy())
        dialog.present()


if __name__ == "__main__":
    raise SystemExit(AtomicTimeApplication().run())
