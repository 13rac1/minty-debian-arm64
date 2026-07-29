#!/bin/bash
# setup.sh — runs inside the freshly installed system (via the
# preseed's late_command). Installs the package list from the Debian
# archive, then applies the MATE desktop defaults. Safe to rerun:
# sudo bash /opt/minty/setup.sh
#
# Copyright (C) 2026 Bradley Erickson
# SPDX-License-Identifier: GPL-3.0-or-later
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
LOG=/var/log/minty-setup.log
exec > >(tee -a "$LOG") 2>&1

echo "minty: installing packages from the Debian archive"
# The installer records the boot DVD in apt's sources; once the disc is
# gone that entry has no Release file and fails `apt-get update`, which
# would abort setup below. Comment it out so update runs against the
# network mirror — the packages below are not on the DVD, so the mirror
# is required regardless. Anchored match is idempotent on rerun.
sed -i '/^deb cdrom:/s/^/#/' /etc/apt/sources.list 2>/dev/null || true
if ! apt-get update; then
  echo "minty: FATAL apt-get update failed (no network mirror?); aborting." >&2
  exit 1
fi
# Install one package at a time: a single missing package aborts a batched
# apt-get install and takes the installable ones down with it (that is how
# slick-greeter silently failed to install). Any failure is fatal — a
# missing package means the image is incomplete, not degraded-but-usable.
# Collect every failure first so the log names all of them, not just the
# first.
missing=()
while read -r pkg; do
  case "$pkg" in ''|\#*) continue ;; esac
  apt-get install -y "$pkg" || missing+=("$pkg")
done < "$HERE/packages.txt"
if [ "${#missing[@]}" -ne 0 ]; then
  echo "minty: FATAL could not install: ${missing[*]}" >&2
  echo "minty: the image is incomplete; aborting setup." >&2
  exit 1
fi

# Weekly fstrim returns deleted-block space to the host — a qcow2/VM disk
# only grows otherwise. enable (not --now) works in the install-time chroot;
# the timer starts on first boot.
echo "minty: enabling weekly fstrim"
systemctl enable fstrim.timer 2>/dev/null || echo "minty: WARNING could not enable fstrim.timer"

echo "minty: installing the Mint-Y theme"
# build.sh bakes mint-themes + mint-x-icons (Linux Mint pool, arch:all, not
# in Debian) into debs/; the mint-y-icons dependency comes from Debian (in
# packages.txt, installed above). mint-themes ships the GTK color variants
# and the adaptive base Mint-Y metacity (window-border) theme. Offline this
# fails and MATE keeps its default theme.
if ! apt-get install -y "$HERE"/debs/*.deb; then
  echo "minty: WARNING Mint-Y theme not installed (offline?); MATE keeps its"
  echo "minty: default theme. Rerun this script once online to apply it."
fi

# WORKAROUND: mate-control-center (through 1.29) detects Marco themes only
# via metacity-theme-1.xml/-2.xml, never -3.xml, so Mint-Y — which ships only
# metacity-theme-3.xml — triggers a false "window manager theme not installed"
# warning and is missing from the Window Border list. Marco renders v3 fine.
# Symlink a -2.xml name onto the real -3.xml so the GUI's existence check
# finds it; Marco still loads -3.xml (tried first). SEE
# docs/mate-control-center-metacity-theme-3.md.
mY=/usr/share/themes/Mint-Y/metacity-1
if [ -f "$mY/metacity-theme-3.xml" ] && [ ! -e "$mY/metacity-theme-2.xml" ]; then
  ln -s metacity-theme-3.xml "$mY/metacity-theme-2.xml"
  echo "minty: worked around mate-control-center metacity-theme-3 detection"
fi

echo "minty: installing the single bottom panel layout"
# default-layout='minty' (dconf below) points mate-panel at this file; a
# fresh user gets a single bottom panel on first run instead of two.
install -d /usr/share/mate-panel/layouts
install -m 0644 "$HERE/mate-panel/minty.layout" /usr/share/mate-panel/layouts/minty.layout

echo "minty: applying desktop defaults"
install -d /etc/dconf/profile /etc/dconf/db/local.d
printf 'user-db:user\nsystem-db:local\n' > /etc/dconf/profile/user
install -m 0644 "$HERE/dconf/00-minty" /etc/dconf/db/local.d/00-minty
if command -v dconf >/dev/null; then
  dconf update
else
  echo "minty: WARNING dconf-cli missing, defaults staged but not compiled"
fi

# Point lightdm at slick-greeter only if it actually installed;
# otherwise lightdm's default greeter keeps login working.
if [ -x /usr/sbin/slick-greeter ] || dpkg -s slick-greeter >/dev/null 2>&1; then
  install -d /etc/lightdm/lightdm.conf.d
  install -m 0644 "$HERE/lightdm/60-slick-greeter.conf" /etc/lightdm/lightdm.conf.d/60-slick-greeter.conf
  install -m 0644 "$HERE/lightdm/slick-greeter.conf" /etc/lightdm/slick-greeter.conf
fi

echo "minty: done"
