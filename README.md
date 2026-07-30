# Minty - a Mint-flavored Debian Linux

Minty is Debian 13 configured to look like [Linux Mint](https://www.linuxmint.com/)
(the Mint-Y theme and a single taskbar), pre-configured with shared
clipboard/folders to run virtualized in UTM on Apple Silicon Macs or
other ARM64 hosts.

## Note

This exists because there is not an official ARM64 Linux Mint release,
updates cease when there is.

## MacOS requirements

- An Apple Silicon Mac (M1 or later).
- [UTM](https://mac.getutm.app)
- About 10 GB of free disk space and an internet connection.

## 1. Install UTM

Download [UTM](https://mac.getutm.app) or install from the App Store.

## 2. Download Minty

Download the latest `minty-…-netinst.iso` from the
[Releases](https://github.com/13rac1/minty-debian-arm64/releases) page.

To optionally verify the download, also download `SHA256SUMS` and run
`shasum -a 256 -c SHA256SUMS` in the folder containing both files.

## 3. Create the virtual machine

1. In UTM, select **＋ → Virtualize → Linux**.
2. Leave **Use Apple Virtualization** unchecked. The default (QEMU) provides
   clipboard sharing and a fully writable shared folder.
3. **Boot ISO Image:** browse to the downloaded `minty-…iso`.
4. **Memory:** 4096 MB. **CPU Cores:** default.
5. **Storage:** 32 GB or more. This is the VM's virtual disk; files on the
   Mac are not affected.
6. Optional — **Shared Directory:** select a Mac folder. It mounts at
   `~/Shared` inside the VM.
7. Name the VM and save.

On a Retina Mac, open the VM's **Settings → Display** and enable **Retina
Mode (HiDPI)** for a sharp, full-resolution display.

## 4. Install Minty

Start the VM and select **Install**. Accept the defaults except:

- **Language / keyboard.**
- **Hostname** — a name for the machine.
- **User account** — name, username, password. There is no separate root
  password; this account uses `sudo` for administration.
- **Time zone.**
- **Disk** — use the entire disk. This is the VM's virtual disk, not the
  Mac.

The rest is automatic and downloads packages, so keep the network
connected. The VM reboots into Minty Debian when finished.

If it reboots into the installer instead, shut the VM down, remove the
CD/ISO drive in its settings, and start it again.

## 5. First login

Select your user and enter your password. The desktop is dark Mint-Y MATE.
A README on the desktop covers further details.

## Mac integration

Clipboard sharing and a shared folder are already configured in Minty —
nothing needs setting up inside the VM. On the default (QEMU) backend, turn
on clipboard sharing and/or select a shared directory in UTM's settings;
copy/paste then works between the Mac and Minty and the shared folder
appears at `~/Shared`.

## Building from source

See [README_ADVANCED.md](README_ADVANCED.md).

## Name and license

"Minty" describes the flavor; this project is not Linux Mint and ships none
of its logos or branding, only its GPL-licensed theme. GPLv3; see
[LICENSE](LICENSE).
