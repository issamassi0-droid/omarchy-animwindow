# omarchy-animwindow

oshelf-style open/close animations and a matching gradient background for the Omarchy quickshell — applied dynamically through the shell's shared `qs.Ui` components, so **any** plugin, current or future, that builds on them inherits both the animation and the gradient automatically.

## What it does

The main menu, top bar, bar popups (tray, media), panels (audio, bluetooth, clock, network, weather, …), confirm dialogs, OSD and reminder cards get:

1. **AnimWindow animation** — content slides in while fading and scaling up (and reverses on close), instead of popping in/out instantly.
2. **Accent-tinted gradient wash** — a subtle top-edge gradient (`Color.accent` at 8.5% opacity fading to transparent), matching the oshelf shelf style, applied to every surface in the shell and to installed third-party plugins.

```
omarchy-animwindow status

  component:           installed
  menu animation:      applied
  popup animation:     applied
  keyboard anim:       applied
  dialog animation:    applied
  menu gradient:       applied
  popup gradient:      applied
  keyboard gradient:   applied
  dialog gradient:     applied
  osd gradient:        applied
  reminder gradient:   applied
  bar gradient:        applied
```

## Requirements

- [Omarchy](https://github.com/) (Arch Linux, Hyprland, quickshell) with the standard shell at `/usr/share/omarchy/shell`
- `patch` (util-linux, always installed)

## How it works / "dynamic for all plugins"

Both effects are wired into **shared components** that plugins build their surfaces on — not into individual plugins:

| Shared component        | Animations | Gradient | Covers |
| ----------------------- | :--------: | :------: | ------ |
| `Ui/PopupCard.qml`      | ✓          | ✓        | bar popups — tray, media, island panel … |
| `Ui/KeyboardPanel.qml`  | ✓          | ✓        | audio, bluetooth, clock, monitor, network, power, tailscale, weather, agents + user plugins |
| `Ui/ConfirmDialog.qml`  | ✓          | ✓        | in-window confirm overlays — menu, clipboard, plugin-manager |
| `plugins/menu/Menu.qml` | ✓          | ✓        | the main menu itself |
| `plugins/osd/Osd.qml`   |            | ✓        | volume/brightness OSD |
| `plugins/reminders/ReminderFlow.qml` | | ✓ | reminder cards |
| `plugins/bar/Bar.qml`   |            | ✓        | the top bar itself |

Because the patches touch shared components, a plugin installed later does **not** need its own animation or gradient code — if it uses `PopupCard`, `KeyboardPanel` or `ConfirmDialog`, it inherits both automatically. Individual plugins that draw their own cards (plugin-manager, notifications, quicksearch, omarchy-find, massi.menu) are discovered and patched **dynamically** at install time under `patches/plugins/`.

### Why the patches at all?

The shell only resolves `import qs.Ui` from the package directory (`/usr/share/omarchy/shell/Ui`); quickshell ignores `QML_IMPORT_PATH` for it. So a component living in `~/.config/omarchy` cannot be imported on its own. The install script bridges that with:

1. a symlink `/usr/share/omarchy/shell/Ui/animwindow.qml` → your user file,
2. one `qmldir` registration line (`AnimWindow 1.0 animwindow.qml`),
3. reversible `patch`-based edits that use `AnimWindow` and add the gradient in the shared components,
4. per-plugin gradient patches applied automatically to installed plugins that have their own card surfaces.

Everything the script changes in `/usr/share` is reverted by `uninstall` and safely re-applied by re-running `install` after an `omarchy update` resets the package files.

## Install

1. Put the files where the script expects them (the script reads from your user config, **not** from this repo at runtime):

   ```sh
   mkdir -p ~/.config/omarchy/shell/Ui ~/.local/bin
   cp animwindow.qml ~/.config/omarchy/shell/Ui/
   cp -r patches ~/.config/omarchy/
   cp omarchy-animwindow ~/.local/bin/
   chmod +x ~/.local/bin/omarchy-animwindow
   ```

2. Install (elevation defaults to `sudo`; on a clone with only `pkexec`, use `SUDO=pkexec`):

   ```sh
   ~/.local/bin/omarchy-animwindow install
   ```

   This adds the symlink + registration, applies all shared and per-plugin patches, and restarts the shell. Everything is live immediately.

3. Check the new state:

   ```sh
   ~/.local/bin/omarchy-animwindow status
   ```

## Usage

```
omarchy-animwindow {install|uninstall|status}

  install     # add symlink + qmldir + all shared + per-plugin patches, restart shell
  uninstall   # revert everything, restart shell
  status      # show which pieces are currently applied
```

Environment:

- `SUDO=pkexec omarchy-animwindow install` — use `pkexec` for elevation instead of `sudo`.
- `OMARCHY_NO_RESTART=1` — skip the `omarchy restart shell` at the end (useful for testing).

After **any** `omarchy update`, re-run `install`; package-file edits are lost on update by design, and the command is idempotent — it only patches what is pristine.

## Gradient borders per theme (no patching)

The border color can itself be a gradient, matching the background wash, **entirely from `shell.toml`** — the Omarchy border system already renders `"<color1> <color2> <angle>deg"` border tokens on every surface (popup cards, keyboard panels, OSD, menu, the bar has no border but shares the wash). No QML patch is involved for this part.

Set each theme's `[popups]` and `[menu]` `border` token to a vertical fade of the theme's accent/border color:

```toml
[popups]
border  = "rgba(ebc894ff) rgba(ebc89400) 90deg"
border-alpha = 0.7

[menu]
border = "rgba(ebc894ff) rgba(ebc89400) 90deg"
```

Apply the change to the running shell (no restart needed):

```sh
COLORS=$(base64 -w0 ~/.config/omarchy/themes/<theme>/colors.toml)
SHELL=$(base64 -w0 ~/.config/omarchy/themes/<theme>/shell.toml)
omarchy-shell shell applyTheme "$COLORS" "$SHELL"
```

`themes/` in this repo holds the config files (`shell.toml` + `colors.toml`) for the themes that ship these gradient borders:

## Customizing AnimWindow

Edit the defaults in `~/.config/omarchy/shell/Ui/animwindow.qml` (this file in the repo), then re-run `install`:

```qml
property real duration: 260            // ms to fully open
property real closeDuration: 195       // ms to fully close (defaults to 0.75 × duration)
property real slideY: 40.0             // px the surface travels while animating
property real startScale: 0.96         // scale at fully closed
```

Or override per instance, e.g. `AnimWindow { id: anim; open: root.open; duration: 180 }`.

## AnimWindow API

| Property       | Type   | Notes                                                          |
| -------------- | ------ | -------------------------------------------------------------- |
| `open`         | `bool` | required; drives the animation direction                       |
| `openness`     | `real` | animates `1` when open, `0` when closed (OutCubic)             |
| `closing`      | `bool` | read-only; `true` while the close animation runs               |
| `duration`     | `real` | open duration, ms (default 260)                                |
| `closeDuration`| `real` | close duration, ms (default `round(duration * 0.75)`)          |
| `slideY`       | `real` | slide distance used by the attached surfaces (default 40)      |
| `startScale`   | `real` | closed-state scale (default 0.96)                              |

Used in your own component or plugin:

```qml
import qs.Ui

PanelWindow {
  visible: root.opened || anim.closing
  AnimWindow { id: anim; open: root.opened }

  BorderSurface {
    opacity: anim.openness
    y: baseY + (1 - anim.openness) * anim.slideY
    scale: anim.startScale + anim.openness * (1 - anim.startScale)
  }
}
```

## Gradient patch format

Each gradient patch (under `patches/gradient/`) inserts a `Rectangle` block right after the surface's `radius:` binding:

```qml
Rectangle {
  anchors { top: parent.top; left: parent.left; right: parent.right; margins: 1 }
  height: Math.min(parent.height, 160)
  radius: Style.cornerRadius - 1
  gradient: Gradient {
    GradientStop { position: 0; color: Util.alpha(Color.accent, 0.085) }
    GradientStop { position: 1; color: "transparent" }
  }
}
```

The gradient patches overlay the anim-applied state — the installer always applies animation first, then gradient.

## Uninstall

```sh
~/.local/bin/omarchy-animwindow uninstall
```

Reverts gradient patches, then animation patches (in that order), removes the `animwindow.qml` symlink and its `qmldir` line, and restarts the shell with the stock visuals.

## Troubleshooting

- **Shell/menu doesn't open after install** — a QML compile error (e.g. `AnimWindow` unavailable) fails the plugin load. Check `journalctl --user -p err -n 40 --since "1 min ago"`. Symptoms like `"openness" is a read-only property` mean `animwindow.qml` has an incompatible edit: `openness` must **not** be `readonly` (a `Behavior` cannot target a read-only property). Revert the edit and re-install.
- **`patch` refuses to run / "can't find file to patch"** — the patches use `a/`/`b/` relative paths on purpose; they must be applied with `-p1` and the full target path (the script does this).
- **`sudo: a terminal is required`** — elevated commands in a non-interactive shell; use `SUDO=pkexec`.
- **`omarchy update` wipes the effect** — run `install` again; it's idempotent and will only patch pristine files.

## Notes

- This is a customization layer on top of Omarchy; nothing here modifies Hyprland or GTK config.
- The patches are generated with `diff -u` against pristine package files and are human-readable — inspect them under `patches/` before applying.
- Plugin patches under `patches/plugins/` are applied only when the matching plugin directory exists under `~/.config/omarchy/plugins/`.
