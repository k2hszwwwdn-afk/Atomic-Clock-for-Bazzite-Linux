# Atomic Time

A small, standalone clock for Linux desktops. On Bazzite it opens in a native GTK window with an embedded WebKit view. It shows a green LED-style digital readout with milliseconds, supports system time zones and 12/24-hour display, and syncs to TimeAPI.io's UTC time service once a minute.

## Bazzite installation

From this folder, run:

```sh
./install.sh
```

Then search for **Atomic Time** in the application launcher. On systems without the GTK/WebKit runtime, it falls back to an installed browser; the Firefox Flatpak receives read-only access to this app's folder so it can load the local page.

The installer copies the app to `~/.local/share/atomic-time` and adds a desktop entry and icon for your user; it does not change system files. To remove it, delete that app folder, `~/.local/share/applications/atomic-time.desktop`, and `~/.local/share/icons/hicolor/scalable/apps/atomic-time.svg`.

Online time accuracy depends on the time service and network connection; when the service cannot be reached, the app clearly switches to the device clock.

## KDE Plasma widget

The Plasma 6 widget package is in `plasma/atomic-time`. Install it with:

```sh
kpackagetool6 --type Plasma/Applet --install plasma/atomic-time
```

The installer also installs the widget package. The widget shows only the time readout; resize it to scale the digits. Right-click it and choose **Configure** to set an IANA time zone, switch between 12- and 24-hour time, pick a custom readout color, or toggle the transparent background (on by default). A dark outline keeps the digits readable over wallpapers. The standalone app includes an **Add widget** button.
