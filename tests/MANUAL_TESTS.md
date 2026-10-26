# Manual validation (not yet run in Roblox/Xeno)

- [ ] Load the PR branch. A standalone "IVORY ESP - Loading" notification appears, followed by "IVORY ESP - Loaded" only once the dashboard starts.
- [ ] Simulate an invalid module branch; a standalone in-game "Load failed" notice and F9 error should identify the missing module.
- [ ] With a large Workspace, module startup completes before the incremental monster scan finishes (avoid long client freezes).
- [ ] Load the PR branch. A 680 x 500 rounded dark dashboard appears, with English text only and no emoji icons.
- [ ] Verify Home, ESP, Monsters, Settings sidebar navigation works.
- [ ] Header FPS and ping labels update after a second.
- [ ] Player ESP and other-Nonmonster NPC ESP default OFF. Turn either ON and verify independently controlled overlays.
- [ ] Toggle individual player boxes, names, health, and wall highlights; verify behavior.
- [ ] With Workspace.DhabWild.Dhab_fa1f92 replicated, Monster ESP recognizes it; display count increases above zero.
- [ ] With Workspace.DhabHandCatches.HandCatch_6d67eea5cb324ca780fff2c0e7e6ec5d replicated, HandCatch tab shows an independent blue ESP and count.
- [ ] Throw a HandCatch onto terrain; it remains labeled and highlighted while replicated, without creating player/plot ESP.
- [ ] Turn off HandCatch ESP while Monster ESP remains on, and vice versa.
- [ ] HandCatch category shows separately under the O-key inspector report.
- [ ] Dhab quality label shows the actual per-instance Quality value where replicated; missing data shows Quality: Unknown (never fabricated).
- [ ] Test quality present as an attribute, as a nested StringValue/NumberValue, and as a clearly labeled TextLabel; verify value updates within one second.
- [ ] If quality source is Rarity or Grade, label its actual type, not an assumed percentage.
- [ ] Enable Auto Aim while both a live Dhab and thrown HandCatch are visible. The camera locks only to the live Dhab, never the thrown HandCatch.
- [ ] Auto Shoot defaults OFF, with Auto Aim either ON/OFF independently.
- [ ] Turning Auto Shoot ON also enables Auto Aim, and status reports when no Tool is equipped.
- [ ] Equip a Roblox Tool with an Activated handler. When a live Dhab is centered within 16 pixels, verify bounded Tool activation at the selected 1–8 shots/second rate.
- [ ] With HandCatch only, Auto Shoot never activates a weapon.
- [ ] Check no shots when a Dhab is blocked by Terrain or a part and line-of-sight is ON.
- [ ] Check pressing right mouse is required when the right-mouse setting is ON.
- [ ] Disable Auto Shoot or Auto Aim while targeting: tool activations immediately stop.
- [ ] Unequip the Tool: firing stops, status says Equip a Roblox Tool. Verify no accidental tools are equipped.
- [ ] Custom weapons without Tool.Activated handlers may not fire and require game-specific integration; don't claim otherwise.
- [ ] Reload script repeatedly and confirm only one AutoShootController / render loop is active.
- [ ] If there are only HandCatch objects but no live Dhab, auto aim does not move the camera.
- [ ] Verify right mouse requirement, aim radius and distance settings still work.
- [ ] Do not create ESP duplicates for child rig models/parts, or for DhabWild container itself.
- [ ] Cars in Workspace.PlayersCars, plots and vendors remain excluded from Monster ESP.
- [ ] Press O and check the DhabWild creature now appears in RECOGNIZED MONSTERS, not buried in scenery.
- [ ] Move to Monsters. Hostile-marked/name-matched models and DhabWild creatures are recognized; shopkeepers and plots do not show monster outlines.
- [ ] Targets > Show scenery lists nearby models. TRACK an unrecognized monster by exact name; verify monster ESP appears. UNTRACK removes its forced classification.
- [ ] Point at a real NPC or creature and press M. It should register that model name and print a report; it must never register Terrain.
- [ ] Auto Aim tab: enable camera aim; with a registered monster inside the FOV circle, camera gradually turns toward it (without firing). Check right-mouse-only mode, circle toggle, distance and smoothing controls.
- [ ] With zero recognized monsters, auto aim should leave the camera unchanged.
- [ ] Toggle Monster ESP and each monster subfeature independently.
- [ ] Press I to hide both player and monster overlays; press I again to restore.
- [ ] Press P while aiming at a monster (with F9 closed); it prints model path, tags and attributes. Clipboard receives the report where supported.
- [ ] Press P while aiming at Terrain; it does NOT label Terrain as a monster, and attempts NPC detection near cursor or explains how to scan.
- [ ] Press O or click Find models and open F9; it lists up to 25 recognized NPC candidates and up to 25 other nearby models, including names and full paths.
- [ ] Run the old standalone inspector and then the modular loader; verify duplicate P handlers from the old script are disconnected.
- [ ] Confirm no player character is wrongly included as a monster after join/respawn.
- [ ] Confirm models without Humanoids but tagged/named as a monster can be highlighted and have names.
- [ ] Detection distance +/- buttons change effective range by 100 studs, clamped 100–5000.
- [ ] Settings FOV slider changes camera FOV between 40 and 120 and works when overlays are off.
- [ ] Try with low-resolution window; UI fits screen.
- [ ] Drag the dashboard header; it moves.
- [ ] Re-execute the loader; old GUI/events/highlights are removed, and only one dashboard remains.
- [ ] Call getgenv().IvoryESP_Stop() and verify full cleanup/FOV restoration.
- [ ] Test in games where monsters are streamed in and out.
- [ ] Measure FPS on servers with 20+ players and many NPCs.


## Cars + quality test cases

- [ ] \`Workspace.PlayersCars.DH_8638378195_SHAS_2025__2\` appears as one purple car ESP with no duplicate wheel/tire highlights.
- [ ] Cars tab toggles independent from monster, player and HandCatch ESP, with an accurate whole-car count.
- [ ] Cars cannot be targeted by Auto Aim or Auto Shoot.
- [ ] The Quality tab's **Inspect nearest Dhab quality** works without F9, displays actual source and copies/exports a report.
- [ ] Dhab quality is read from matching local attributes, nested ValueObjects or displayed labels when present.
- [ ] Exact-ID matching of ReplicatedStorage/PlayerGui data is used only when linked to the same Dhab; no quality leaks between 24 Dhab.
- [ ] The \`O\` scan shows Dhab quality and a separate whole-car section.
- [ ] If no quality is client-replicated, **Quality: Unknown** appears (no fabricated percentage).

## Anti Fog manual checks

- [ ] Anti Fog toggle appears in English under Settings and starts OFF.
- [ ] With Lighting fog active, enabling Anti Fog increases fog distances to 1,000,000 / 10,000,000 studs.
- [ ] With a Lighting.Atmosphere object, enabling Anti Fog sets Density, Haze and Glare to 0 without removing Atmosphere.
- [ ] Changing the game's fog while enabled is corrected within approximately 0.75 seconds.
- [ ] Newly added Atmosphere instances are cleared and their original values remembered.
- [ ] Turning the feature OFF restores the values captured when enabled and disconnects listeners.
- [ ] Re-executing loader and stopping IVORY restores local Lighting defaults and creates no duplicate fog loops.
- [ ] The main ESP, camera FOV, Cars, Dhab, HandCatch, quality inspector and auto-aim toggles still operate independently.

## Mouse-left-click Auto Shoot validation

- [ ] Auto Shoot defaults OFF and its input mode defaults to **Left Click**.
- [ ] Input button swaps **Left Click** / **Tool**, updating label immediately without multiple extra GUI instances.
- [ ] With a live Dhab centered, Left Click mode invokes `mouse1click()` (if available) at the bounded firing rate.
- [ ] If `mouse1click` is missing but `mouse1press` and `mouse1release` are available, press/release are balanced and released within ~0.06s.
- [ ] With no executor input APIs, status says mouse1click isn't exposed and never silently claims firing.
- [ ] Tool mode continues to use a correctly equipped `Tool:Activate()` and release.
- [ ] Left Click mode works even if custom weapon isn't an Instance Tool (as long as game listens to mouse clicks).
- [ ] Auto Shoot does nothing if no live Dhab, line of sight is blocked, auto aim disabled, or typing into text input.
- [ ] Clicking on the ESP GUI itself isn't automated: with mouse pointer inside the visible dashboard, Auto Shoot pauses.
- [ ] HandCatch, cars and players cannot become Auto Shoot targets; 1–8 shots/sec cap still respected.
- [ ] Disabling/reloading script releases any held mouse input, preventing stuck mouse-button states.
- [ ] Anti Fog, Cars, Quality and other features retain their existing settings.

## Verified Tier / Length / State

- [ ] Model attributes `Tier`, `Length`, and `State` appear verbatim over recognized live Dhab, updating when the model changes.
- [ ] `DhabStatsEnabled` Quality-tab toggle hides/shows those stats independently of `DhabQualityEnabled`.
- [ ] `O` scan lists the actual Tier and State per live Dhab without claiming they are its numerical Quality or Rare/Common rarity.
- [ ] Tier values T1, T2, T3 are displayed accurately; other tiers are not assumed or filtered out.
- [ ] Missing Tier/State values don't create fake values; real Quality still reads `Quality: Unknown` until a verified source exists.
