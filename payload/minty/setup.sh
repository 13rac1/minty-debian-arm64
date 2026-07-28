#!/bin/bash
# setup.sh — runs inside the freshly installed system (via the
# preseed's late_command). Installs the Mint-origin package list from
# the Debian archive, then applies desktop defaults. Safe to rerun:
# sudo bash /opt/minty/setup.sh
#
# Copyright (C) 2026 Bradley Erickson
# SPDX-License-Identifier: GPL-3.0-or-later
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
LOG=/var/log/minty-setup.log
exec > >(tee -a "$LOG") 2>&1

echo "minty: installing packages from the Debian archive"
packages_ok=0
if apt-get update; then
  if xargs -a "$HERE/packages.txt" apt-get install -y; then
    packages_ok=1
  fi
fi
if [ "$packages_ok" -ne 1 ]; then
  echo "minty: WARNING package install failed (no network mirror?)."
  echo "minty: the system is plain Debian Cinnamon; rerun this script later:"
  echo "minty:   sudo bash /opt/minty/setup.sh"
fi

echo "minty: installing the Mint-Y theme"
# build.sh bakes the theme .debs into debs/; apt pulls the mint-y-icons
# dependency from Debian. Offline (no mirror), this fails and Cinnamon
# keeps its default theme.
if ! apt-get install -y "$HERE"/debs/*.deb; then
  echo "minty: WARNING Mint-Y theme not installed (offline?); Cinnamon keeps its"
  echo "minty: default theme. Rerun this script once online to apply it."
fi

# mate-themes rides in as a Recommends of cinnamon-desktop-environment.
# We ship Cinnamon, not MATE; drop it (and its BlackMATE/BlueMenta themes).
# Recommends means nothing depends on it, so purge does not cascade.
if dpkg -s mate-themes >/dev/null 2>&1; then
  echo "minty: removing mate-themes (unused MATE themes)"
  apt-get purge -y mate-themes
fi

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

echo "minty: done (packages_ok=$packages_ok)"
