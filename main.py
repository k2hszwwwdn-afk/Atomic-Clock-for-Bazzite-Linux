#!/usr/bin/env python3

from pathlib import Path
import subprocess

import gi

gi.require_version("Gtk", "4.0")
gi.require_version("WebKit", "6.0")

from gi.repository import Gtk, WebKit

APPLET_ID = "io.github.atomicclock.plasma"
APPLET_PATH = Path(__file__).parent / "plasma" / "atomic-time"


class AtomicTimeApplication(Gtk.Application):
    def __init__(self) -> None:
        super().__init__(application_id="io.github.atomicclock.AtomicTime")

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

            clock = WebKit.WebView()
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
