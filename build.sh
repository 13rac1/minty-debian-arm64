#!/usr/bin/env bash
# build.sh — remaster a stock Debian 13 arm64 installer ISO (netinst or
# DVD-1) into an unattended installer for a Mint-like Cinnamon desktop.
# SEE README.md "How it works" for the mechanism and safety notes.
#
# Copyright (C) 2026 Bradley Erickson
# SPDX-License-Identifier: GPL-3.0-or-later
set -euo pipefail

usage() {
  echo "Usage: $0 [--auto] <debian-13-arm64.iso> [output.iso]" >&2
  echo "  --auto  fully unattended: ERASES the first disk, user minty/minty" >&2
  exit 1
}

PRESEED=preseed/preseed.cfg
if [ "${1:-}" = "--auto" ]; then
  PRESEED=preseed/preseed-auto.cfg
  shift
fi
[ $# -ge 1 ] || usage
ISO=$1
OUT=${2:-minty-debian-arm64.iso}
HERE="$(cd "$(dirname "$0")" && pwd)"

for dep in xorriso cpio gzip; do
  command -v "$dep" >/dev/null || { echo "missing dependency: $dep" >&2; exit 1; }
done
[ -f "$ISO" ] || { echo "no such file: $ISO" >&2; exit 1; }

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

# d-i auto-loads /preseed.cfg from the initramfs root; /minty is copied
# into the target by the preseed's late_command.
overlay="$WORK/overlay"
mkdir -p "$overlay"
cp "$HERE/$PRESEED" "$overlay/preseed.cfg"
cp -r "$HERE/payload/minty" "$overlay/minty"
# --format (not -H/--quiet) works in both GNU cpio and macOS BSD cpio.
( cd "$overlay" && find . | cpio -o --format newc | gzip -9 ) > "$WORK/overlay.cpio.gz"

# Both the text and gtk installer initrds live under /install.a64; the
# kernel accepts concatenated initramfs archives, later entries win.
xorriso -osirrox on -indev "$ISO" -extract /install.a64 "$WORK/install.a64" 2>/dev/null
chmod -R u+w "$WORK/install.a64"
found=0
while IFS= read -r initrd; do
  cat "$WORK/overlay.cpio.gz" >> "$initrd"
  echo "injected overlay into ${initrd#"$WORK"/}"
  found=1
done < <(find "$WORK/install.a64" -name initrd.gz)
[ "$found" -eq 1 ] || { echo "no initrd.gz under /install.a64 — not a Debian arm64 installer ISO?" >&2; exit 1; }

# Replay mode reproduces the source ISO's EFI boot structure unchanged.
xorriso -indev "$ISO" -outdev "$OUT" \
        -boot_image any replay \
        -map "$WORK/install.a64" /install.a64

echo
echo "wrote $OUT (preseed: $(basename "$PRESEED"))"
