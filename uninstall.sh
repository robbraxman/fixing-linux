#!/usr/bin/env bash
# Human Linux — uninstall
# Removes files and rules the install script created.
# Does not remove packages. Does not undo dock, scale, pins, or browser defaults.
if [[ ! -t 1 ]]; then
  zenity --question --width=420 --title="Human Linux uninstall" \
    --text="This removes the links, bookmarks, watcher, Find my file, Brax.me, the lid rule, and the IPv4 preference.\n\nPackages stay installed. A terminal will open for your password. Continue?" \
    || exit 0
  term="$(command -v gnome-terminal || command -v x-terminal-emulator || true)"
  [[ -n "$term" ]] || { zenity --error --text="No terminal found."; exit 1; }
  exec "$term" -- bash -c "\"$0\"; echo; read -r -p 'Press Enter to close.'"
fi
set -euo pipefail

log()  { printf '\n==> %s\n' "$*"; }
warn() { printf '!!  %s\n' "$*" >&2; }

if [[ "$(id -u)" -eq 0 ]]; then
  warn "Run as your user, not root."
  exit 1
fi

log "Links and bookmarks"
find "$HOME/Media/Disks" -maxdepth 1 -type l -delete 2>/dev/null || true
rm -f "$HOME/Media/Phone"
find "$HOME/Documents/AppFiles" -maxdepth 2 -type l -delete 2>/dev/null || true
rmdir "$HOME/Media/Disks" "$HOME/Media" "$HOME/Documents/AppFiles/debs" \
      "$HOME/Documents/AppFiles/rpms" \
      "$HOME/Documents/AppFiles/appimages" "$HOME/Documents/AppFiles" \
      "$HOME/Videos/OBS" 2>/dev/null || true

for f in "$HOME/.config/gtk-3.0/bookmarks" "$HOME/.config/gtk-4.0/bookmarks"; do
  [[ -f "$f" ]] || continue
  grep -vE 'file://.+/Media |file://.+/AppFiles ' "$f" > "$f.tmp" || true
  mv "$f.tmp" "$f"
done
if [[ -f "$HOME/.local/share/user-places.xbel" ]]; then
  grep -vE 'file://.+/Media"|file://.+/AppFiles"' "$HOME/.local/share/user-places.xbel" > "$HOME/.local/share/user-places.xbel.tmp" || true
  mv "$HOME/.local/share/user-places.xbel.tmp" "$HOME/.local/share/user-places.xbel"
fi
rm -f "$HOME/.local/share/org.gnome.Ptyxis/palettes/kit-contrast.palette"

log "Launchers and watcher"
systemctl --user disable --now human-linux-usb-watch.service 2>/dev/null || true
rm -f "$HOME/.config/systemd/user/human-linux-usb-watch.service" \
      "$HOME/.local/bin/human-linux-usb-watch" \
      "$HOME/.local/bin/where-is-my-file" \
      "$HOME/.local/bin/where-is-my-file-gui" \
      "$HOME/.local/share/applications/where-is-my-file.desktop" \
      "$HOME/.local/share/applications/brax-me.desktop" \
      "$HOME/.local/share/icons/brax-me.png" \
      "$HOME/.local/share/backgrounds/human-linux-wallpaper.jpg"
rm -f "$HOME/.local/share/applications"/human-linux-appimage-*.desktop \
      "$HOME/.local/bin/sh-launcher" \
      "$HOME/.local/share/applications/sh-launcher.desktop"
xdg-mime default org.gnome.TextEditor.desktop text/x-shellscript 2>/dev/null || true
xdg-mime default org.gnome.TextEditor.desktop application/x-shellscript 2>/dev/null || true
systemctl --user daemon-reload 2>/dev/null || true

log "Lid rule and IPv4 preference"
if gsettings list-keys org.gnome.settings-daemon.plugins.power 2>/dev/null | grep -q lid-close-ac-action; then
  gsettings set org.gnome.settings-daemon.plugins.power lid-close-ac-action 'suspend' || true
  gsettings set org.gnome.settings-daemon.plugins.power lid-close-battery-action 'suspend' || true
fi
sudo rm -f /etc/systemd/logind.conf.d/human-linux-lid.conf
if [[ -f /etc/gai.conf ]]; then
  sudo sed -i '/human-linux-ipv4/d' /etc/gai.conf
fi

nautilus -q 2>/dev/null || true
log "Uninstall done. Packages were left installed. Dock, scale, and pins were left as they are."
echo "Lid file is removed. It applies on the next reboot. logind was not restarted."
echo "IPv6 is preferred again."
