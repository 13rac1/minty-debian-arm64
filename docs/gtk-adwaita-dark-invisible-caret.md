# GTK3 Adwaita-dark: invisible text caret in `entry` widgets

Draft write-up for an upstream GTK issue / merge request. Captured so it can
be filed later. All facts below were verified against the GTK source and the
compiled theme in Debian 13 (trixie).

## Summary

In the **dark** variant of GTK3's built-in Adwaita theme, `GtkEntry` widgets
have **no `caret-color`**, so the text insertion cursor falls back to a dark
default and is **invisible against the dark entry background**. Typed text is
visible; only the blinking caret is missing. The light variant is unaffected
(the same dark fallback caret happens to show up on a light background), and
every non-Adwaita theme is fine (they set an entry caret color).

User-visible symptom: you cannot see the text cursor when editing any text
field under Adwaita-dark — e.g. renaming a file in a file manager, or any
`GtkEntry`/`GtkSpinButton`.

## Affected / environment

- **Theme:** GTK3 built-in Adwaita, dark variant
  (`resource:///org/gtk/libgtk/theme/Adwaita/gtk-contained-dark.css`,
  compiled into `libgtk-3-0`). The stock `/usr/share/themes/Adwaita-dark`
  from `gnome-themes-extra-data` is just a stub that `@import`s this resource.
- **GTK:** 3.24.x. Verified against `gtk-3-24` HEAD
  `888ede6720c449b4e932e2287f2e1dece81ea9d0` (2026-07-23) — **still present**.
  Reproduced on Debian 13 (trixie) GTK 3.24.x.
- **Apps:** any GTK3 app; first noticed in MATE/Caja (renaming desktop icons
  and files in the file-manager window).

## Reproduction

1. Use the Adwaita-dark theme (`gtk-theme-name = Adwaita-dark`, or Adwaita
   with `gtk-application-prefer-dark-theme = true` — both load the same
   built-in dark CSS).
2. Focus any `GtkEntry` (rename a file, or a search box, etc.).
3. The typed characters appear but the blinking insertion caret does not.

## Root cause

In `gtk/theme/Adwaita/_common.scss`:

- `.view` / `%view` (textviews, treeviews, iconviews) **do** set a caret color:

  ```scss
  .view,
  %view {
    color: $text_color;
    caret-color: $caret_color;        // ~line 111
    background-color: $base_color;
  ```

- The `entry` block sets `color` and (via `@include entry(normal)`) a
  background, but **never sets `caret-color`** (block starts ~line 323).

- `$caret_color` itself is defined to contrast in both variants, so it is not
  the problem — entries simply never receive it (`gtk/theme/Adwaita/_colors.scss:6`):

  ```scss
  $caret_color: if($variant == 'light', lighten($text_color, 5%), darken($text_color, 3%));
  ```

With no `caret-color` on `entry`, GTK renders the caret with its default,
which does not track the (light) entry text color in the dark variant, so it
is invisible on the dark entry background.

### Compiled evidence (dark `gtk-contained-dark.css`)

```css
/* views/textviews get a visible caret … */
.view, iconview, .view text, iconview text, textview text {
  color: white; caret-color: #f7f7f7; background-color: #2d2d2d;
}
/* … but the entry has none */
entry {
  … color: white; background-color: #2d2d2d; …   /* no caret-color */
}
```

### The theme already knows the default is unreliable

`_common.scss` ~line 179 sets it manually on labels, with a revealing comment:

```scss
label {
  caret-color: currentColor; // this shouldn't be needed.
```

i.e. the authors already worked around GTK's implicit caret default for
labels — they just never applied the same to `entry`.

## Fix

Add `caret-color: $caret_color;` to the `entry` block, mirroring `.view`.
Targeted at `gtk-3-24`, `gtk/theme/Adwaita/_common.scss`:

```diff
diff --git a/gtk/theme/Adwaita/_common.scss b/gtk/theme/Adwaita/_common.scss
index b9db604..e404005 100644
--- a/gtk/theme/Adwaita/_common.scss
+++ b/gtk/theme/Adwaita/_common.scss
@@ -328,6 +328,7 @@ entry {
     border: 1px solid;
     border-radius: $button_radius;
     transition: all 200ms $ease-out-quad;
+    caret-color: $caret_color;
 
     @include entry(normal);
```

(The `.scss` is compiled to the shipped `gtk-contained*.css` by the theme's
build; regenerate those if submitting the built CSS too.)

## Suggested commit message

```
Adwaita: set caret-color on entry

The dark variant sets color and background-color on entry but no
caret-color, so the text caret falls back to a dark default and is
invisible on the dark entry background (every text field, e.g. renaming
a file in a file manager). The .view block already sets
caret-color: $caret_color; mirror it for entry so the caret contrasts in
both variants.
```

## How to submit

1. Fork `https://gitlab.gnome.org/GNOME/gtk` on gitlab.gnome.org.
2. Branch off `gtk-3-24` (GTK3 is in maintenance; GTK4/libadwaita is a
   separate codebase and **not** where this bug lives).
3. Apply the diff above, commit with the message above, push to the fork.
4. Open a merge request against `GNOME/gtk` targeting `gtk-3-24`.
5. Note in the MR: GTK3 is EOL-ish, so also worth checking whether the same
   omission exists in GTK4's Adwaita — though GTK4 apps typically use
   libadwaita, not this theme.

## Local workaround (for reference)

Until upstream fixes it, a theme can force it in its own `gtk-3.0/gtk.css`:

```css
@import url("resource:///org/gtk/libgtk/theme/Adwaita/gtk-contained-dark.css");
entry, spinbutton { caret-color: currentColor; }
```

(Loaded via `/usr/share/themes/<Theme>/gtk-3.0/gtk.css` when that theme is
selected, or per-user via `~/.config/gtk-3.0/gtk.css`. A system-wide
`/etc/xdg/gtk-3.0/gtk.css` does **not** work — GTK3 only reads the user
config dir for `gtk.css`, per `gtksettings.c`.)
