#!/usr/bin/env bash
set -eu

source_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
data_home="${XDG_DATA_HOME:-$HOME/.local/share}"
install_dir="$data_home/atomic-time"
plasmoid_dir="$install_dir/plasma/atomic-time"
applications_dir="$data_home/applications"
icons_dir="$data_home/icons/hicolor/scalable/apps"

mkdir -p "$install_dir" "$plasmoid_dir" "$applications_dir" "$icons_dir"
install -m 0644 "$source_dir/index.html" "$install_dir/index.html"
install -m 0644 "$source_dir/main.py" "$install_dir/main.py"
install -m 0755 "$source_dir/run.sh" "$install_dir/run.sh"
install -m 0644 "$source_dir/atomic-time.svg" "$icons_dir/atomic-time.svg"
cp -R "$source_dir/plasma/atomic-time/." "$plasmoid_dir/"

if command -v kpackagetool6 >/dev/null 2>&1; then
  if kpackagetool6 --type Plasma/Applet --show io.github.atomicclock.plasma >/dev/null 2>&1; then
    kpackagetool6 --type Plasma/Applet --upgrade "$plasmoid_dir"
  else
    kpackagetool6 --type Plasma/Applet --install "$plasmoid_dir"
  fi
fi

exec_path="$install_dir/run.sh"
exec_path="${exec_path//\\/\\\\}"
exec_path="${exec_path//\"/\\\"}"
icon_path="$icons_dir/atomic-time.svg"

cat > "$applications_dir/atomic-time.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=Atomic Time
Comment=Online-synchronized digital clock with time zone selection
Exec="/usr/bin/env" bash "$exec_path"
Icon=$icon_path
Terminal=false
Categories=Utility;Clock;
StartupNotify=true
EOF

printf 'Installed Atomic Time. Find it in your application launcher, or run:\n  %s\n' "$exec_path"
