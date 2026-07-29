# mate-control-center: metacity-theme-3.xml not detected (Mint-Y "not installed")

Draft write-up for an upstream mate-control-center issue. We are not filing
it now; the image ships a local workaround (see the last section). Verified
against the source and a running Debian 13 (trixie) MATE system.

## Summary

The MATE Appearance tool (mate-control-center) detects Marco/metacity window
manager themes by looking **only** for `metacity-theme-1.xml` or
`metacity-theme-2.xml`. It never looks for **`metacity-theme-3.xml`** — the
newer format (v3, with adaptive `gtk:custom(...)` color references). Any
theme that ships *only* a v3 metacity theme is therefore invisible to the
GUI, even though it is installed and Marco renders it fine.

Concretely, with `Mint-Y` (which ships only `metacity-theme-3.xml`):

- Appearance → **Theme** shows: *"This theme will not look as intended
  because the required window manager theme 'Mint-Y' is not installed."*
- Appearance → **Customize → Window Border** does not list `Mint-Y` at all.

Both are false: `Mint-Y` is installed (`marco theme='Mint-Y'` is set) and the
window borders render correctly, because **Marco supports v3**. Only the GUI
is blind to it.

## Affected / environment

- **mate-control-center:** `1.26.1` (Debian trixie) through current `master`
  (`d2f5e0f7`, 1.29.0-dev). The string `metacity-theme-3` appears in **zero
  commits** in the entire git history — never fixed upstream.
- **Theme:** `mint-themes` `Mint-Y`, which ships only
  `/usr/share/themes/Mint-Y/metacity-1/metacity-theme-3.xml`
  (`version="< 3.1"`, i.e. format 3).
- **Not reproducible on Linux Mint** — Mint carries a downstream patch to
  mate-control-center. Same theme files and same Marco, so the GUI is the
  only difference.

## Root cause

`capplets/common/mate-theme-info.c`:

- Detection (~line 1086) — existence check, `-2.xml` then `-1.xml`, no `-3`:

  ```c
  subdir = g_file_get_child (theme_dir_uri, "metacity-1");
  uri = g_file_get_child (subdir, "metacity-theme-2.xml");
  if (g_file_query_exists (uri, NULL)) {
    update_marco_index (uri, monitor_data->priority);
  } else {
    g_object_unref (uri);
    uri = g_file_get_child (subdir, "metacity-theme-1.xml");
    if (g_file_query_exists (uri, NULL))
      update_marco_index (uri, monitor_data->priority);
  }
  ```

- File-change monitor (line 968) — same omission:

  ```c
  if (!strcmp (affected_file, "metacity-theme-1.xml") ||
      !strcmp (affected_file, "metacity-theme-2.xml")) {
  ```

`update_marco_index` registers the theme by its **directory name** (the
metacity-1 dir's parent, e.g. `Mint-Y`) and does not parse the file — so
detection is purely "does a `metacity-theme-{1,2}.xml` exist." A theme with
only `metacity-theme-3.xml` is never indexed.

Marco itself is fine: `src/ui/theme-parser.c` defines `THEME_MAJOR_VERSION 3`
(`THEME_MINOR_VERSION 5`) and loads `metacity-theme-3.xml` first, so a v3
theme renders correctly — the discrepancy is entirely in the GUI's detector.

## Suggested upstream fix

Teach both sites about `metacity-theme-3.xml`, checked first (Marco already
prefers the highest version):

- Detection (~line 1086): try `metacity-theme-3.xml`, then `-2.xml`, then
  `-1.xml`.
- Monitor (line 968): add
  `|| !strcmp (affected_file, "metacity-theme-3.xml")`.

Suggested commit message:

```
appearance: detect metacity-theme-3.xml window manager themes

The Marco theme detector only checked for metacity-theme-1.xml and
metacity-theme-2.xml, so themes shipping only the v3 format (e.g. Mint-Y)
were reported as "not installed" and omitted from the Window Border list,
even though Marco loads and renders them. Look for metacity-theme-3.xml
first (Marco already prefers the highest version), and notice it in the
theme-dir monitor.
```

Submit to `https://gitlab.gnome.org/GNOME/mate-control-center` (or the
GitHub mirror `mate-desktop/mate-control-center`).

## Local workaround (applied in this image)

We cannot rebuild mate-control-center (no third-party packages), so we make
the GUI's existence check succeed: after installing `mint-themes`,
`setup.sh` loops over every `/usr/share/themes/*/metacity-1` that ships only
`metacity-theme-3.xml` (in `mint-themes` that is `Mint-Y` **and** `Mint-X`)
and symlinks a `metacity-theme-2.xml` name onto the real
`metacity-theme-3.xml`.

- The GUI's `g_file_query_exists("metacity-theme-2.xml")` now passes, so it
  indexes the theme (name from the directory), lists it in Window Border, and
  the "not installed" warning disappears.
- Marco still loads `metacity-theme-3.xml` (it tries the highest version
  first), so rendering is unchanged.

It writes into a package-owned directory, so it is not dpkg-tracked; a
`mint-themes` upgrade leaves the symlink in place (harmless).
