# IVORY ESP (Roblox Luau)

Class-based, modular client-side ESP with a dark dashboard inspired by the provided D3F screenshot. **All UI labels are in English, without emojis.**

**Status:** Implementation is committed on PR #1, but Roblox/Xeno runtime testing remains necessary. The repository is **public**: don't commit secrets.

## Features

- Dashboard with Home, ESP, Monsters and Settings tabs, plus FPS/ping readouts.
- All ESP toggles are functional and stored in config.lua.
- Player boxes, names, health bars, distance labels and through-wall highlights (player ESP is OFF by default).
- Separate `Other NPC ESP` toggle (OFF by default): traders/vendors are not included in monster ESP.
- Monster discovery uses hostile tags/names/attributes or user-registered model names; friendly NPC Humanoids are no longer automatically classified as monsters.
- Thrown HandCatch models (e.g. `Workspace.DhabHandCatches.HandCatch_6d67eea5cb324ca780fff2c0e7e6ec5d`) have independent blue ESP in a dedicated **HandCatch** tab. Thrown HandCatch can never be chosen by auto-aim.
- Each live Dhab displays a quality label above its model name; HandCatch can also show available captured-creature quality. The per-instance quality reader tries model/descendant attributes, StringValue/NumberValue/IntValue fields and explicitly labeled quality text. Missing replicated values are shown as `Quality: Unknown` rather than invented.
- `Targets` tab lets you select a real nearby model (including custom creatures) and track/untrack its name. Registered names survive loader re-execution in the current executor session.
- Detection distance defaults to 1200 studs and changes in 100-stud steps.
- New **Auto Shoot** tab (OFF by default): activates the equipped Roblox Tool only when a live DhabWild model is selected, centered in the crosshair and visible (line-of-sight check on by default). It has an adjustable 1–8 shots/second limit and an in-GUI status message. Turning it ON also enables camera aim; switching Aim OFF pauses shooting. Thrown HandCatch, vendors, players and other monsters are never shot.
- `Auto Aim` only rotates the camera toward **live DhabWild Models** (not discarded HandCatch, traders, plots, or other monsters). The tab has an aim toggle (OFF by default), optional right-mouse hold, FOV circle, adjustable FOV radius, target distance and smoothing. Does not fire weapons or send attack events.
- Camera FOV slider (40 to 120 degrees) under Settings.
- **I** toggles all ESP overlays while keeping the dashboard, FOV, and independently controlled auto-aim available.
- **Right Ctrl** hides/shows the large dashboard (the aim circle continues to display). You can also click the HIDE [CTRL] button in the header.
- **M** marks the target model under the cursor as a monster (same model name for all instances); alternatively use Targets > TRACK.
- **P** inspects the creature at your cursor. If you hit Terrain or another obstacle, it tries a raycast excluding Terrain and checks recognized NPCs near your cursor.
- **O** lists nearby recognized Dhab creatures, thrown HandCatch, and unclassified Workspace models with names and paths (25 max per group); also available via the Find models dashboard button. Diagnostics print to F9 and copy to clipboard if supported.
- One 30 Hz render coordinator, cleanup on re-execution.

## In-game load notifications and troubleshooting

The remote `main.lua` creates an independent dark notification at the top-right before fetching feature modules. It reports loading progress, **IVORY ESP - Loaded** once the dashboard starts, or **IVORY ESP - Load failed** with the failing module/error. Failure details are also printed in the F9 developer console. This notification works even if the main ESP GUI cannot initialize (provided `main.lua` itself downloads).

Monster scanning is scheduled separately and yields periodically on large worlds, so it should not block dashboard startup. Monster overlays may appear after the dashboard becomes ready.

If no notification appears at all, the initial `game:HttpGet(.../main.lua)` or `loadstring` may have failed in the executor. Use this diagnostic launcher to surface that outer error:

```lua
local ok, err = pcall(function()
    getgenv().IvoryESP_Ref = "feature/modular-ivory-esp"
    local source = game:HttpGet(
        "https://raw.githubusercontent.com/7ejal/rbl-scr/feature/modular-ivory-esp/main.lua"
    )
    local run = assert(loadstring(source))
    run()
end)
if not ok then
    warn("[IVORY BOOT ERROR] " .. tostring(err))
    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title = "IVORY ESP - Boot error",
            Text = "Open F9 and copy the IVORY BOOT ERROR line.",
            Duration = 12,
        })
    end)
end
```

## Test the open PR branch

In a trusted executor supporting game:HttpGet and loadstring:

    getgenv().IvoryESP_Ref = "feature/modular-ivory-esp"
    loadstring(game:HttpGet("https://raw.githubusercontent.com/7ejal/rbl-scr/feature/modular-ivory-esp/main.lua"))()

After review and merge, use:

    getgenv().IvoryESP_Ref = "main"
    loadstring(game:HttpGet("https://raw.githubusercontent.com/7ejal/rbl-scr/main/main.lua"))()

Calling getgenv().IvoryESP_Stop() removes overlays, UI and listeners, and restores the starting FOV. A new load replaces the previous instance. Running fetched scripts trusts the repository code; review modifications before loading.

## Monster identification

The in-game scan revealed a creature model `Workspace.DhabWild.Dhab_fa1f92` about 121 studs away, which the earlier tracker missed. `WildlifeFolderName = "DhabWild"` now matches individual wildlife models or loose parts from that specific source. Nested rig parts, cars, plot scenery and the root container are excluded. This identifies wildlife, **not necessarily hostile monsters**.

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
| src/MonsterTracker.lua | DhabWild / DhabHandCatches / other NPC classification, manual registration |
| src/HandCatchESP.lua | Independent overlay for thrown HandCatch (blue; never aim) |
| src/QualityResolver.lua | Per-instance replicated quality source lookup; unknown fallback |
| src/QualityESP.lua | Dhab / HandCatch quality label |
| src/MonsterESP.lua | Composes monster visuals |
| src/MonsterInspector.lua | Inspect hovered monster (P), scan nearby (O), register (M) |
| src/AimController.lua | Live-Dhab-only camera targeting and FOV circle |
| src/AutoShootController.lua | Equipped Tool auto-activation, rate limit and visibility checking |
| src/Projection.lua | Bounding-box projection |
| src/BoxESP.lua | Screen box |
| src/NameESP.lua | Label |
| src/DistanceESP.lua | Stud distance label |
| src/HealthESP.lua | Health bar |
| src/HighlightESP.lua | Through-wall Highlight |
| src/FOVController.lua | Camera FOV |
| src/UIController.lua | Dark dashboard: ESP, Auto Aim, Auto Shoot, Monsters, HandCatch, Targets, Settings |
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
- Auto Shoot calls `Tool:Activate()` / `Tool:Deactivate()` on an **already equipped Tool**. A custom game weapon that uses its own input handler/RemoteEvent might not respond. This script does not spoof game-specific remotes, equip tools, or bypass ammunition/cooldowns. Disable Auto Shoot to stop activations.
- Auto aim rotates the local camera only; it does not modify weapon hits, attack accuracy or server behavior. Targets MUST be live Dhab models inside `Workspace.DhabWild`; no HandCatch can ever be targeted.
- Quality and rarity aren't equivalent. The label reflects the actual field name when `Rarity` or `Grade` is found. If no per-model quality metadata is available to the client, the script displays `Quality: Unknown`. Press P to inspect the exact object and its replicated attributes for diagnosis.
- Target names added through the GUI or M are remembered only in the current client session; for persistence across Roblox launches, copy exact names into `config.lua`.
- The script is untested in a live Xeno/Roblox runtime; follow tests/MANUAL_TESTS.md.
- Automatic HandCatch detection requires the object to be replicated under `Workspace.DhabHandCatches`. If your thrown object is stored elsewhere, inspect its path (P/O) and change `HandCatchFolderName` in `config.lua`.


## Cars ESP and live Dhab quality diagnostics (October 26, 2026)

The in-game scan revealed \`Workspace.PlayersCars.DH_8638378195_SHAS_2025__2\` with nested \`Wheels\`, \`Tire\`, \`Body\` and accessories. **Cars** now has independent purple outlines, whole-car boxes, names, distances and highlights. Classification accepts **only direct car Models** in \`Workspace.PlayersCars\` so wheels/tires don't generate separate ESP. Cars are never aim or shoot targets.

**Quality** now has a dedicated tab. Press **Inspect nearest Dhab quality** to identify a nearby Dhab, display its source, model attributes and candidate quality metadata in the GUI. It also copies the report to the clipboard if available and stores the text in \`getgenv().IvoryQualityReport\`. F9 is not required. The \`O\` nearby scan includes each Dhab's resolved quality and a separate whole-car section.

\`src/QualityResolver.lua\` reads the creature's own attributes and nested Value objects first, followed by explicitly labeled quality text. When needed, it scans bounded, cached replicated metadata in \`ReplicatedStorage\` and \`PlayerGui\` and accepts an **exact Dhab ID match only**. It does not infer quality from a name or reuse another Dhab's value.

**Crucial:** The scan identifies model paths but does not establish where quality is stored in the game. If a Dhab still shows \`Quality: Unknown\`, the client may not have the value. Inspect the report and—because you own the game—consider copying the authoritative server-side quality onto a replicated \`Quality\` model attribute in Roblox Studio. This is more reliable than guessing from client model names.

Added: \`src/CarESP.lua\` (one ESP per whole car). Existing class-based features and HandCatch isolation remain intact.

**Best guaranteed quality integration for your own game:** See [Server-side Dhab Quality Integration](docs/QUALITY_SERVER_INTEGRATION.md) for instructions to expose each animal's authoritative Quality attribute to the client, including thrown HandCatch copies. The inspector cannot recover server-only quality that was never replicated.

## Anti Fog (Settings)

Open **Settings → Anti Fog (clear haze)**. This independent OFF-by-default control uses `src/AntiFogController.lua` to locally set `Lighting.FogStart`/`FogEnd` far away and clear the `Atmosphere.Density`, `Haze` and `Glare` properties. The change is client-side, does not remove any objects, and periodically reapplies while enabled if the game adjusts the weather. Existing and newly added Atmosphere instances are supported. Turning the toggle OFF or running `getgenv().IvoryESP_Stop()` restores the recorded fog and atmosphere values from when Anti Fog was enabled.

This does **not** remove opaque particle effects, smoke parts, blur effects, or custom shader-based fog. If the game applies different weather settings while Anti Fog is running, the restored values are the settings captured when toggled ON; subsequent game weather scripts may change them again. Reference: [Roblox Atmosphere documentation](https://create.roblox.com/docs/environment/atmosphere) and [Lighting class](https://create.roblox.com/docs/reference/engine/classes/Lighting).

## Auto Shoot input fix: real left-click

The game weapon requires a **left mouse click**. The former `Tool:Activate()` mode could report attempted activation even when the custom weapon ignored it.

**Auto Shoot → Fire input** now defaults to **Left Click** and sends a supported executor `mouse1click()` action when a live DhabWild target is selected and centered. If `mouse1click()` isn't exposed, the script tries a timed `mouse1press()`/`mouse1release()` pair. You can switch to **Tool** mode for standard Roblox Tools; Tool mode still requires an equipped Tool. In Left Click mode, custom weapons do not have to be represented as an equipped Roblox Tool.

Left Click is subject to executor support and may activate GUI buttons or click the current cursor position. Hide the dashboard with **Right Ctrl** or move the pointer off it when firing. Aim, distance, center, line-of-sight, optional right-mouse requirement and rate limits still apply. Mouse clicks only occur on the current Roblox client; this does **not** guarantee that the specific weapon will fire or hit, because game-specific input and server validation can differ.

The **Auto Shoot** tab reports `Xeno does not expose mouse1click` when neither supported input API is accessible. If the status says **Auto shooting: left click** but no bullets fire, determine whether the equipped weapon uses actual mouse input or requires a particular cursor position, ammo, or its own weapon handler.

## Verified client-side Dhab attributes (user-provided October 26, 2026 report)

The new read-only client report proves each examined `Workspace.DhabWild.Dhab_<id>` model exposes `Uid`, `Tier` (T1, T2, T3), `Length` (studs), `State` (walk/idle), `Scale`, `Speed`, and other rig attributes. **None of the inspected five models had a distinct Quality or Rarity attribute.** `Tier` is therefore displayed as **Tier**, not mislabeled as Rare/Common or as a quality percentage. The new `src/DhabStatsESP.lua` displays `Tier | Length | State` above each live Dhab in real time, with an independent toggle in the Quality tab. The `O` scan and Quality diagnostic include verified Tier values.

A potential next source for rarity mapping is the replicated `ReplicatedStorage.Dhab.Config.Dhab` ModuleScript. If inspecting it through the game's own permitted developer environment, validate whether it defines tiers, rarity names and weights. Do not claim a mapping until proven. If quality is server-only, the official game code needs to replicate it.

## Simplified live Dhab labels: Tier, Length, Size

By request, the default Dhab ESP now displays **only verified Tier, Length and Size** values above each creature. It reads the replicated model attributes `Tier`, `Length` (studs) and `Scale` (shown as `Size ...x`, a **scale multiplier**, not a measured width/height). Example based on the supplied game scan:

```text
Tier T2 | Length 5.42 studs | Size 2.15x
```

Movement State and unverified Quality/Rarity no longer appear in the standard Dhab ESP label or nearby O-key summary. `DhabQualityEnabled` and `HandCatchQuality` default OFF to avoid clutter from `Quality: Unknown`. The optional quality diagnostic remains available for further investigation but is not required for ESP. Switch **Quality → Show Dhab Tier / Length / Size** to control the three-field label. Other existing ESP, Auto Aim, Auto Shoot, Cars and Anti Fog settings are unchanged.


## Auto Hunt: live Dhab only

Auto Hunt is implemented in src/AutoHuntController.lua, has a separate English GUI page, and is **OFF by default**.

- Searches for the nearest living, replicated Dhab model within the chosen search radius (default 700 studs, adjustable 100–2000).
- Uses normal Humanoid:MoveTo and PathfindingService for walking toward the Dhab. No teleportation, vehicle control, item pickup or server remotes.
- Stops at the configured distance (default 28 studs, adjustable 10–100). Retargets when the animal disappears or dies.
- Aims at that exact Dhab when it enters the existing camera AimDistance. Never hunts cars, HandCatch, vendors, player characters or scenery.
- The Auto Shoot during hunt toggle (ON by default, but no effect until Auto Hunt itself is turned ON) invokes the existing left-click or Tool shooter, with line-of-sight, centering and rate checks. Turning Hunt off also turns off its implicit shooting; independent Auto Shoot settings are never overwritten.
- Pauses automatic walking while WASD/arrow keys are pressed or a text box is focused. Resumes after manual movement stops.
- Cannot hunt while dead, respawning, seated or without a Humanoid. Disabling Hunt, reloading, or stopping the script cancels navigation and releases the selected target.
- Use Right Ctrl to hide the dashboard so simulated left-click does not click a menu button. The status line shows the target, range, navigation mode or reason for pausing.
- Dynamic desert terrain or games restricting local character movement may prevent reliable pathfinding. No live Roblox/Xeno testing has been performed; see tests/MANUAL_TESTS.md.


## Six improvements to Auto Hunt (October 26, 2026)

All six enhancements are implemented in the feature branch:

1. Smart Target Selection: select Closest, Longest (actual Length attribute) or Largest (actual Scale attribute); filter Tier T1-T6, unknown tiers, and minimum Length. Live Dhab only. Tier is not converted into an unverified rarity.
2. Better navigation: retries paths and walking around obstructions, detects repeated no-progress episodes, then temporarily skips the unreachable Dhab for 35 seconds. No teleportation.
3. Smarter shooting: configurable standalone Auto Shoot max distance (default 160 studs) and hunt shooting distance (default 85 studs); both apply in hunt. Existing line-of-sight and centered-aim guards and rate limit remain. Dead targets are not fired on.
4. Dhab Radar: optional radar overlay (OFF by default), up to 30 live Dhab within customizable range; white center is player, orange are Dhab, green is the chosen hunt target. Camera-relative, client-side.
5. Hunt Statistics: session duration, targets selected, unreachable skips, shot attempts and input dispatches; confirmed hits/catches are explicitly unavailable without a verified client event. Session-only counters, no invented kills or catch figures. Stats may be toggled off or reset.
6. Settings Persistence: Statistics page opt-in (OFF by default) saves only whitelisted preferences in a per-PlaceId local JSON file when Xeno implements readfile/writefile. Includes ESP, target tiers, range, priority, input mode, FOV and radar. No secrets are stored. Turning this off writes an opt-out flag. If file APIs are unavailable, script runs normally without persistence.

UI: Sidebar is scrollable for Radar and Statistics tabs, and the Auto Hunt/Auto Shoot pages scroll to show advanced controls. No automatic looting, server damage calls or game-specific remotes have been added.

These are GitHub implementation changes; live Roblox/Xeno behavior is not tested. Custom weapon inputs and PathfindingService may behave differently in the actual game. If no confirmed owner-linked catch event is exposed to the client, the program does NOT fabricate successful catches.
