# IVORY ESP (Roblox Luau)

Modular, client-side player ESP for the owner of this repository. Each feature is implemented in its own class-style Luau module; the main entry point loads the modules on demand.

**Status:** Initial implementation awaiting testing inside Roblox/Xeno. This repository is **public**. Never commit executor credentials, Roblox cookies, or other secrets.

## Features

- Red player outlines/boxes, green for teammates
- Built-in Roblox Highlight visible through walls
- Player display names, distance in studs, and health bars
- Press **I** or click the ESP button to toggle the visual overlay
- Mouse/touch camera FOV slider (**40–120**) stays usable with ESP off
- Automatic player join/leave/respawn handling
- 30 Hz box refresh (configurable), one shared frame loop
- Clean re-execution: old UI, event listeners, and highlights are removed

## Loader (after merging this PR into main)

Paste in a trusted Luau executor that supports both loadstring and game:HttpGet:

    loadstring(game:HttpGet("https://raw.githubusercontent.com/7ejal/rbl-scr/main/main.lua"))()

## Test the PR branch before merging

    getgenv().IvoryESP_Ref = "feature/modular-ivory-esp"
    loadstring(game:HttpGet("https://raw.githubusercontent.com/7ejal/rbl-scr/feature/modular-ivory-esp/main.lua"))()

After merging, remove IvoryESP_Ref or set it to "main". Running remotely fetched code trusts the repository contents; review changes before execution. Compatibility with any specific Xeno release has not been verified.

To turn everything off and restore the starting FOV:

    getgenv().IvoryESP_Stop()

## Architecture

| File | Responsibility |
| --- | --- |
| main.lua | Fetch all modules, start and replace a running instance |
| config.lua | Central settings and keybind |
| src/ESPController.lua | App lifecycle and 30 Hz render coordinator |
| src/PlayerTracker.lua | Join/leave subscriptions |
| src/PlayerESP.lua | One player's module composition |
| src/Projection.lua | 3D-to-2D bounding box projection |
| src/BoxESP.lua | 2D outline |
| src/NameESP.lua | Display name |
| src/DistanceESP.lua | Distance label |
| src/HealthESP.lua | Health bar |
| src/HighlightESP.lua | Wall-visible highlight |
| src/FOVController.lua | Camera FieldOfView |
| src/UIController.lua | Toggle and FOV slider UI |
| src/KeybindController.lua | I shortcut |
| src/Janitor.lua | Connection/instance cleanup |

To change one feature, edit its class module. main.lua does not need to be recopied for module edits.

## Technical notes

- Standard Roblox Instances are used instead of the executor-specific Drawing API.
- Camera FieldOfView is held at the chosen value while running. Disabling ESP does not reset FOV; calling IvoryESP_Stop does.
- No server-side abilities are added. Streaming and client replication limit which characters are visible.
- GetBoundingBox is sampled per player at up to 30 Hz. If you target large servers, lower RenderFPS or MaxDistance in config.lua.
- Highlight instances have a Roblox engine rendering limit.
- Real-world validation: see tests/MANUAL_TESTS.md.
