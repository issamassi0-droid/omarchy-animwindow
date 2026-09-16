# omarchy-animwindow

oshelf-style open/close animations (slide + fade + scale) for the Omarchy quickshell — applied dynamically through the shell's shared `qs.Ui` components, so **any** plugin, current or future, that builds on them inherits the animation automatically.

## What it does

The main menu, bar popups (tray, media), the panels (audio, bluetooth, clock, network, weather, ...) and confirm dialogs open with the same smooth animation oshelf uses: content slides in while fading and scaling up, and reverses on close — instead of popping in/out instantly.

```
omarchy-animwindow status

  component: installed
  menu patch:          applied
  popup patch:         applied
  keyboard panel patch: applied
  confirm dialog patch: applied
```

## Requirements

- [Omarchy](https://github.com/) (Arch Linux, Hyprland, quickshell) with the standard shell at `/usr/share/omarchy/shell`
- `patch` (util-linux, always installed)

## How it works / "dynamic for all plugins"

The animation is a tiny reusable QML component, `AnimWindow`. It is wired into the **shared components** that plugins build their surfaces on, not into individual plugins:

| Shared component        | Reads as                                       | Covers                                                            |
| ----------------------- | ---------------------------------------------- | ----------------------------------------------------------------- |
| `Ui/PopupCard.qml`      | bar popups                                     | tray, media, osd …                                                |
| `Ui/KeyboardPanel.qml`  | panels                                         | audio, bluetooth, clock, dropbox, monitor, network, power, tailscale, weather, agents + user plugins |
| `Ui/ConfirmDialog.qml`  | in-window confirm overlays                     | menu, clipboard, plugin-manager                                   |
| `plugins/menu/Menu.qml` | the main menu                                  | the main menu itself                                              |

Because the patches touch shared components, a plugin installed later does **not** need its own animation code — if it uses `PopupCard`, `KeyboardPanel` or `ConfirmDialog`, it animates out of the box. (Plugins that ship their own bespoke `PanelWindow`s won't inherit; add the `AnimWindow` pattern to them to animate those.)

### Why the patches at all?

The shell only resolves `import qs.Ui` from the package directory (`/usr/share/omarchy/shell/Ui`); quickshell ignores `QML_IMPORT_PATH` for it. So a component living in `~/.config/omarchy` cannot be imported on its own. The install script bridges that with:

1. a symlink `/usr/share/omarchy/shell/Ui/animwindow.qml` → your user file,
2. one `qmldir` registration line (`AnimWindow 1.0 animwindow.qml`),
3. reversible `patch`-based edits that use `AnimWindow` inside the shared components.

Everything the script changes in `/usr/share` is reverted by `uninstall` and safely re-applied by re-running `install` after an `omarchy update` resets the package files.

## Install

1. Put the files where the script expects them (the script reads from your user config, **not** from this repo at runtime):

   ```sh
   mkdir -p ~/.config/omarchy/shell/Ui ~/.config/omarchy/patches ~/.local/bin
   cp animwindow.qml ~/.config/omarchy/shell/Ui/
   cp patches/*.patch ~/.config/omarchy/patches/
   cp omarchy-animwindow ~/.local/bin/
   chmod +x ~/.local/bin/omarchy-animwindow
   ```

2. Install (elevation defaults to `sudo`; on a clone with only `pkexec`, use `SUDO=pkexec`):

   ```sh
   ~/.local/bin/omarchy-animwindow install
   ```

   This adds the symlink + registration, applies all four patches, and restarts the shell. The animation is live immediately.

3. Check the new state:

   ```sh
   ~/.local/bin/omarchy-animwindow status
   ```

## Usage

```
omarchy-animwindow {install|uninstall|status}

  install     # add symlink + qmldir + menu + popup + panel + dialog patches, restart shell
  uninstall   # revert everything, restart shell
  status      # show which pieces are currently applied
```

Environment:

- `SUDO=pkexec ~/.local/bin/omarchy-animwindow install` — use `pkexec` for elevation instead of `sudo`.

After **any** `omarchy update`, re-run `install`; package-file edits are lost on update by design, and the command is idempotent — it only patches what is pristine.

## Customizing

Edit the defaults in `~/.config/omarchy/shell/Ui/animwindow.qml` (this file in the repo), then re-run `install`:

```qml
property real duration: 260            // ms to fully open
property real closeDuration: 195       // ms to fully close (defaults to 0.75 × duration)
property real slideY: 40.0             // px the surface travels while animating
property real startScale: 0.96         // scale at fully closed
```

Or override per instance, e.g. `AnimWindow { id: anim; open: root.open; duration: 180 }`.

## AnimWindow API

| Property     | Type    | Notes                                                          |
| ------------ | ------- | -------------------------------------------------------------- |
| `open`       | `bool`  | required; drives the animation direction                       |
| `openness`   | `real`  | animates `1` when open, `0` when closed (OutCubic)             |
| `closing`    | `bool`  | read-only; `true` while the close animation runs               |
| `duration`   | `real`  | open duration, ms (default 260)                                |
| `closeDuration` | `real` | close duration, ms (default `round(duration * 0.75)`)        |
| `slideY`     | `real`  | slide distance used by the attached surfaces (default 40)      |
| `startScale` | `real`  | closed-state scale (default 0.96)                              |

Used in your own component or plugin:

```qml
import qs.Ui

PanelWindow {
  visible: root.opened || anim.closing   // stay mapped during the close fade
  AnimWindow { id: anim; open: root.opened }

  BorderSurface {
    opacity: anim.openness
    y: baseY + (1 - anim.openness) * anim.slideY        // slide in from above
    scale: anim.startScale + anim.openness * (1 - anim.startScale)
  }
}
```

## Uninstall

```sh
~/.local/bin/omarchy-animwindow uninstall
```

Reverts all four patches, removes the `animwindow.qml` symlink and its `qmldir` line, and restarts the shell with the stock animations.

## Troubleshooting

- **Shell/menu doesn't open after install** — a QML compile error (e.g. `AnimWindow` unavailable) fails the plugin load. Check `journalctl --user -p err -n 40 --since "1 min ago"`. Symptoms like `"openness" is a read-only property` mean `animwindow.qml` has an incompatible edit: `openness` must **not** be `readonly` (a `Behavior` cannot target a read-only property). Revert the edit and re-install.
- **`patch` refuses to run / "can't find file to patch"** — the patches use `a/`/`b/` relative paths on purpose; they must be applied with `-p1` and the full target path (the script does this).
- **`sudo: a terminal is required`** — elevated commands in a non-interactive shell; use `SUDO=pkexec`.

## Notes

- This is a customization layer on top of Omarchy; nothing here modifies Hyprland or GTK config.
- The patches are generated with `diff -u` against pristine package files and are human-readable — inspect them under `patches/` before applying.