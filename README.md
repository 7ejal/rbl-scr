# IVORY ESP (Roblox Luau)

Class-based, modular client-side ESP with a dark dashboard branded as 7jl, with a compact dark dashboard. **All UI labels are in English, without emojis.**

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


## Vehicle Auto Hunt — drive from your own car

Auto Hunt now detects when **your character is already sitting as the driver** in a `VehicleSeat` inside one whole car model under `Workspace.PlayersCars`. It automatically switches from on-foot navigation to an independent `VehicleHuntController.lua`. It keeps the same verified live-Dhab targeting, priority, tier and length filters, aimed camera and optional shooting system.

Enable **Auto Hunt → Auto Hunt while driving (VehicleSeat)** (enabled by default but has no effect unless the main Auto Hunt toggle is ON). Adjust **Vehicle stopping radius** (default 48 studs), **Vehicle speed cap** (default 32 studs/second), and **Reverse vehicle steering** if your chassis faces the opposite way. You must **enter the driver's seat yourself**. It does not auto-enter, teleport, equip a vehicle, change network ownership or drive another player's car.

Vehicle steering follows the direction of the chosen Dhab and writes standard local `VehicleSeat.ThrottleFloat` / `SteerFloat` values while occupied; it slows/coasts approaching the stopping radius and stops throttle on a detected obstacle. Holding WASD/arrow keys pauses automated driving when the manual-movement guard is ON. Seat change, death, target loss, toggling hunting OFF and script cleanup release the controls. There is no guaranteed vehicle pathfinding, automatic road routing or custom chassis support. `VehicleSeat` is documented to forward inputs only to compatible motor joints; custom vehicles may have to be integrated with their own *documented* control system. No game-specific remotes, item collection or simulated server damage.

If your car uses a generic `Seat` rather than `VehicleSeat`, or is not under `PlayersCars`, the status reports why vehicle hunting is unavailable. This has been statically inspected on GitHub but has **not been tested inside your actual car/Xeno client**.


## Eight upgrades + keyboard-driven car fix (October 26, 2026)

**Car fix: this game's vehicle is driven with W/A/S/D, not necessarily VehicleSeat floats.** VehicleHuntController now defaults to **Keyboard W/A/S/D** rather than directly writing VehicleSeat input. It only controls the local player's occupied Seat or VehicleSeat under Workspace.PlayersCars. VehicleKeyInput tries executor keypress/keyrelease using Windows virtual-key codes W=0x57, A=0x41, S=0x53 and D=0x44. It falls back to protected VirtualInputManager SendKeyEvent when exposed; neither API is guaranteed available in every Xeno version. If unsupported, Diagnostics reports the input error; it NEVER claims successful movement. You can choose the old Seat control mode from Auto Hunt's Car input button if your chassis responds to VehicleSeat floats.

**8 upgrades**
1. Advanced car autopilot: keyboard steering, speed limiting, multi-ray obstacle detection, short reverse recovery and automatic key release. Direct world-coordinate steering is not a fully fledged road planner; not all chassis work.
2. Intelligent target scoring: Auto Hunt's Target priority now offers Smart, combining true replicated Length, Scale and distance with tunable weights on the Advanced page. Existing Closest/Longest/Largest remain.
3. Multi-Dhab route planner: optional checkbox builds a short greedy nearest-neighbor path through up to 12 candidates. Keeps a route across target selection; does not teleport or guarantee that every point has safe road access.
4. Predictive aim: optional camera lead based on Dhab primary-part AssemblyLinearVelocity, clamp of maximum velocity and adjustable AimLeadSeconds (0 to 0.6). Only targets live Dhab; actual projectile travel time is unknown.
5. Catch/inventory observer: read-only inspection of Workspace.DhabCatches objects that explicitly claim ownership by LocalPlayer.UserId, and player inventory capacity fields if replicated. Shows owned catch objects observed, not guaranteed server-confirmed catches. Unknown capacity is displayed as unknown rather than invented.
6. Blacklist zones: Advanced tab can mark player's current position as a temporary avoid region, with adjustable radius and Clear blocked zones. Up to 20 session-only zones; not persisted and not an exact polygon route solver.
7. Performance mode: reduces monster rescan interval, caps overlay render to 15 FPS and lowers radar/hunter update frequency. FPS/ping shown in the existing header; Roblox UI runtime compatibility still needs testing.
8. Emergency stop and diagnostics: press **F8** or click Emergency stop to immediately disable Hunt/Aim/Shoot and release injected W/A/S/D keys. Diagnostics tab shows current mode, car state, keyboard API, input errors, Auto Shoot status and planner summary.

The Advanced and Diagnostics tabs are available in the scrollable sidebar. Features are optional, with Auto Hunt OFF by default and saved settings still opt-in. No network-ownership manipulation, game-specific remotes, server damage spoofing, teleporting or forced interaction was introduced.

**IMPORTANT:** GitHub/static verification cannot establish whether your Xeno version actually exposes keypress/keyrelease/VirtualInputManager or whether the custom chassis receives injected input. Enter the car, enable Auto Hunt, open Diagnostics and check Key API / Key error. Press F8 immediately if the car behaves unexpectedly.


## Vehicle Auto Hunt: sustained W and 120 km/h cruise (2026-10-26)

The original Xeno car controller could tap W briefly then stop because **keyboard mode reset VehicleSeat.ThrottleFloat to zero every frame**, capped speed at only 32 studs/second, sometimes treated driveable slopes or the hunted Dhab as obstacles, and had a short stale-input timeout. These issues have been addressed in `src/VehicleHuntController.lua`:

- **Keyboard W/A/S/D (default)** now holds W continuously while accelerating, without forcing `VehicleSeat.ThrottleFloat = 0` during the drive. A and D remain held through turns as needed. Separate `VehicleSeat` mode is still selectable.
- **Vehicle speed target: 120 km/h** by default, adjustable between 30–180 km/h from the Auto Hunt tab. At Roblox's nominal scale (1 stud = 0.28 m), 120 km/h is approximately 119 studs/sec. The speed regulator reads the occupied seat assembly's velocity and uses an 11 km/h hysteresis gap to avoid rapid W tap/release at the target. A game's custom speedometer may use a different conversion, and the controller cannot make a physically limited car reach a higher speed.
- **Brake for obstacles** is ON by default and can be turned off separately to diagnose unexpected brakes. The upgraded three-ray check ignores the hunted model, non-collidable objects, and upward-facing traversable ground. It still releases acceleration for genuinely blocking obstacles.
- **Coast when nearing a Dhab**, taking actual current speed and stopping radius into account. Even at the 120 km/h target, Auto Hunt intentionally releases W when sufficiently close to a Dhab. This is not a continuous full-speed crash-into-target mode.
- A **2-second drive intent timeout** tolerates short update stalls while still releasing input on disable, F8 emergency stop, seat exit, stale target, or script cleanup. The original user-configured separate hunter and shooting restrictions remain unchanged.
- Older saved `HuntCarMaxSpeed` values are not loaded into the new `HuntCarTargetKmh` preference, to avoid restoring the previous too-low speed cap. The car target speed defaults to 120 km/h until the user explicitly saves a new km/h value.

**To test:** Sit in your own driver seat → Auto Hunt → `Car input: Keyboard W/A/S/D` → `Vehicle speed target: 120 km/h` → enable Auto Hunt. Diagnostics / hunt status indicates `W held`, actual calculated km/h, obstruction, near-target coasting, or missing keyboard API. F8 is the emergency stop. Live Roblox/Xeno driving and the game's speedometer calibration remain **unverified**.


## Diagnosing "W held | 0/120 km/h" (Screenshot, October 26, 2026)

The real game HUD showed **0 km/h** while IVORY displayed **Keyboard | 0/120 km/h | W held** with a live Dhab 944 studs away. This means selection and keypress dispatch were active, but the vehicle did not actually accelerate. The game HUD also showed an **N** near **4H**, which may mean the transmission is in **Neutral**; this is only a visual clue, not a verified replicated gear value.

Vehicle Auto Hunt now measures actual car motion rather than equating successful `keypress()` with successful driving:
- After 2 seconds at zero speed with W requested, it probes a W key-up/key-down event every ~0.45 seconds in case the executor's initial keypress event was transient.
- After 5 seconds without movement it **tries the alternate VirtualInputManager input backend once**, only if available.
- After 9 seconds without movement it **releases all simulated keys** and displays `No drive response (0 km/h); check gear N / Drive` rather than endlessly pressing W, reversing blindly or skipping Dhab.
- Unstick reversing is disabled until actual vehicle movement has previously been observed.
- The Diagnostics page now scrolls and displays measured speed, any replicated gear hint, W requested state, whether Roblox UserInputService sees W, number of W re-press probes, backend fallback attempt and no-response flag.
- To test: manually select a forward gear (if the HUD's N means Neutral), verify that **pressing physical W** accelerates your own car, then click **Diagnostics → Retry car input after shifting into Drive**. The script never guesses a shift key or changes the game's transmission itself.
- F8 still releases all simulated W/A/S/D inputs immediately.

If a physical W press works but input probing still reports no vehicle motion, the custom chassis may ignore Xeno's injected input completely. In that case, further implementation would require **verified** details of the car's local control scripts or the game's documented control APIs; the client cannot assume arbitrary remote endpoints or claim success. No live driving test was possible from GitHub alone.


## Ten hunting usability upgrades (October 27, 2026)

This feature branch includes all ten additional user-requested options, with explicit limitations for game-specific car controls:

1. **Vehicle Control Learner** in **Vehicle Lab**: observe the player's own *manual* W/A/S/D driving for eight seconds and record input and actual velocity. It never sends keys in observation mode; it only inspects the currently occupied driver Seat/VehicleSeat within Workspace.PlayersCars.
2. **Smart Cruise Control**: the 120 km/h car speed target now tapers toward a smaller speed as distance to the Dhab falls (with a simple conservative braking-distance model) and slows through large steering angles. Disabled by toggling **Approach-speed cruise control** in Vehicle Lab. This does not guarantee the custom game speedometer's units, braking distance, or ability to reach 120 km/h.
3. **Vehicle Input Calibration**: explicitly press **Calibrate car input (slow test)** while stationary in a forward gear with Auto Hunt OFF. It applies low-speed forward input to Keyboard, then VehicleSeat when available, measures real vehicle displacement/speed change, releases commands, and records a confirmed responsive input *method* per vehicle type attribute (CarType/VehicleType/ModelName) or per car model name. When car input is set to Auto, a calibrated method wins; without calibration it falls back to Keyboard. Profiles are stored across sessions only if opt-in **Save preferences locally** is enabled. F8 cancels any trial. Do not calibrate near people, drops, walls or traffic.
4. **Off-road Navigation Assist**: optional client-side terrain and collision raycasts that look for short lateral, passable approaches when the direct line is obstructed. Stops throttle when no safe approach is sampled; does not drive through obstacles or imply a fully modeled road network.
5. **Target Lock and Previous/Next** under **Hunt Tools**: lock current target, cycle among living and eligible Dhab, and unlock; retain current target until invalid or unreachable. Never includes HandCatch, cars, players or vendors.
6. **Enhanced Dhab ESP** under Hunt Tools: optional real Tier-specific colors, gold outline/label for the Dhab with the longest *replicated* Length, and a small off-screen target direction arrow. Actual Tier is not assumed to equal rarities.
7. **One-click hunt presets** under Hunt Tools: Closest, Biggest (replicated Scale), Longest (replicated Length), and T3+ (only known Tier T3-T6). Presets reset incompatible tier filters and retarget; enabled hunt remains user controlled.
8. **Dhab observation heatmap** under Radar: an eight-by-eight local grid around the player displays places where unique live Dhab models have been *observed* this session, not verified server spawn events. Clear observations from Radar. Entirely session-only and OFF by default.
9. **Compact hunting HUD** under Hunt Tools: shows current target, actual Tier/Length/Scale, distance, measured car speed and hunt status. Optional arrow displays when selected Dhab is off-screen. HUD is OFF by default; independent of the dashboard menu.
10. **Safety focus and emergency controls**: press F8 to cancel hunting, shooting, car input, and an active calibration test. WindowFocusReleased (when Roblox exposes it) likewise invokes the emergency stop rather than leaving simulated W held after alt-tabbing; focus return requires manually enabling hunting again. Driver seat/occupant checks, dead character detection and no-response aborts stay active.

**Important car limitation:** The user's actual game has reported "W held" and zero real movement; the screenshot also showed an "N" that might indicate Neutral. Calibration can prove which input backend produces movement but cannot force a custom chassis to accept executor-generated keystrokes, automatically shift an unknown gearbox, or guarantee 120 km/h. Before testing, physically drive manually in a forward gear and use Vehicle Lab. If neither backend moves the car, no autonomous vehicle motion is claimed.

**Load:** keep using the existing feature-branch raw main.lua URL. The main branch remains unchanged. GitHub static validation is not equivalent to a live Roblox/Xeno integration test.


## Ten more improvements: Car Inspector, Explorer, alerts and GUI V2 (October 27, 2026)

1. **Custom car controller adapter** in src/VehicleAdapter.lua identifies replicated/local car controls without injecting undocumented remotes or claiming universal chassis support. Supports normal Keyboard, VehicleSeat, plus explicit opt-in **typed NumberValue Throttle and Steer** under a car's Controls/Input folder. The latter must be enabled in Car Inspector, selected from Auto Hunt's Car input cycle, and confirmed by actual vehicle motion. It is not guaranteed to work with an unknown chassis. If not found, Car Inspector reports unsupported.
2. **Gear & Transmission Inspector** in src/GearInspector.lua checks available seat/car gear attributes and ValueBase entries read-only, plus VehicleSeat steering/throttle. Does not guess shift keys or change transmission. If N appears on the HUD, verify manually.
3. **Vehicle Test Bench**: Vehicle Lab → Manual test bench (10s), collects real peak speed, acceleration, braking, steering rotation and W/S/A/D observations while user physically drives. No keys injected by this measurement; the preexisting explicit Calibrate test remains available separately. Cancel with F8.
4. **Live Dhab Explorer**: new sortable Dhab Explorer page for actual Tier, Length, Scale (shown as Size), distance; name search, tier selector, tap an entry to lock that exact still-valid live Dhab. Never includes cars/HandCatch/players.
5. **High-tier/long Dhab alerts**: opt-in Radar tab toggle with adjustable Tier and Length thresholds, max 3 notifications per scan and bounded recent list. Uses actual Tier/Length, not guessed rarity.
6. **Dhab skips and cooldowns**: manually exclude current Dhab for an adjustable 15-600 seconds; clear skips, temporary unreachable cooldown and live-target-only selection retained.
7. **Custom hotkeys**: Profiles page cycles Hunt, Next Target and Radar keys from a restricted key list, avoids F8 emergency key, menu and ESP toggle keys and duplicate bindings. Persists when Save preferences is explicitly enabled.
8. **Config profiles**: Profiles page offers Car Hunting, On Foot, High Tier and Low FPS safe presets; Custom A/B slots can store allowed setting values. Loading a profile always disables Auto Hunt and Auto Shoot until the user turns them on explicitly. Custom slots are sanitized and saved locally only if storage opt-in is ON.
9. **Debug log export**: Diagnostics → Copy/export debug log copies a bounded event history and current diagnostics; if clipboard API is missing, a string is placed in getgenv().IvoryDebugReport and printed. No tokens, passwords or player IDs deliberately collected.
10. **7jl GUI V2**: sidebar page search, collapsed/expanded Core/Hunting/Tracking/Tools categories, scaled +/- dashboard size, compact preference, a separate floating 7jl reopen control on hide, scrollable long pages for Car Inspector, Dhab Explorer, Profiles, Radar and Diagnostics. The prior Frame.ScrollBarThickness error guard remains.

All settings default to non-invasive behavior; Auto Hunt, Auto Shoot, alerts, and typed custom car adapter do NOT automatically enable. Work is on feature/modular-ivory-esp PR #1, not main.

**Important**: These are implementation and static GitHub checks only. The game's custom car controls, Xeno keyboard input and 120 km/h car behavior still require real session tests. The optional typed Controls adapter is *not* server-authoritative: writing a local NumberValue without seeing movement is insufficient evidence it operates the vehicle. Press F8 to release injected input.
