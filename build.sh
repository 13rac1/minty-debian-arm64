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

# The Debian arm64 installer boots one of two initrds (text / graphical),
# both referenced by /boot/grub/grub.cfg. Touch ONLY these files: extract
# each, append the overlay (the kernel reads concatenated initramfs
# archives, later entries win), and map it back individually. vmlinuz and
# every other file pass through untouched from the source ISO, so no
# xorriso version can corrupt the kernel via a round trip. DANGER: keep
# this list in step with grub.cfg's initrd paths.
INITRDS=(/install.a64/initrd.gz /install.a64/gtk/initrd.gz)
map_args=()
for iso_path in "${INITRDS[@]}"; do
  local_copy="$WORK/$(echo "$iso_path" | tr / _)"
  xorriso -osirrox on -indev "$ISO" -extract "$iso_path" "$local_copy" 2>/dev/null
  [ -s "$local_copy" ] || { echo "missing $iso_path — not a Debian arm64 installer ISO?" >&2; exit 1; }
  chmod u+w "$local_copy"
  cat "$WORK/overlay.cpio.gz" >> "$local_copy"
  echo "injected overlay into $iso_path"
  map_args+=(-map "$local_copy" "$iso_path")
done

# Replay mode reproduces the source ISO's EFI boot structure unchanged.
xorriso -indev "$ISO" -outdev "$OUT" \
        -boot_image any replay \
        "${map_args[@]}"

# Verify the rebuild preserved the boot-critical files. A broken xorriso
# can silently corrupt files while still producing a bootable-looking
# ISO — the symptom is reaching GRUB but hanging at kernel handoff (blank
# screen, flashing cursor). Refuse to emit such an image.
corrupt() {
  echo "ERROR: $1" >&2
  echo "       This host's xorriso ($(xorriso -version 2>/dev/null | head -1)) is corrupting files during rebuild." >&2
  echo "       The ISO would reach GRUB but hang at kernel handoff. Not shipping it." >&2
  rm -f "$OUT"
  exit 1
}

# The kernel is passed through untouched, so it must be byte-identical.
xorriso -osirrox on -indev "$ISO" -extract /install.a64/vmlinuz "$WORK/kern_in"  2>/dev/null
xorriso -osirrox on -indev "$OUT" -extract /install.a64/vmlinuz "$WORK/kern_out" 2>/dev/null
cmp -s "$WORK/kern_in" "$WORK/kern_out" || corrupt "kernel changed during rebuild"

# The patched initrds must be intact gzip (all concatenated streams).
for iso_path in "${INITRDS[@]}"; do
  chk="$WORK/verify$(echo "$iso_path" | tr / _)"
  xorriso -osirrox on -indev "$OUT" -extract "$iso_path" "$chk" 2>/dev/null
  gzip -t < "$chk" 2>/dev/null || corrupt "$iso_path is corrupt in the output ISO"
done

echo
echo "wrote $OUT (preseed: $(basename "$PRESEED"); kernel + initrds verified intact)"
