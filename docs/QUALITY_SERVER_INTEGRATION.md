# Getting the exact quality of every Dhab (server-side setup)

This is the most reliable method when you own the Roblox experience.

The client script can display only values Roblox replicates to the local player. A value in server-only memory, ServerStorage, or ServerScriptService cannot be recovered by the ESP. The fact that a model is named Dhab_21addd does not reveal its actual quality.

## In Roblox Studio

Find the **server-side function that creates each live Dhab** (the function that parents a Dhab Model under workspace.DhabWild). It likely already has an actual per-creature quality field in the spawn data. **Use that real field**, without generating a new random number.

When you have both the spawned model and the authoritative quality, add:

\`\`\`lua
-- Example inside YOUR existing server-side spawn code.
-- generatedData.quality is only an example field name:
-- replace it with the actual quality value from your game.
local actualQuality = generatedData.quality
assert(type(actualQuality) == "number" or type(actualQuality) == "string")

dhabModel:SetAttribute("Quality", actualQuality)
dhabModel.Parent = workspace:WaitForChild("DhabWild")
\`\`\`

If your game's actual field represents a percentage, use an explicit name:

\`\`\`lua
dhabModel:SetAttribute("QualityPercent", actualQualityPercent)
\`\`\`

If quality is stored as an enum/grade, use the original label/value instead of pretending it is a percentage.

Likewise, when the server creates a thrown HandCatch object from an existing Dhab, preserve the original value:

\`\`\`lua
-- Example inside YOUR existing HandCatch creation code:
local existingQuality = dhabModel:GetAttribute("Quality")
if existingQuality ~= nil then
    handCatchModel:SetAttribute("Quality", existingQuality)
end
-- The HandCatch model is already parented by your actual game code.
\`\`\`

Don't copy these example variable names literally unless they exist in your game. Place the calls where the original server actually knows the quality.

## Verify in game

Run the modular ESP branch. Under the Quality tab press **Inspect nearest Dhab quality**. It displays the actual field and path, and copies a diagnostic report when clipboard access is available.

With these server attributes:
- Each live Dhab reads its own exact Quality or QualityPercent.
- Each thrown HandCatch can show its original quality separately.
- Vehicles, other creatures, NPCs and other players cannot supply a Dhab's quality by accident.
- No client script has to guess from IDs or invoke game-specific remotes.

## If you cannot change the game server

The updated client resolver attempts a bounded exact-ID lookup within replicated model data and UI. When it still says **Quality: Unknown**, the correct conclusion is that the actual value **was not found in inspected client-replicated data**. It is not evidence that the animal has zero quality.
