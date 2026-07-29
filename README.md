# Minty — a Mint-flavored Linux for Apple Silicon Macs

Run a clean, dark, Linux Mint–style desktop in a window on your Mac — no
Linux experience required. Minty is Debian 13 dressed in the Linux Mint
look (the Mint-Y theme, a single taskbar, a friendly menu), packaged to
install in a few clicks with the free **UTM** app.

## What you need

- An **Apple Silicon Mac** (M1, M2, M3, …).
- **UTM** — free: <https://mac.getutm.app>
- About **10 GB** of free disk space and an internet connection.

## 1. Install UTM

Download UTM from <https://mac.getutm.app> (or the Mac App Store) and drag
it into your Applications folder.

## 2. Download Minty

From the
**[Releases](https://github.com/13rac1/minty-debian-arm64/releases)** page,
download the latest `minty-…-netinst.iso`.

*(Optional — to confirm the download isn't corrupted: also download
`SHA256SUMS`, then in the folder with both files run
`shasum -a 256 -c SHA256SUMS` in Terminal. It should say `OK`.)*

## 3. Create the virtual machine

1. Open UTM → **＋** → **Virtualize** → **Linux**.
2. Leave **“Use Apple Virtualization” unchecked** — the default gives you
   copy/paste between Mac and Minty and a fully shared folder.
3. **Boot ISO Image:** click *Browse* and choose the `minty-…iso` you
   downloaded.
4. **Memory:** 4096 MB is plenty. **CPU Cores:** leave the default.
5. **Storage:** 16 GB or more. *(This is the VM's own disk — your Mac's
   files are never touched.)*
6. *(Optional)* **Shared Directory:** pick a Mac folder to swap files
   through; it shows up at `~/Shared` inside Minty.
7. Name it **Minty** and click **Save**.

## 4. Install Minty

Start the VM and choose **Install** at the boot menu. The installer asks a
few simple questions — the defaults are fine except:

- **Language / keyboard** — pick yours.
- **Hostname** — a name for the machine (e.g. `minty`).
- **Your account** — your name, a username, and a password. *(There's no
  separate “root” password; you use this account for everything, with
  `sudo` for admin tasks.)*
- **Time zone.**
- **Disk** — when asked, use the **entire disk**. It's the VM's 16 GB
  virtual disk, **not your Mac**, so this is safe.

Everything else runs on its own (it downloads the desktop, so keep the
internet connected). When it's done it reboots into Minty.

> If it boots back into the installer, shut the VM down, remove the CD/ISO
> drive in the VM's settings, and start it again.

## 5. First login

Pick your user on the login screen and type your password. You'll land on a
dark, green-accented Mint-Y desktop. A **README on the desktop** explains
the shared folder, clipboard, and a few extras.

That's it — a Linux desktop on your Mac.

---

## Building it yourself · how it works

Building the ISO from source, customizing the packages or theme, the fully
unattended mode, and how the installer is assembled all live in
**[README_ADVANCED.md](README_ADVANCED.md)**.

## About the name & license

“Minty” describes the flavor — this project is **not** Linux Mint and ships
none of Mint's logos or branding, only its GPL-licensed theme. GPLv3; see
[LICENSE](LICENSE).
