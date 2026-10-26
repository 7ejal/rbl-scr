# Manual test checklist

This project requires a live Roblox client/executor. These are scenarios for testing, not claims that they have already passed.

- [ ] Execute branch loader; ESP button and FOV slider appear once.
- [ ] Join with two or more players; remote players have projected outline, display name, distance, and health bar.
- [ ] Highlight remains visible through a wall; boxes disappear when a target leaves the screen.
- [ ] Press I when not typing; ESP switches off immediately. Press I again; it switches back on.
- [ ] Click the ESP button to toggle independently of the keybind.
- [ ] Drag FOV slider by mouse from 40 to 120 and observe camera changes, including while ESP is off.
- [ ] Respawn a remote player and local player; ESP keeps working.
- [ ] Join and leave players; there are no stale boxes or highlights.
- [ ] Re-execute loader multiple times; only one GUI and one render connection should remain.
- [ ] Call getgenv().IvoryESP_Stop() to clean up and restore original FOV.
- [ ] Switch teams; allied players are green, enemies red.
- [ ] Verify acceptable performance with 20+ players. Rendering is capped at 30 updates/second.
- [ ] Check executor compatibility; no Drawing library or external dependencies are required.

## Caveats

Roblox's Highlight rendering has a finite capacity, so large servers can exceed its limit. Projected boxes are hidden when a bounding-box corner passes behind the camera. Standard client replication rules apply: the script cannot visualize characters the client does not have.