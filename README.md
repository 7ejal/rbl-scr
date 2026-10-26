# IVORY ESP (Roblox Luau)

Class-based, modular client-side ESP with a dark dashboard inspired by the provided D3F screenshot. **All UI labels are in English, without emojis.**

**Status:** Implementation is committed on PR #1, but Roblox/Xeno runtime testing remains necessary. The repository is **public**: don't commit secrets.

## Features

- Dashboard with Home, ESP, Monsters and Settings tabs, plus FPS/ping readouts.
- All ESP toggles are functional and stored in config.lua.
- Player boxes, names, health bars, distance labels and through-wall highlights (player ESP is OFF by default).
- Separate `Other NPC ESP` toggle (OFF by default): traders/vendors are not included in monster ESP.
- Monster discovery uses hostile tags/names/attributes or user-registered model names; friendly NPC Humanoids are no longer automatically classified as monsters.
- `Targets` tab lets you select a real nearby model (including custom creatures) and track/untrack its name. Registered names survive loader re-execution in the current executor session.
- Detection distance defaults to 1200 studs and changes in 100-stud steps.
- `Auto Aim` tab has a monster-only camera aim toggle (OFF by default), optional right-mouse hold, FOV circle, adjustable FOV radius, target distance and smoothing. Does not fire weapons or send attack events.
- Camera FOV slider (40 to 120 degrees) under Settings.
- **I** toggles all ESP overlays while keeping the dashboard, FOV, and independently controlled auto-aim available.
- **Right Ctrl** hides/shows the large dashboard (the aim circle continues to display). You can also click the HIDE [CTRL] button in the header.
- **M** marks the target model under the cursor as a monster (same model name for all instances); alternatively use Targets > TRACK.
- **P** inspects the creature at your cursor. If you hit Terrain or another obstacle, it tries a raycast excluding Terrain and checks recognized NPCs near your cursor.
- **O** lists nearby recognized and unclassified Workspace models with names and full paths (25 max per group); also available via the Find models dashboard button. Diagnostics print to F9 and copy to clipboard if supported.
- One 30 Hz render coordinator, cleanup on re-execution.

## Test the open PR branch

In a trusted executor supporting game:HttpGet and loadstring:

    getgenv().IvoryESP_Ref = "feature/modular-ivory-esp"
    loadstring(game:HttpGet("https://raw.githubusercontent.com/7ejal/rbl-scr/feature/modular-ivory-esp/main.lua"))()

After review and merge, use:

    getgenv().IvoryESP_Ref = "main"
    loadstring(game:HttpGet("https://raw.githubusercontent.com/7ejal/rbl-scr/main/main.lua"))()

Calling getgenv().IvoryESP_Stop() removes overlays, UI and listeners, and restores the starting FOV. A new load replaces the previous instance. Running fetched scripts trusts the repository code; review modifications before loading.

## Monster identification

MonsterTracker separates `monster` and `other` categories. A Humanoid alone does **not** mean monster, because this game includes many merchant NPCs. Plots and common vendor/scenery names are excluded from monster matching. It recognizes common hostile names, tags and attributes, along with registered exact model names. It scans at startup, on creation and every 10 seconds. Custom creatures can be manually registered through the Targets tab or M key.

**Monster IDs are not guaranteed numeric.** Close F9 to aim, then point at an in-game monster and press **P**. If the output only says Terrain or cannot identify the model, press **O** or click Find models, then open F9 and share the nearby-model list. Pressing P or O will copy the report if your executor supports clipboard access. Share the inspector result to add precise per-game monster targeting, e.g., tiers T5/T6. An unclassified model can be scenery, not a confirmed monster.

The inspector cannot see server-only instances or unreplicated/streamed-out models.

## Architecture

| File | Responsibility |
| --- | --- |
| main.lua | Remote loader, lifecycle replacement |
| config.lua | All shared settings |
| src/ESPController.lua | App lifecycle, unified render coordinator |
| src/PlayerTracker.lua | Player join/leave |
| src/PlayerESP.lua | Composes player visuals |
| src/MonsterTracker.lua | Monster/other-NPC classification and manual registration |
| src/MonsterESP.lua | Composes monster visuals |
| src/MonsterInspector.lua | Inspect hovered monster (P), scan nearby (O), register (M) |
| src/AimController.lua | Monster-only camera targeting and FOV circle |
| src/Projection.lua | Bounding-box projection |
| src/BoxESP.lua | Screen box |
| src/NameESP.lua | Label |
| src/DistanceESP.lua | Stud distance label |
| src/HealthESP.lua | Health bar |
| src/HighlightESP.lua | Through-wall Highlight |
| src/FOVController.lua | Camera FOV |
| src/UIController.lua | Dark dashboard: ESP, Auto Aim, Monsters, Targets, Settings |
| src/KeybindController.lua | I keyboard shortcut |
| src/Janitor.lua | Listener/instance cleanup |

Each behavior has its own class-like module. Edit a module without re-copying the loader.

## Known limits

- Standard Roblox UI Instances, no Drawing library required.
- Roblox limits active Highlight renderers in large servers.
- Projected 2D rectangles are conservatively hidden when a bounding-box corner is behind the camera.
- Monsters without health data won't show health bars.
- In some games, NPCs may be friendly rather than hostile; generic matching cannot tell them apart.
- Client streaming/replication determines what the script can inspect.
- Monster auto aim rotates the local camera only; it does not modify weapon hits, attack accuracy, or server behavior. Aim target selection requires a recognized or user-registered monster.
- Target names added through the GUI or M are remembered only in the current client session; for persistence across Roblox launches, copy exact names into `config.lua`.
- The script is untested in a live Xeno/Roblox runtime; follow tests/MANUAL_TESTS.md.
