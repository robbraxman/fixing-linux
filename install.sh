#!/usr/bin/env bash
# Human Linux — install
# Ubuntu, Zorin, Mint (Cinnamon, MATE, Xfce), Pop COSMIC, Fedora Workstation.
# Video line:
#   wget -qO- https://raw.githubusercontent.com/robbraxman/fixing-linux/main/install.sh | bash
#
# Change SCALE if 1.25 is wrong. Wallpaper applies only if the current one is still a distro default.
# Mint's file manager may run this with sh. That fails on lines 9, 17, and 23.
if [ -z "${BASH_VERSION:-}" ]; then
  exec bash "$0" "$@"
fi
# Double-click in Files does nothing useful. Use install.desktop, or run in a terminal.
if [[ ! -t 1 ]]; then
  zenity --question --width=420 --title="Human Linux" \
    --text="This installs KeePassXC, KolourPaint, Chrome, VLC, Thunderbird, GDebi, Disks, and Flatpak.\n\nIt also sets folders, the dock, the lid rule, and Find my file.\n\nA terminal will open so you can enter your password. Continue?" \
    || exit 0
  term="$(command -v gnome-terminal || command -v x-terminal-emulator || true)"
  [[ -n "$term" ]] || { zenity --error --text="No terminal found."; exit 1; }
  exec "$term" -- bash -c "\"$0\"; echo; read -r -p 'Press Enter to close.'"
fi
set -euo pipefail

SCALE="1.25"
WALLPAPER_URL="https://brax.me/readylinux/wallpaper.jpg"
BRAX_ICON_URL="https://brax.me/img/logo-b1a.png"
BRAX_URL="https://brax.me"

log()  { printf '\n==> %s\n' "$*"; }
warn() { printf '!!  %s\n' "$*" >&2; }
need_cmd() { command -v "$1" >/dev/null 2>&1; }

if [[ "$(id -u)" -eq 0 ]]; then
  warn "Run as your user, not root. The script will ask for sudo."
  exit 1
fi

desktop_session() {
  printf '%s\n' "${XDG_CURRENT_DESKTOP:-${DESKTOP_SESSION:-unknown}}"
}

# ---------------------------------------------------------------------------
# System packages (one sudo)
# ---------------------------------------------------------------------------
log "Installing packages"
. /etc/os-release
case "${ID:-}" in
  fedora)
    sudo dnf install -y \
      curl ca-certificates wget gnupg2 \
      zenity flatpak \
      keepassxc kolourpaint thunderbird vlc gnome-text-editor gnome-disk-utility
    if ! rpm -q google-chrome-stable >/dev/null 2>&1; then
      log "Adding Google Chrome"
      sudo dnf install -y https://dl.google.com/linux/direct/google-chrome-stable_current_x86_64.rpm
    fi
    ;;
  *)
    sudo apt-get update
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
      curl ca-certificates wget gnupg \
      zenity flatpak gdebi gnome-disk-utility \
      keepassxc kolourpaint thunderbird vlc
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y gnome-text-editor 2>/dev/null \
      || sudo DEBIAN_FRONTEND=noninteractive apt-get install -y gedit 2>/dev/null \
      || true
    if [[ "${XDG_CURRENT_DESKTOP:-}${DESKTOP_SESSION:-}" == *[Cc]innamon* ]]; then
      sudo DEBIAN_FRONTEND=noninteractive apt-get install -y xed || true
    fi
    if ! dpkg -s google-chrome-stable >/dev/null 2>&1; then
      log "Adding Google Chrome"
      sudo mkdir -p /usr/share/keyrings /tmp
      curl -fsSL -o /tmp/google-chrome.pub https://dl.google.com/linux/linux_signing_key.pub
      sudo rm -f /usr/share/keyrings/google-chrome.gpg
      sudo gpg --batch --yes --dearmor -o /usr/share/keyrings/google-chrome.gpg /tmp/google-chrome.pub
      echo "deb [arch=amd64 signed-by=/usr/share/keyrings/google-chrome.gpg] https://dl.google.com/linux/chrome/deb/ stable main" \
        | sudo tee /etc/apt/sources.list.d/google-chrome.list >/dev/null
      sudo apt-get update
      sudo DEBIAN_FRONTEND=noninteractive apt-get install -y google-chrome-stable
    fi
    if ! dpkg -s brave-browser >/dev/null 2>&1; then
      log "Adding Brave"
      sudo mkdir -p /usr/share/keyrings
      curl -fsSL -o /tmp/brave-browser-archive-keyring.gpg \
        https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg
      sudo cp /tmp/brave-browser-archive-keyring.gpg /usr/share/keyrings/brave-browser-archive-keyring.gpg
      echo "deb [signed-by=/usr/share/keyrings/brave-browser-archive-keyring.gpg] https://brave-browser-apt-release.s3.brave.com/ stable main" \
        | sudo tee /etc/apt/sources.list.d/brave-browser-release.list >/dev/null
      sudo apt-get update
      sudo DEBIAN_FRONTEND=noninteractive apt-get install -y brave-browser
    fi
    ;;
esac

if ! flatpak remotes | grep -q flathub; then
  sudo flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
fi

# Ubuntu Snap Thunderbird stores mail outside the apt profile.
# Copy it when the apt profile is missing or still blank. Do not overwrite accounts.
snap_tb="$HOME/snap/thunderbird/common/.thunderbird"
if [[ -f "$snap_tb/profiles.ini" ]]; then
  blank=1
  if [[ -f "$HOME/.thunderbird/profiles.ini" ]]; then
    if grep -Rqs 'mail.accountmanager.accounts' "$HOME/.thunderbird" 2>/dev/null \
       && grep -Rqs 'mail.accountmanager.accounts=.*[a-zA-Z0-9]' "$HOME/.thunderbird" 2>/dev/null; then
      blank=0
    fi
  fi
  if [[ "$blank" == "1" ]]; then
    log "Copying Snap Thunderbird profile into the blank apt profile"
    mkdir -p "$HOME/.thunderbird"
    cp -a "$snap_tb"/. "$HOME/.thunderbird"/
  fi
fi
if [[ -f /etc/gai.conf ]] && grep -q 'human-linux-ipv4' /etc/gai.conf; then
  log "IPv4 preference already set"
else
  log "Prefer IPv4, leave IPv6 available"
  echo "precedence ::ffff:0:0/96  100  # human-linux-ipv4" | sudo tee -a /etc/gai.conf >/dev/null
fi

# Lid: suspend on battery, awake on AC and dock. Do not restart logind.
log "Lid close rule (applies on next reboot)"
sudo mkdir -p /etc/systemd/logind.conf.d
sudo tee /etc/systemd/logind.conf.d/human-linux-lid.conf >/dev/null <<'EOF'
[Login]
HandleLidSwitch=suspend
HandleLidSwitchExternalPower=ignore
HandleLidSwitchDocked=ignore
EOF

# ---------------------------------------------------------------------------
# Folders, links, bookmarks
# ---------------------------------------------------------------------------
refresh_media_links() {
  local user src d gvfs mtp line dev mp fstype
  user="$(id -un)"
  mkdir -p "$HOME/Media/Disks"
  # Mount extra data partitions (NVMe, internal). Skip system, swap, and optical.
  if command -v lsblk >/dev/null && command -v udisksctl >/dev/null; then
    while read -r dev fstype label mp; do
      [[ -n "$dev" && -n "$fstype" ]] || continue
      [[ "$fstype" == "swap" || "$fstype" == "iso9660" ]] && continue
      case "$mp" in
        /|/boot|/boot/efi|/home) continue ;;
      esac
      [[ -n "$mp" ]] && continue
      case "${label,,}" in
        boot|efi|esp|system|recovery|winre|winre_drv|"microsoft reserved"|reserved) continue ;;
      esac
      udisksctl mount -b "$dev" >/dev/null 2>&1 || true
    done < <(lsblk -pnr -o PATH,FSTYPE,LABEL,MOUNTPOINT)
  fi
  find "$HOME/Media/Disks" -maxdepth 1 -type l -delete 2>/dev/null || true
  find "$HOME/Media/USB" -maxdepth 1 -type l -delete 2>/dev/null || true
  rmdir "$HOME/Media/USB" 2>/dev/null || true
  for src in "/media/$user" "/run/media/$user"; do
    [[ -d "$src" ]] || continue
    for d in "$src"/*; do
      [[ -e "$d" ]] || continue
      case "$(basename "$d" | tr '[:upper:]' '[:lower:]')" in
        boot|efi|esp|system|recovery|winre|winre_drv) continue ;;
      esac
      ln -sfn "$d" "$HOME/Media/Disks/$(basename "$d")"
    done
  done
  gvfs="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/gvfs"
  rm -f "$HOME/Media/Phone"
  if [[ -d "$gvfs" ]]; then
    mtp="$(find "$gvfs" -maxdepth 1 \( -iname '*mtp*' -o -iname '*gphoto*' -o -iname '*afc*' \) 2>/dev/null | head -n1 || true)"
    if [[ -n "${mtp:-}" && -e "$mtp" ]]; then
      ln -sfn "$mtp" "$HOME/Media/Phone"
    fi
  fi
}

refresh_appfiles() {
  local dest="$HOME/Documents/AppFiles" d name
  mkdir -p "$dest" "$dest/debs" "$dest/rpms" "$dest/appimages"
  if [[ -d "$HOME/snap" ]]; then
    for d in "$HOME/snap"/*; do
      [[ -d "$d" ]] || continue
      name="$(basename "$d")"
      [[ "$name" == "README" ]] && continue
      [[ -e "$d/current" ]] && ln -sfn "$d/current" "$dest/${name}"
      [[ -d "$d/common" ]] && ln -sfn "$d/common" "$dest/${name}-common"
    done
  fi
  if [[ -d "$HOME/.var/app" ]]; then
    for d in "$HOME/.var/app"/*; do
      [[ -d "$d" ]] || continue
      name="$(basename "$d")"
      ln -sfn "$d" "$dest/flatpak-${name}"
    done
  fi
  if [[ -d "$HOME/Downloads" ]]; then
    for d in "$HOME/Downloads"/*.deb "$HOME/Downloads"/*.Deb; do
      [[ -e "$d" ]] || continue
      ln -sfn "$d" "$dest/debs/$(basename "$d")"
    done
    for d in "$HOME/Downloads"/*.rpm "$HOME/Downloads"/*.RPM; do
      [[ -e "$d" ]] || continue
      ln -sfn "$d" "$dest/rpms/$(basename "$d")"
    done
  fi
}

bookmark() {
  local uri="$1" label="$2" f
  for f in "$HOME/.config/gtk-3.0/bookmarks" "$HOME/.config/gtk-4.0/bookmarks"; do
    mkdir -p "$(dirname "$f")"
    touch "$f"
    grep -qF "$uri" "$f" || echo "$uri $label" >> "$f"
  done
}

log "Folders and sidebar"
xdg-user-dirs-update || true
mkdir -p "$HOME/Media/Disks" "$HOME/Videos/OBS" "$HOME/Documents/AppFiles"
refresh_media_links
refresh_appfiles
bookmark "file://$HOME/Media" "Media"
bookmark "file://$HOME/Documents/AppFiles" "AppFiles"
bookmark "file:///" "File System"

# ---------------------------------------------------------------------------
# USB watcher
# ---------------------------------------------------------------------------
log "USB watcher"
mkdir -p "$HOME/.local/bin" "$HOME/.config/systemd/user"
cat > "$HOME/.local/bin/human-linux-usb-watch" <<'EOF'
#!/usr/bin/env bash
refresh() {
  local user src d gvfs mtp dev mp fstype
  user="$(id -un)"
  mkdir -p "$HOME/Media/Disks"
  if command -v lsblk >/dev/null && command -v udisksctl >/dev/null; then
    while read -r dev fstype label mp; do
      [[ -n "$dev" && -n "$fstype" ]] || continue
      [[ "$fstype" == "swap" || "$fstype" == "iso9660" ]] && continue
      case "$mp" in
        /|/boot|/boot/efi|/home) continue ;;
      esac
      [[ -n "$mp" ]] && continue
      case "${label,,}" in
        boot|efi|esp|system|recovery|winre|winre_drv|"microsoft reserved"|reserved) continue ;;
      esac
      udisksctl mount -b "$dev" >/dev/null 2>&1 || true
    done < <(lsblk -pnr -o PATH,FSTYPE,LABEL,MOUNTPOINT)
  fi
  find "$HOME/Media/Disks" -maxdepth 1 -type l -delete 2>/dev/null || true
  find "$HOME/Media/USB" -maxdepth 1 -type l -delete 2>/dev/null || true
  rmdir "$HOME/Media/USB" 2>/dev/null || true
  for src in "/media/$user" "/run/media/$user"; do
    [[ -d "$src" ]] || continue
    for d in "$src"/*; do
      [[ -e "$d" ]] || continue
      case "$(basename "$d" | tr '[:upper:]' '[:lower:]')" in
        boot|efi|esp|system|recovery|winre|winre_drv) continue ;;
      esac
      ln -sfn "$d" "$HOME/Media/Disks/$(basename "$d")"
    done
  done
  gvfs="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/gvfs"
  rm -f "$HOME/Media/Phone"
  if [[ -d "$gvfs" ]]; then
    mtp="$(find "$gvfs" -maxdepth 1 \( -iname '*mtp*' -o -iname '*gphoto*' -o -iname '*afc*' \) 2>/dev/null | head -n1 || true)"
    if [[ -n "${mtp:-}" && -e "$mtp" ]]; then
      ln -sfn "$mtp" "$HOME/Media/Phone"
    fi
  fi
}
refresh
udisksctl monitor | while read -r line; do
  case "$line" in
    *Added*|*Removed*|*mounted*|*unmounted*) refresh ;;
  esac
done
EOF
chmod +x "$HOME/.local/bin/human-linux-usb-watch"
cat > "$HOME/.config/systemd/user/human-linux-usb-watch.service" <<EOF
[Unit]
Description=Refresh Human Linux Media links
[Service]
ExecStart=$HOME/.local/bin/human-linux-usb-watch
Restart=on-failure
EOF
systemctl --user disable --now usb-watch.service 2>/dev/null || true
rm -f "$HOME/.config/systemd/user/usb-watch.service" "$HOME/.local/bin/usb-watch"
systemctl --user daemon-reload || true
systemctl --user enable human-linux-usb-watch.service || true
systemctl --user restart human-linux-usb-watch.service || warn "Disk watcher not started. Log in on the desktop and rerun."

# ---------------------------------------------------------------------------
# Find my file
# ---------------------------------------------------------------------------
log "Find my file"
cat > "$HOME/.local/bin/where-is-my-file" <<'EOF'
#!/usr/bin/env bash
q="${1:-}"
[[ -n "$q" ]] || { echo "usage: where-is-my-file <name>"; exit 1; }
roots=(
  "$HOME/Documents" "$HOME/Downloads" "$HOME/Videos" "$HOME/Pictures"
  "$HOME/Desktop" "$HOME/Media" "$HOME/Documents/AppFiles"
  "$HOME/snap" "$HOME/.var/app"
)
find "${roots[@]}" -iname "*${q}*" 2>/dev/null | head -n 50
EOF
chmod +x "$HOME/.local/bin/where-is-my-file"
cat > "$HOME/.local/bin/where-is-my-file-gui" <<'EOF'
#!/usr/bin/env bash
q="$(zenity --entry --title="Find my file" --text="Name or part of a name")" || exit 0
[[ -z "$q" ]] && exit 0
hits="$("$HOME/.local/bin/where-is-my-file" "$q")"
if [[ -z "$hits" ]]; then
  zenity --info --title="Find my file" --text="No matches for: $q"
  exit 0
fi
zenity --text-info --title="Find my file: $q" --width=700 --height=400 <<< "$hits"
EOF
chmod +x "$HOME/.local/bin/where-is-my-file-gui"
mkdir -p "$HOME/.local/share/applications"
cat > "$HOME/.local/share/applications/where-is-my-file.desktop" <<EOF
[Desktop Entry]
Name=Find my file
Comment=Search Documents, Media, Snap and Flatpak folders
Exec=$HOME/.local/bin/where-is-my-file-gui
Terminal=false
Type=Application
Icon=system-search
Categories=Utility;
X-Human-Linux=true
EOF

# ---------------------------------------------------------------------------
# AppImage launchers
# ---------------------------------------------------------------------------
log "AppImage launchers"
shopt -s nullglob
for d in "$HOME/Downloads"/*.AppImage "$HOME/Downloads"/*.appimage \
         "$HOME/Applications"/*.AppImage "$HOME/Applications"/*.appimage \
         "$HOME/Documents/AppFiles"/*.AppImage; do
  [[ -f "$d" ]] || continue
  chmod +x "$d" || true
  base="$(basename "$d")"
  name="${base%.[Aa]pp[Ii]mage}"
  ln -sfn "$d" "$HOME/Documents/AppFiles/appimages/$base"
  cat > "$HOME/.local/share/applications/human-linux-appimage-${name}.desktop" <<EOF
[Desktop Entry]
Name=$name
Exec=$d
Terminal=false
Type=Application
Icon=application-x-executable
Categories=Utility;
X-Human-Linux=true
EOF
done
shopt -u nullglob

# ---------------------------------------------------------------------------
# Brax.me
# ---------------------------------------------------------------------------
log "Brax.me launcher"
browser="$(command -v brave-browser || command -v google-chrome-stable || command -v google-chrome || true)"
if [[ -n "$browser" ]]; then
  mkdir -p "$HOME/.local/share/icons"
  curl -fsSL -o "$HOME/.local/share/icons/brax-me.png" "$BRAX_ICON_URL" || warn "Brax icon download failed"
  cat > "$HOME/.local/share/applications/brax-me.desktop" <<EOF
[Desktop Entry]
Name=Brax.me
Comment=brax.me
Exec=$browser --app=$BRAX_URL
Icon=$HOME/.local/share/icons/brax-me.png
Terminal=false
Type=Application
Categories=Network;
StartupNotify=true
X-Human-Linux=true
EOF
fi

# ---------------------------------------------------------------------------
# Defaults
# ---------------------------------------------------------------------------
desktop_id_exists() {
  local id="$1" f
  for f in "/usr/share/applications/${id}" "$HOME/.local/share/applications/${id}" \
           "/var/lib/flatpak/exports/share/applications/${id}"; do
    [[ -f "$f" ]] && return 0
  done
  return 1
}
first_existing_desktop() {
  local id
  for id in "$@"; do
    if desktop_id_exists "$id"; then
      printf '%s\n' "$id"
      return 0
    fi
  done
  return 1
}

log "Default browser and mail"
if id="$(first_existing_desktop brave-browser.desktop com.brave.Browser.desktop)"; then
  xdg-settings set default-web-browser "$id" || true
  xdg-mime default "$id" x-scheme-handler/http || true
  xdg-mime default "$id" x-scheme-handler/https || true
  xdg-mime default "$id" text/html || true
else
  warn "Brave not installed; default browser unchanged"
fi
if id="$(first_existing_desktop thunderbird.desktop org.mozilla.Thunderbird.desktop)"; then
  xdg-mime default "$id" x-scheme-handler/mailto || true
fi
if id="$(first_existing_desktop vlc.desktop)"; then
  for mime in video/mp4 video/x-matroska video/x-msvideo video/webm; do
    xdg-mime default "$id" "$mime" || true
  done
fi
if id="$(first_existing_desktop gnome-disk-image-writer.desktop org.gnome.DiskUtility.desktop)"; then
  mkdir -p "$HOME/.local/bin" "$HOME/.local/share/applications"
  cat > "$HOME/.local/bin/open-iso" <<'EOF'
#!/usr/bin/env bash
iso="${1:-}"
[[ -n "$iso" && -f "$iso" ]] || exit 1
real="$(readlink -f "$iso")"
# Files mounts the ISO on click. Disk Image Writer errors if it is mounted.
while read -r loop back; do
  [[ "$back" == "$real" ]] || continue
  udisksctl unmount -b "$loop" >/dev/null 2>&1 || umount -l "$loop" >/dev/null 2>&1 || true
  udisksctl loop-delete -b "$loop" >/dev/null 2>&1 || losetup -d "$loop" >/dev/null 2>&1 || true
done < <(losetup -lnO NAME,BACK-FILE 2>/dev/null || true)
# A restore fails if the USB stick is still mounted. Unmount removable disks only.
while read -r dev rm; do
  [[ "$rm" == "1" ]] || continue
  while read -r part mp; do
    [[ -n "$mp" ]] || continue
    udisksctl unmount -b "$part" >/dev/null 2>&1 || umount -l "$part" >/dev/null 2>&1 || true
  done < <(lsblk -pnr -o PATH,MOUNTPOINT "$dev")
done < <(lsblk -dnr -o PATH,RM)
if command -v gnome-disk-image-writer >/dev/null; then
  exec gnome-disk-image-writer "$iso"
fi
exec gnome-disks
EOF
  chmod +x "$HOME/.local/bin/open-iso"
  cat > "$HOME/.local/share/applications/open-iso.desktop" <<EOF
[Desktop Entry]
Name=Write ISO to USB
Exec=$HOME/.local/bin/open-iso %f
Terminal=false
Type=Application
MimeType=application/x-cd-image;application/x-iso9660-image;application/vnd.efi.iso;application/x-raw-disk-image;
NoDisplay=true
X-Human-Linux=true
EOF
  for mime in application/x-cd-image application/x-iso9660-image application/vnd.efi.iso application/x-raw-disk-image; do
    xdg-mime default open-iso.desktop "$mime" || true
  done
fi

# ---------------------------------------------------------------------------
# Dock, scale, wallpaper, lid (session)
# ---------------------------------------------------------------------------
log "Session settings"
de="$(desktop_session | tr '[:upper:]' '[:lower:]')"

pin_gnome() {
  need_cmd gsettings || return 0
  need_cmd python3 || return 0
  local schema="$1"
  local files="$2"
  local editor="$3"
  gsettings writable "$schema" favorite-apps >/dev/null 2>&1 || return 0
  gsettings list-keys "$schema" 2>/dev/null | grep -qx favorite-apps || return 0
  python3 - "$schema" "$files" "$editor" <<'PY'
import ast, subprocess, sys
schema, files, editor = sys.argv[1:]
wanted = [
  "brave-browser.desktop",
  "google-chrome.desktop",
  "firefox.desktop",
  "firefox_firefox.desktop",
  "thunderbird.desktop",
  "org.keepassxc.KeePassXC.desktop",
  "libreoffice-writer.desktop",
  editor,
  files,
  "org.gnome.Calculator.desktop",
  "org.gnome.Terminal.desktop",
]
raw = subprocess.check_output(["gsettings", "get", schema, "favorite-apps"], text=True)
try:
    cur = ast.literal_eval(raw.strip())
except Exception:
    cur = []
if not isinstance(cur, list):
    cur = []
rest = [x for x in cur if x not in wanted]
out = wanted + rest
repr_out = "[" + ", ".join("'" + x.replace("'", "") + "'" for x in out) + "]"
subprocess.check_call(["gsettings", "set", schema, "favorite-apps", repr_out])
print("pinned", repr_out)
PY
}

case "$de" in
  *cosmic*)
    log "COSMIC dock and Files sidebar"
    fav="$HOME/.config/cosmic/com.system76.CosmicAppList/v1/favorites"
    mkdir -p "$(dirname "$fav")"
    python3 - "$fav" <<'PY' || true
import json, os, sys
path = sys.argv[1]
wanted = [
  "brave-browser", "google-chrome", "firefox", "thunderbird",
  "org.keepassxc.KeePassXC", "libreoffice-writer", "com.system76.CosmicEdit",
  "com.system76.CosmicFiles", "org.gnome.Calculator",
  "com.system76.CosmicStore", "com.system76.CosmicSettings",
  "com.system76.CosmicTerm",
]
cur = []
if os.path.exists(path):
    try:
        cur = json.load(open(path))
    except Exception:
        cur = []
if not isinstance(cur, list):
    cur = []
rest = [x for x in cur if x not in wanted]
cur = wanted + rest
json.dump(cur, open(path, "w"), indent=4)
print("cosmic dock", cur)
PY
    files_cfg="$HOME/.config/cosmic/com.system76.CosmicFiles/v1/config.ron"
    if [[ -f "$files_cfg" ]]; then
      grep -q "$HOME/Media" "$files_cfg" || sed -i "s/favorites: \[/favorites: [\n        Path(\"$HOME\/Media\"),\n        Path(\"$HOME\/Documents\/AppFiles\"),/" "$files_cfg" || true
    fi
    ;;
  *cinnamon*)
    log "Cinnamon panel pins"
    python3 - <<'PY' || true
import json
from pathlib import Path
wanted = [
  "brave-browser.desktop", "google-chrome.desktop", "firefox.desktop",
  "thunderbird.desktop", "org.keepassxc.KeePassXC.desktop",
  "libreoffice-writer.desktop",
]
for editor in ("xed.desktop", "org.gnome.TextEditor.desktop", "gedit.desktop"):
    if Path("/usr/share/applications", editor).is_file():
        wanted.append(editor)
        break
wanted += ["nemo.desktop", "org.gnome.Calculator.desktop", "org.gnome.Terminal.desktop"]
roots = [
  Path.home() / ".config/cinnamon/spices/grouped-window-list@cinnamon.org",
  Path.home() / ".cinnamon/configs/grouped-window-list@cinnamon.org",
]
files = []
for root in roots:
    if root.is_dir():
        files.extend(root.glob("*.json"))
if not files:
    print("no cinnamon panel config")
else:
    for f in files:
        try:
            data = json.loads(f.read_text())
        except Exception:
            continue
        pin = data.get("pinned-apps")
        cur = []
        if isinstance(pin, dict):
            cur = pin.get("value") or pin.get("default") or []
            pin["value"] = wanted + [x for x in cur if x not in wanted]
        elif isinstance(pin, list):
            data["pinned-apps"] = wanted + [x for x in pin if x not in wanted]
        else:
            data["pinned-apps"] = {"value": wanted}
        f.write_text(json.dumps(data, indent=4))
        print("cinnamon panel", f)
PY
    # The running panel keeps the old list until it is reloaded.
    cinnamon --replace >/dev/null 2>&1 &
    ;;
  *mate*)
    log "MATE menu pins"
    if gsettings list-schemas | grep -qx 'com.linuxmint.mintmenu.plugins.applications'; then
      python3 - <<'PY' || true
import ast, subprocess
schema = "com.linuxmint.mintmenu.plugins.applications"
key = "favorite-apps-list"
wanted = [
  "brave-browser.desktop", "google-chrome.desktop", "firefox.desktop",
  "thunderbird.desktop", "org.keepassxc.KeePassXC.desktop",
  "libreoffice-writer.desktop", "pluma.desktop", "caja.desktop",
  "org.gnome.Calculator.desktop", "mate-terminal.desktop",
]
raw = subprocess.check_output(["gsettings", "get", schema, key], text=True).strip()
try:
    cur = ast.literal_eval(raw)
except Exception:
    cur = []
if not isinstance(cur, list):
    cur = []
rest = [x for x in cur if x not in wanted]
out = wanted + rest
repr_out = "[" + ", ".join("'" + x.replace("'", "") + "'" for x in out) + "]"
subprocess.check_call(["gsettings", "set", schema, key, repr_out])
print("mate pins", repr_out)
PY
    fi
    ;;
  *xfce*)
    log "Xfce Whisker pins"
    python3 - <<'PY' || true
from pathlib import Path
wanted = [
  "brave-browser.desktop", "google-chrome.desktop", "firefox.desktop",
  "thunderbird.desktop", "org.keepassxc.KeePassXC.desktop",
  "libreoffice-writer.desktop", "mousepad.desktop", "thunar.desktop",
  "org.gnome.Calculator.desktop", "xfce4-terminal.desktop",
]
files = list(Path.home().joinpath(".config/xfce4/panel").glob("whiskermenu-*.rc"))
if not files:
    print("no whisker menu config")
else:
    for f in files:
        lines = f.read_text().splitlines()
        cur = []
        idx = None
        for i, line in enumerate(lines):
            if line.startswith("favorites="):
                idx = i
                cur = [x for x in line.split("=", 1)[1].split(",") if x]
        rest = [x for x in cur if x not in wanted]
        new = "favorites=" + ",".join(wanted + rest)
        if idx is None:
            lines.append(new)
        else:
            lines[idx] = new
        f.write_text("\n".join(lines) + "\n")
        print("xfce pins", f)
PY
    ;;
  *kde*|*plasma*)
    log "KDE places. Panel pins are not the Ubuntu dock, so they are left as they are."
    xbel="$HOME/.local/share/user-places.xbel"
    mkdir -p "$HOME/.local/share"
    if [[ ! -f "$xbel" ]]; then
      printf '%s\n' '<?xml version="1.0" encoding="UTF-8"?>' '<xbel version="1.0">' '</xbel>' > "$xbel"
    fi
    for pair in "$HOME/Media|Media" "$HOME/Documents/AppFiles|AppFiles"; do
      uri="file://${pair%%|*}"
      label="${pair##*|}"
      grep -qF "$uri" "$xbel" || sed -i "s#</xbel># <bookmark href=\"$uri\"><title>$label</title></bookmark>\n</xbel>#" "$xbel"
    done
    ;;
  *)
    pin_gnome org.gnome.shell org.gnome.Nautilus.desktop org.gnome.TextEditor.desktop || true
    if gsettings list-schemas | grep -q 'org.gnome.shell.extensions.dash-to-dock'; then
      pos="$(gsettings get org.gnome.shell.extensions.dash-to-dock dock-position 2>/dev/null || echo '')"
      if [[ "$pos" == "'LEFT'" ]]; then
        gsettings set org.gnome.shell.extensions.dash-to-dock dock-position 'BOTTOM' || true
        gsettings set org.gnome.shell.extensions.dash-to-dock extend-height false || true
      fi
      size="$(gsettings get org.gnome.shell.extensions.dash-to-dock dash-max-icon-size 2>/dev/null || echo '')"
      if [[ "$size" == "48" ]]; then
        gsettings set org.gnome.shell.extensions.dash-to-dock dash-max-icon-size 32 || true
      fi
    fi
    ;;
esac

if gsettings list-keys org.gnome.settings-daemon.plugins.power 2>/dev/null | grep -q lid-close-ac-action; then
  gsettings set org.gnome.settings-daemon.plugins.power lid-close-ac-action 'nothing' || true
  gsettings set org.gnome.settings-daemon.plugins.power lid-close-battery-action 'suspend' || true
fi

# Yaru paints the editor purple. Classic is a plain light page. 14pt is readable on a laptop.
if gsettings list-schemas | grep -qx 'org.gnome.TextEditor'; then
  gsettings set org.gnome.TextEditor style-scheme 'classic' || true
  gsettings set org.gnome.TextEditor use-system-font false || true
  gsettings set org.gnome.TextEditor custom-font 'Monospace 10' || true
elif gsettings list-schemas | grep -qx 'org.gnome.gedit.preferences.editor'; then
  gsettings set org.gnome.gedit.preferences.editor scheme 'classic' || true
  gsettings set org.gnome.gedit.preferences.editor use-default-font false || true
  gsettings set org.gnome.gedit.preferences.editor editor-font 'Monospace 12' || true
fi
if gsettings list-schemas | grep -qx 'org.x.editor.preferences.editor'; then
  gsettings set org.x.editor.preferences.editor use-default-font false || true
  gsettings set org.x.editor.preferences.editor editor-font 'Monospace 10' || true
fi

# Terminal frame is 110x34 on the distros we support.
# Newer Ubuntu uses Ptyxis. Zorin and Mint use GNOME Terminal.
if gsettings list-schemas | grep -qx 'org.gnome.Ptyxis'; then
  gsettings set org.gnome.Ptyxis default-columns 110 || true
  gsettings set org.gnome.Ptyxis default-rows 34 || true
  gsettings set org.gnome.Ptyxis use-system-font false || true
  gsettings set org.gnome.Ptyxis font-name 'Monospace 10' || true
  mkdir -p "$HOME/.local/share/org.gnome.Ptyxis/palettes"
  cat > "$HOME/.local/share/org.gnome.Ptyxis/palettes/kit-contrast.palette" <<'EOF'
[Palette]
Name=Kit Contrast

[Light]
Foreground=#FFFFFF
Background=#000000
Color7=#FFFFFF
Color15=#FFFFFF

[Dark]
Foreground=#FFFFFF
Background=#000000
Color7=#FFFFFF
Color15=#FFFFFF
EOF
  uuid="$(gsettings get org.gnome.Ptyxis default-profile-uuid 2>/dev/null | tr -d "'")"
  if [[ -n "$uuid" ]]; then
    profile="org.gnome.Ptyxis.Profile:/org/gnome/Ptyxis/Profiles/${uuid}/"
    gsettings set "$profile" palette 'Kit Contrast' || true
    gsettings set "$profile" opacity 1.0 || true
    gsettings set "$profile" cell-height-scale 1.0 || true
    gsettings set "$profile" cell-width-scale 1.0 || true
  fi
fi
if gsettings list-schemas | grep -qx 'org.gnome.Terminal.Legacy.Settings'; then
  python3 - <<'PY' || true
import subprocess
def setv(path, key, val):
    subprocess.check_call(["gsettings", "set", path, key, val])
raw = subprocess.check_output(["dconf", "list", "/org/gnome/terminal/legacy/profiles:/"], text=True)
uids = [line.strip("/:") for line in raw.splitlines() if line.strip()]
if not uids:
    print("gnome-terminal has no profile yet; size applies after the first terminal is closed and opened")
for uid in uids:
    path = f"org.gnome.Terminal.Legacy.Profile:/org/gnome/terminal/legacy/profiles:/:{uid}/"
    setv(path, "default-size-columns", "110")
    setv(path, "default-size-rows", "34")
    setv(path, "use-system-font", "false")
    setv(path, "font", "'Monospace 10'")
    setv(path, "use-theme-colors", "false")
    setv(path, "foreground-color", "'#FFFFFF'")
    setv(path, "background-color", "'#000000'")
    print("gnome-terminal next window 110x34", uid)
PY
  mkdir -p "$HOME/.local/share/applications"
  cat > "$HOME/.local/share/applications/org.gnome.Terminal.desktop" <<EOF
[Desktop Entry]
Name=Terminal
Exec=gnome-terminal --geometry=110x34
Icon=org.gnome.Terminal
Terminal=false
Type=Application
Categories=System;TerminalEmulator;
StartupNotify=true
EOF
fi

# 125% on a laptop or a 1080p-class screen. A desktop at 1440p or 4K stays at 100%.
primary_w="$(xrandr 2>/dev/null | awk '/ connected/{print $3; exit}' | cut -dx -f1)"
if [[ -d /sys/class/power_supply ]] && compgen -G /sys/class/power_supply/BAT* >/dev/null; then
  SCALE="1.25"
elif [[ -n "${primary_w:-}" && "$primary_w" -le 1920 ]]; then
  SCALE="1.25"
else
  SCALE="1.0"
fi
log "Screen scale $SCALE"
if gsettings writable org.gnome.desktop.interface text-scaling-factor >/dev/null 2>&1; then
  gsettings set org.gnome.desktop.interface text-scaling-factor "$SCALE" || true
fi
if gsettings writable org.cinnamon.desktop.interface text-scaling-factor >/dev/null 2>&1; then
  gsettings set org.cinnamon.desktop.interface text-scaling-factor "$SCALE" || true
fi
if gsettings writable org.cinnamon active-display-scale >/dev/null 2>&1; then
  gsettings set org.cinnamon active-display-scale "$SCALE" || true
fi
if [[ "$SCALE" == "1.25" && -f "$HOME/.config/cinnamon-monitors.xml" ]]; then
  sed -i 's/scale="0.75"/scale="1.25"/g; s/<scale>0.75<\/scale>/<scale>1.25<\/scale>/g' \
    "$HOME/.config/cinnamon-monitors.xml" || true
fi

if [[ -n "$WALLPAPER_URL" ]]; then
  current="$(gsettings get org.gnome.desktop.background picture-uri 2>/dev/null || echo '')"
  dark="$(gsettings get org.gnome.desktop.background picture-uri-dark 2>/dev/null || echo '')"
  if [[ "$current" == *"/usr/share/backgrounds/"* && "$dark" == *"/usr/share/backgrounds/"* ]]; then
    mkdir -p "$HOME/.local/share/backgrounds"
    if curl -fsSL -o "$HOME/.local/share/backgrounds/human-linux-wallpaper.jpg" "$WALLPAPER_URL"; then
      gsettings set org.gnome.desktop.background picture-uri "file://$HOME/.local/share/backgrounds/human-linux-wallpaper.jpg" || true
      gsettings set org.gnome.desktop.background picture-uri-dark "file://$HOME/.local/share/backgrounds/human-linux-wallpaper.jpg" || true
    else
      warn "Wallpaper download failed"
    fi
  else
    log "Wallpaper already chosen. Skipped."
  fi
else
  log "Wallpaper URL blank. Skipped."
fi

update-desktop-database "$HOME/.local/share/applications" 2>/dev/null || true

# Click a .sh in Files: Run or Edit, instead of opening the text editor.
log "Script launcher"
cat > "$HOME/.local/bin/sh-launcher" <<'EOF'
#!/usr/bin/env bash
f="${1:-}"
[[ -n "$f" && -f "$f" ]] || { zenity --error --text="No script given."; exit 1; }
zenity --question --width=420 --title="Script" \
  --ok-label="Run" --cancel-label="Edit" \
  --text="File: $f

Run starts this script.
Edit opens it in the text editor." || {
  if command -v gnome-text-editor >/dev/null; then exec gnome-text-editor "$f"
  elif command -v gedit >/dev/null; then exec gedit "$f"
  elif command -v xed >/dev/null; then exec xed "$f"
  elif command -v pluma >/dev/null; then exec pluma "$f"
  elif command -v mousepad >/dev/null; then exec mousepad "$f"
  else zenity --error --text="No text editor found."
  fi
  exit 0
}
chmod +x "$f" || true
if command -v gnome-terminal >/dev/null; then
  gnome-terminal -- bash -c "bash \"$f\"; echo; read -r -p 'Press Enter to close.'"
elif command -v kgx >/dev/null; then
  kgx -- bash -c "bash \"$f\"; echo; read -r -p 'Press Enter to close.'"
elif command -v x-terminal-emulator >/dev/null; then
  x-terminal-emulator -e bash -c "bash \"$f\"; echo; read -r -p 'Press Enter to close.'"
else
  zenity --error --text="No terminal program found."
fi
EOF
chmod +x "$HOME/.local/bin/sh-launcher"
cat > "$HOME/.local/share/applications/sh-launcher.desktop" <<EOF
[Desktop Entry]
Name=Script launcher
Exec=$HOME/.local/bin/sh-launcher %f
Terminal=false
Type=Application
MimeType=text/x-shellscript;application/x-shellscript;
NoDisplay=true
X-Human-Linux=true
EOF
xdg-mime default sh-launcher.desktop text/x-shellscript || true
xdg-mime default sh-launcher.desktop application/x-shellscript || true
# Nemo asks Run or Display before the default app. Launch skips that and opens ours.
if gsettings writable org.nemo.preferences executable-text-activation >/dev/null 2>&1; then
  gsettings set org.nemo.preferences executable-text-activation 'launch' || true
fi

# Clickable launchers. Files will not run a .sh; these .desktop files do.
if [[ -f "$0" ]]; then
  kit="$HOME/.local/share/human-linux"
  mkdir -p "$kit" "$HOME/.local/share/applications"
  cp -f "$0" "$kit/install.sh"
  chmod +x "$kit/install.sh"
  if [[ -f "$(dirname "$0")/uninstall.sh" ]]; then
    cp -f "$(dirname "$0")/uninstall.sh" "$kit/uninstall.sh"
    chmod +x "$kit/uninstall.sh"
  fi
  cat > "$HOME/.local/share/applications/human-linux-install.desktop" <<EOF
[Desktop Entry]
Name=Human Linux install
Comment=Preview, confirm, then run the install
Exec=$kit/install.sh
Terminal=false
Type=Application
Icon=system-software-install
Categories=Utility;
EOF
  cat > "$HOME/.local/share/applications/human-linux-uninstall.desktop" <<EOF
[Desktop Entry]
Name=Human Linux uninstall
Comment=Preview, confirm, then remove kit files
Exec=$kit/uninstall.sh
Terminal=false
Type=Application
Icon=user-trash
Categories=Utility;
EOF
  chmod +x "$HOME/.local/share/applications/human-linux-install.desktop" \
           "$HOME/.local/share/applications/human-linux-uninstall.desktop" || true
  gio set "$HOME/.local/share/applications/human-linux-install.desktop" metadata::trusted true 2>/dev/null || true
  gio set "$HOME/.local/share/applications/human-linux-uninstall.desktop" metadata::trusted true 2>/dev/null || true
fi

log "Done."
echo "Plug a USB stick in. It should appear under ~/Media/Disks after Ubuntu mounts it."
echo "Show Apps: Human Linux install, and Human Linux uninstall."
echo "Log out and back in if Show Apps or the dock did not update."
echo "Lid-on-AC applies fully after the next reboot. logind was not restarted."
