#!/usr/bin/env bash
set -eu

app_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
app_file="$app_dir/index.html"
file_url="file://$(printf '%s' "$app_file" | sed 's/ /%20/g')"

if command -v python3 >/dev/null 2>&1 &&
  python3 -c 'import gi; gi.require_version("Gtk", "4.0"); gi.require_version("WebKit", "6.0"); from gi.repository import Gtk, WebKit' >/dev/null 2>&1; then
  exec python3 "$app_dir/main.py"
fi

for browser in chromium chromium-browser google-chrome-stable google-chrome brave-browser brave microsoft-edge microsoft-edge-stable; do
  if command -v "$browser" >/dev/null 2>&1; then
    exec "$browser" --app="$file_url" --no-first-run
  fi
done

if command -v flatpak >/dev/null 2>&1; then
  for app_id in org.chromium.Chromium com.google.Chrome com.brave.Browser com.microsoft.Edge; do
    if flatpak list --app --columns=application 2>/dev/null | grep -Fxq "$app_id"; then
      exec flatpak run "$app_id" --app="$file_url" --no-first-run
    fi
  done
fi

if command -v firefox >/dev/null 2>&1; then
  exec firefox --new-window "$file_url"
fi

if command -v flatpak >/dev/null 2>&1 &&
  flatpak list --app --columns=application 2>/dev/null | grep -Fxq "org.mozilla.firefox"; then
  exec flatpak run --filesystem="$app_dir:ro" org.mozilla.firefox --new-window "$file_url"
fi

if command -v xdg-open >/dev/null 2>&1; then
  exec xdg-open "$app_file"
fi

printf '%s\n' "Atomic Time needs a web browser. Install Firefox or Chromium and try again." >&2
exit 1
