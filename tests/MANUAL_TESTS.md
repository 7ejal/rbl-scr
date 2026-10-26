# Manual validation (not yet run in Roblox/Xeno)

- [ ] Load the PR branch. A 680 x 500 rounded dark dashboard appears, with English text only and no emoji icons.
- [ ] Verify Home, ESP, Monsters, Settings sidebar navigation works.
- [ ] Header FPS and ping labels update after a second.
- [ ] Toggle individual player boxes, names, health, and wall highlights; verify behavior.
- [ ] Move to Monsters. NPCs with Humanoids are detected; check names, boxes, health, distance and highlights.
- [ ] Toggle Monster ESP and each monster subfeature independently.
- [ ] Press I to hide both player and monster overlays; press I again to restore.
- [ ] Press P while hovering a monster's body part; F9 console prints full model hierarchy, tags and attributes. Where available, clipboard contains report.
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
