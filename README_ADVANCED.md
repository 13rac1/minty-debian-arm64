# Minty — Advanced: building & internals

For just *running* Minty on a Mac, see [README.md](README.md). This document
is for building the ISO yourself, customizing it, and understanding how it
works.

## What Minty is

`build.sh` turns a stock Debian 13 arm64 installer ISO into an unattended
installer for a Mint-like MATE desktop with the Mint-Y theme. Almost
everything comes from official Debian mirrors; the only exceptions are the
Mint-Y GTK theme and Mint-X icons (`mint-themes`, `mint-x-icons`) — arch:all
GPL data Debian does not carry — which `build.sh` fetches from the Linux
Mint package pool and bakes into the image. No third-party apt repository is
added to the installed system, and none of Linux Mint's logos or
artwork-branding are shipped.

The installed system is Debian 13 with MATE, themed Mint-Y-Dark (green
accent): the Mint-Y-Dark GTK theme, the adaptive Mint-Y Marco window
borders, Mint-Y icons, and the Bibata cursor. Plus the Mint-origin
applications Debian itself packages (slick-greeter, timeshift), guest agents
for VMs (spice-vdagent, spice-webdavd, qemu-guest-agent), and a UTM shared
folder that auto-mounts read/write at `~/Shared` (9p on the QEMU backend,
virtiofs on Apple Virtualization).

This is an installer image, not a live session — Debian publishes no arm64
live desktop images, so there is no try-before-install.

## Building

1. Download a Debian 13 arm64 installer ISO — netinst or DVD-1:
   <https://www.debian.org/distrib/> (e.g. `debian-13.6.0-arm64-netinst.iso`)
2. `git clone https://github.com/13rac1/minty-debian-arm64`
3. `./build.sh debian-13.6.0-arm64-netinst.iso`

Output: `minty-` + the input ISO's name (e.g.
`minty-debian-13.6.0-arm64-netinst.iso`; override with a second argument to
`build.sh`). `build.sh` refuses any ISO that is not Debian 13.

Build dependencies: `xorriso`, `cpio`, `gzip`, and `curl` or `wget`.
Runs on any Linux or macOS host, any architecture (only the target ISO is
arm64):

- Debian/Ubuntu: `sudo apt install xorriso` (cpio, gzip, wget are standard)
- macOS: `brew install xorriso` (curl, cpio, gzip are built in)

The released ISO is the **netinst**-based build (GitHub caps release assets
at 2 GB; the DVD-1 build is larger). It requires internet during install.

## Modes

**Default (semi-attended):** the installer still asks for language,
keyboard, hostname, user account, timezone, and — before touching anything
— the target disk. Everything else is automated. The root account is
disabled (no password); the user you create gets `sudo`.

**`--auto` (fully unattended):**

```
./build.sh --auto debian-13.6.0-arm64-netinst.iso
```

DANGER: erases the first disk without confirmation and creates user `minty`
with password `minty`. Only for VMs and machines you intend to wipe. Change
the password on first login.

## Network requirements

- **netinst input:** network required for the whole install.
- **DVD-1 input:** the MATE desktop installs from the disc; the Mint-origin
  packages are not on DVD-1 and install from the network mirror. With no
  network the result is a plain Debian MATE system — finish later with
  `sudo bash /opt/minty/setup.sh`.

## Testing in QEMU (without UTM)

```
qemu-img create -f qcow2 disk.qcow2 16G
qemu-system-aarch64 -M virt -cpu max -smp 4 -m 4096 \
  -drive if=pflash,format=raw,readonly=on,file=/usr/share/AAVMF/AAVMF_CODE.fd \
  -device virtio-gpu-pci -device qemu-xhci -device usb-kbd -device usb-tablet \
  -drive file=minty-debian-13.6.0-arm64-netinst.iso,media=cdrom \
  -drive file=disk.qcow2,if=virtio \
  -netdev user,id=n0 -device virtio-net-pci,netdev=n0 \
  -display gtk
```

AAVMF firmware is in the `qemu-efi-aarch64` package. Use `-accel kvm` and
`-cpu host` on arm64 hosts with KVM. On an Apple Silicon Mac, UTM or QEMU
run arm64 guests under Hypervisor.framework, no emulation.

## How it works

`build.sh` appends a cpio overlay (the `payload/` tree) to both installer
initrds inside the ISO, places the preseed file on the ISO filesystem,
patches `grub.cfg` to pass `file=/cdrom/preseed.cfg` to the kernel, and
repacks with xorriso in boot-image replay mode so the EFI boot structure is
preserved byte-for-byte. The preseed is loaded from the CD-ROM mount point
after hardware detection rather than auto-loaded from the initramfs root —
the early initramfs path runs before framebuffer init on QEMU ARM64,
blanking the display.

The preseed's `late_command` copies the payload into the installed system
and runs `setup.sh`, which installs the package list, installs the baked
Mint-Y theme `.deb`s, and applies the desktop defaults (dconf system
database, slick-greeter as the lightdm greeter, the Mint-Y-Dark theme, a
single bottom panel, the UTM shared folder, and a README on the desktop).
`build.sh` fetches the Mint-Y theme `.deb`s from the Linux Mint pool
(arch:all, not in Debian) and caches them under `.cache/` between builds;
everything else on the ISO passes through unchanged.

## Layout

- `build.sh` — ISO in, ISO out
- `preseed/preseed.cfg` — semi-attended answers (default)
- `preseed/preseed-auto.cfg` — fully unattended answers (`--auto`)
- `payload/minty/setup.sh` — runs in the target at the end of install
- `payload/minty/packages.txt` — the package list
- `payload/minty/dconf/` — desktop defaults
- `payload/minty/lightdm/` — greeter configuration
- `payload/minty/mate-panel/` — the single-panel layout
- `payload/minty/themes/`, `payload/minty/desktop/` — theme + desktop README
- `docs/` — write-ups of two upstream bugs Minty works around (an
  Adwaita-dark GTK caret bug and a mate-control-center metacity-theme-3
  detection bug)

## Naming and trademarks

"Minty" describes the flavor; this project is not Linux Mint and ships none
of its logos or artwork-branding. It does redistribute Mint's GPL theme
data — `mint-themes` and `mint-x-icons` from the Linux Mint pool, plus
`mint-y-icons` and the apps (slick-greeter, timeshift) that Debian itself
packages — all under their upstream GPL licenses.

## License

GPLv3 — see [LICENSE](LICENSE). Copyright (C) 2026 Bradley Erickson.
