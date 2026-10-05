# Linux Is a Pain. Let's Fix It.

These are usability problems that show up on almost every distro. A new user hits one, decides Linux cannot be changed, and goes back to Windows.

The fix is one script. Run it once after a fresh install. It is a compilation of long use, plus the easy privacy setup, not a new distro. Nothing here is destructive. `uninstall.sh` reverses the pieces that are not already in Settings.

Advanced or beginner, you can see what each change does before you rely on it. The idea is the same kind of script Chris Titus uses for Windows. This one is for Linux.

## Supported

- Ubuntu GNOME
- Zorin
- Linux Mint Cinnamon, MATE, and Xfce
- Pop!_OS COSMIC, and older Pop still on GNOME
- Fedora Workstation

## Install

The first run is the one time you need a terminal. After that, deb files, AppImages, and `.sh` files can be opened from Files.

```bash
wget -qO- https://brax.me/linuxinstall/install.sh | bash
```

You are asked for your password once. The rest is automatic. The script does not restart logind.

Undo the script changes:

```bash
wget -qO- https://brax.me/linuxinstall/uninstall.sh | bash
```

Uninstall does not remove apps. It removes the Media and AppFiles links, the Files favorites, the IPv4 default, and the lid-close rule. Dock, wallpaper, and other visual choices stay. Change those in Settings.

The script location is fixed and can be versioned. Run it first on a new install. Suggestions belong in the Brax.me community.

## 1. App installation

Deb files. On Ubuntu a downloaded `.deb` often opens in File Roller, the archive tool, so a double-click does nothing. The script installs GDebi and points `.deb` files at it. Double-click, and it installs.

AppImages. There is no installer. You are expected to move the file, chmod it, and remember the folder. The script copies an AppImage to `~/Documents/AppFiles` and adds a Show Apps launcher.

Flatpak by default. Snap hides files. An OBS recording does not land in Videos. It lands under `~/snap`. The script installs Flatpak and Flathub so new apps can come from there. Snap stays installed. Ubuntu still uses it for some preinstalled apps.

## 2. Click a .sh file

Files opens a shell script in the text editor. The beginner path is `cd`, `chmod +x`, and `./script.sh`. The script replaces that opener with a window: Run or Edit. Run sets execute permission and starts a terminal, where a password can be entered. Edit opens the text editor. The file does not start until you press Run.

## 3. Where is my media?

A USB stick or extra partition may be mounted under `/media/$USER` or `/run/media/$USER`, or not mounted at all. The script links those disks under `~/Media`, in the home tree with Documents and Videos. A watcher refreshes the links when a drive is plugged in. Files gets a Media bookmark. A phone shows up under Media too.

## 4. Where are the app files?

Snap and Flatpak files are linked into `~/Documents/AppFiles`, and that folder is bookmarked in Files. OBS output is linked at `~/Videos/OBS`, which is where a recording should be.

## 5. Find my file

Show Apps gets Find my file. It searches your user folders, including Documents, Media, and AppFiles. It does not search system folders.

## 6. Browser isolation

Google sites stay in Chrome. Everything else stays in Brave, where you are not logged into Google. Firefox stays installed as the spare browser. The script installs Chrome and Brave if they are missing. If they are already installed, it leaves them.

## 7. Needed apps

- KeePassXC, for passwords and encrypted notes.
- KolourPaint, a simple Paint-style app. Not GIMP.
- Brax.me, a Show Apps launcher for the community.
- VLC, so common media files play.

Firefox, Thunderbird, and LibreOffice are already on most of these distros. The script fills the gaps.

## 8. Defaults and pins

`mailto` opens Thunderbird. The dock or menu pins Brave, Chrome, Thunderbird, KeePassXC, Writer, Files, Calculator, Text Editor, and Terminal. VLC is the default for mp4, mkv, avi, and webm. The common codecs are installed so those files are not missing a decoder.

## 9. Look like other desktops

Ubuntu's dock starts on the left. The script moves it to the bottom, centered, with an icon size for the screen, and only if you have not already moved it. The stock wallpaper is replaced only if it is still the distro default. Screen scale is set from the resolution if you have not already changed it, so text is not tiny. Terminal colors and size are not changed automatically.

## 10. System settings

Lid close. Settings has no useful control. On AC power the lid does not suspend. On battery it does. The system part applies on the next reboot.

IPv4. On a dual-stack network the machine prefers IPv4, so IPv6 is not the path used for tracking or a VPN leak. This is the normal home default, including Starlink CGNAT. An IPv6-only network, such as some hotel or airport Wi-Fi, can be exempted per connection in Network Manager. It is not a permanent block.
