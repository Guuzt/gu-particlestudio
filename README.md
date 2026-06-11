<div align="center">

# gu-particlestudio

**In-game particle effect (PTFX) placement studio for RedM**

Browse, search, preview and place any RDR3 particle effect directly in the world —
with live preview, free camera, height control and full sync between players.

![RedM](https://img.shields.io/badge/RedM-RDR3-b8281e?style=flat-square)
![Standalone](https://img.shields.io/badge/dependencies-none-2d7d46?style=flat-square)
![Frameworks](https://img.shields.io/badge/frameworks-RSG%20%7C%20VORP%20%7C%20standalone-8a6d3b?style=flat-square)
![License](https://img.shields.io/badge/license-MIT-blue?style=flat-square)

</div>

---

<!-- Add your screenshots / preview video here
![preview](docs/preview.png)
-->

## Features

- **Full PTFX catalog** — browse every Looped and NonLooped particle dictionary in the game
- **Global search** — find any effect by name across all dictionaries, with live filtering
- **Recent & Continue** — jump back to your last dictionary or recently placed effects
- **Live configuration** — adjust scale, rotation X/Y/Z and duration with sliders before placing
- **Two-phase placement** — lock the XY position first, then fine-tune the height
- **Free camera** — detach from your character to place effects anywhere, including mid-air
- **Active effects manager** — move, edit or delete any placed effect at any time
- **Synced for everyone** — effects are server-authoritative and visible to all players
- **Timed effects** — optional duration with automatic server-side cleanup
- **Lua export** — print all placed effects as a ready-to-use Lua table (events, ambience, decoration, cinematics — whatever you need)
- **RDR2-style UI** — custom NUI menu built with the game's own visual language; no menu library required

## No dependencies

Everything is built in: menu, dialogs, notifications and HUD all run on the resource's own NUI.
No btc-core, no ox_lib, no menu library — just drop it in and start the server.

Works with **RSG**, **VORP**, or **fully standalone**. The framework is detected automatically at
runtime; only the permission check adapts per framework.

## Installation

1. Drop the `gu-particlestudio` folder into your server's `resources` directory.
2. Add to your `server.cfg`:
   ```cfg
   ensure gu-particlestudio
   ```
3. Grant access (default `Config.Permission = 'admin'`):

| Framework | How the permission is checked |
|---|---|
| **RSG** | Player has the `admin` permission level in RSGCore |
| **VORP** | Player's character `group` equals `admin` |
| **Standalone** | ACE — add `add_ace group.admin admin allow` to `server.cfg` |

## Usage

Open the studio with the chat command:

```
/particlestudio
```

### Placement controls

| Key | Action |
|---|---|
| `Enter` | Phase 1: lock XY position → Phase 2: confirm placement |
| `G` | Phase 2: back to phase 1 → Phase 1: cancel |
| `Scroll` / `E` / `Q` | Phase 2: adjust height — Free cam: move up/down |
| `Space` / `Shift` | Phase 2: raise/lower height — Free cam: move up/down |
| `Arrow keys` | Rotate the effect (←/→ = yaw, ↑/↓ = pitch) |
| `F` | Toggle free camera |
| `WASD` + `Mouse` | Move / look with the free camera |

### Exporting

Use **Export Positions** in the menu to print every placed effect to the F8 console as a
Lua table — ready to paste into your own scripts.

## Configuration

All options live in [`config/config.lua`](config/config.lua):

| Option | Default | Description |
|---|---|---|
| `Config.Permission` | `admin` | Permission level / group / ACE required |
| `Config.Command` | `particlestudio` | Chat command that opens the menu |
| `Config.Locale` | `eng` | `eng` or `pt-br` |
| `Config.DefaultScale` | `1.0` | Initial scale for new effects |
| `Config.DefaultDuration` | `0` | Default duration in seconds (0 = permanent) |
| `Config.PlacementDistance` | `50.0` | Max raycast distance in metres |
| `Config.HeightStep` | `0.1` | Height change per scroll tick (metres) |
| `Config.FreeCamSpeed` | `0.3` | Free camera speed |
| `Config.Keys` | — | All key bindings (RDR3 `INPUT_` names) |

Notifications use the built-in NUI toasts; swap the `Notify` function at the bottom of the
config if you prefer your own notification system.

## Language 

Ships with `eng` (default) and `pt-br`. Add your own language by extending
[`locale.lua`](locale.lua) and setting `Config.Locale`.

