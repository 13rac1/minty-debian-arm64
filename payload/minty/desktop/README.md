# Minty — Debian 13 (Trixie) · MATE

A Mint-flavored Debian desktop for ARM64: stock Debian plus the Linux Mint
theme. This note summarizes how the system is set up.

## This system

- **Desktop:** MATE, a single bottom panel with the mate-menu menu.
- **Theme:** Mint-Y-Dark (green) with Mint-Y icons and the Bibata cursor.
- **Login:** slick-greeter, showing the list of user accounts.
- **Accounts:** the **root account has no password** — run admin commands
  with `sudo` from your own account.
- **Maintenance:** Timeshift (system snapshots) is installed; a weekly
  `fstrim` keeps the virtual disk from growing without bound.
- **Remote access:** an SSH server is running — `ssh <user>@<vm-ip>`.

## Running under UTM

- **Shared folder → `~/Shared`.** Enable a shared directory in the VM
  settings — **VirtFS** on the QEMU backend, **VirtioFS** on Apple
  Virtualization — and leave the device name as `share`. It auto-mounts at
  `~/Shared` (an empty `~/Shared` means nothing is shared yet). The layout
  differs by backend:
    - **QEMU:** the shared folder's contents sit directly in `~/Shared`,
      read/write.
    - **Apple Virtualization:** virtiofs nests the share one level down, in a
      subfolder named after the host folder you shared — e.g. a Mac folder
      named `Shared` appears as `~/Shared/Shared`. Read and write happen in
      that subfolder; `~/Shared` itself is just the container.
- **Clipboard & display auto-resize.** On the QEMU backend, turn on
  clipboard sharing in UTM; the SPICE agent handles copy/paste and resizing
  the desktop to the window.
- **More UTM guest integration:**
  <https://docs.getutm.app/guest-support/linux/>

## Re-running setup

This desktop was configured by `/opt/minty/setup.sh` (log at
`/var/log/minty-setup.log`). It is safe to re-run if something did not apply
the first time (e.g. the install had no network):

    sudo bash /opt/minty/setup.sh
