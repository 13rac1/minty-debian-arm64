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

echo "minty: installing the DarkShiny theme"
# DarkShiny is a meta-theme (references Adwaita-dark + Shiny + mate, all
# installed above). Shipping index.theme makes it a selectable preset in
# the MATE Appearance list; the dconf defaults below already apply its
# components, so it shows up as the active selection.
install -d /usr/share/themes/DarkShiny
install -m 0644 "$HERE/themes/DarkShiny/index.theme" /usr/share/themes/DarkShiny/index.theme

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
