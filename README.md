# Minty Debian arm64

Turn a stock Debian 13 arm64 installer ISO into an unattended installer
for a Mint-like MATE desktop with the Mint-Y theme. Almost everything
comes from official Debian mirrors; the exceptions are the Mint-Y GTK
theme and Mint-X icons (`mint-themes`, `mint-x-icons`) — arch:all GPL
data Debian does not carry — which `build.sh` fetches from the Linux Mint
package pool and bakes into the image. No third-party apt repository is
added to the installed system, and none of Linux Mint's logos or
artwork-branding are shipped.

## Workflow

1. Download a Debian 13 arm64 installer ISO — netinst or DVD-1:
   https://www.debian.org/distrib/ (e.g. `debian-13.6.0-arm64-DVD-1.iso`)
2. `git clone https://github.com/13rac1/minty-debian-arm64`
3. `./build.sh debian-13.6.0-arm64-DVD-1.iso`

Output: `minty-debian-arm64.iso` — boot it on any arm64 UEFI machine or
VM and it installs Debian 13 with MATE, themed Mint-Y-Dark (green
accent): the Mint-Y-Dark GTK theme, the adaptive Mint-Y Marco window
borders, Mint-Y icons, and the Bibata cursor. Plus the Mint-origin
applications Debian itself packages (slick-greeter, timeshift, mintstick)
and the SPICE/QEMU guest agents for running under UTM or QEMU
(spice-vdagent for clipboard and dynamic resolution, spice-webdavd for
file sharing, qemu-guest-agent for host-driven shutdown). A UTM shared
folder auto-mounts read/write for the first user at `~/Shared` — 9p under
the QEMU backend, virtiofs under Apple Virtualization, detected at install.

This is an installer image, not a live session — Debian publishes no
arm64 live desktop images, so there is no try-before-install.

## Modes

**Default (semi-attended):** the installer still asks for language,
keyboard, user account, timezone, and — before touching anything — the
target disk. Everything else is automated.

**`--auto` (fully unattended):**

```
./build.sh --auto debian-13.6.0-arm64-DVD-1.iso
```

DANGER: erases the first disk without confirmation and creates user
`minty` with password `minty`. Only for VMs and machines you intend to
wipe. Change the password on first login.

## Network requirements

- DVD-1 input: the MATE desktop installs from the disc; the Mint-origin
  packages are not on DVD-1 and install from the network mirror. With no
  network the result is a plain Debian MATE system — finish later with
  `sudo bash /opt/minty/setup.sh`.
- netinst input: network required for the whole install.

## Testing in QEMU

```
qemu-img create -f qcow2 disk.qcow2 16G
qemu-system-aarch64 -M virt -cpu max -smp 4 -m 4096 \
  -drive if=pflash,format=raw,readonly=on,file=/usr/share/AAVMF/AAVMF_CODE.fd \
  -device virtio-gpu-pci -device qemu-xhci -device usb-kbd -device usb-tablet \
  -drive file=minty-debian-arm64.iso,media=cdrom \
  -drive file=disk.qcow2,if=virtio \
  -netdev user,id=n0 -device virtio-net-pci,netdev=n0 \
  -display gtk
```

AAVMF firmware is in the `qemu-efi-aarch64` package. Use `-accel kvm`
and `-cpu host` on arm64 hosts with KVM.

## How it works

`build.sh` appends a cpio overlay (the `payload/` tree) to both
installer initrds inside the ISO, places the preseed file on the ISO
filesystem, patches `grub.cfg` to pass `file=/cdrom/preseed.cfg` to
the kernel, and repacks with xorriso in boot-image replay mode so the
EFI boot structure is preserved byte-for-byte. The preseed is loaded
from the CD-ROM mount point after hardware detection rather than
auto-loaded from the initramfs root — the early initramfs path runs
before framebuffer init on QEMU ARM64, blanking the display. The
preseed's `late_command` copies the payload into the installed system
and runs `setup.sh`, which installs the package list, installs the baked
Mint-Y theme `.deb`s, and applies the desktop defaults (dconf system
database, slick-greeter as the lightdm greeter, the Mint-Y-Dark theme
selection). `build.sh` fetches the Mint-Y theme `.deb`s from the Linux
Mint pool (arch:all, not in Debian) and bakes them into the image,
caching them under `.cache/` between builds; everything else on the ISO
passes through unchanged.

Build dependencies: `xorriso`, `cpio`, `gzip`, and `curl` or `wget`
(build.sh fetches the theme `.deb`s). Runs on any Linux or macOS host,
any architecture (only the target ISO is arm64):

- Debian/Ubuntu: `sudo apt install xorriso` (cpio, gzip, wget are standard)
- macOS: `brew install xorriso` (curl, cpio, gzip are built in)

On an Apple Silicon Mac the result can also be tested at native speed:
UTM or QEMU run arm64 guests under Hypervisor.framework, no emulation.

## Layout

- `build.sh` — ISO in, ISO out
- `preseed/preseed.cfg` — semi-attended answers (default)
- `preseed/preseed-auto.cfg` — fully unattended answers (`--auto`)
- `payload/minty/setup.sh` — runs in the target at the end of install
- `payload/minty/packages.txt` — the package list (MATE theming + Mint-origin apps)
- `payload/minty/dconf/` — desktop defaults
- `payload/minty/lightdm/` — greeter configuration

## Status

ISO repacking is verified against `debian-13.6.0-arm64-DVD-1.iso`.
Full install runs are tested in QEMU; bare-metal reports welcome.

## Naming and trademarks

"Minty" describes the flavor; this project is not Linux Mint and ships
none of its logos or artwork-branding. It does redistribute Mint's GPL
theme data — `mint-themes` and `mint-x-icons` from the Linux Mint pool,
plus `mint-y-icons` and the apps (slick-greeter, timeshift, mintstick)
that Debian itself packages — all under their upstream GPL licenses.

## License

GPLv3 — see LICENSE. Copyright (C) 2026 Bradley Erickson.
