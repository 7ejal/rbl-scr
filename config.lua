-- IVORY ESP configuration. Monster-only view is the default.
return {
    Enabled = true,
    ToggleKey = Enum.KeyCode.I,
    MenuKey = Enum.KeyCode.RightControl,
    InspectorKey = Enum.KeyCode.P,
    InspectorScanKey = Enum.KeyCode.O,
    MarkMonsterKey = Enum.KeyCode.M,
    RenderFPS = 30,
    MaxDistance = 1200,

    PlayersEnabled = false,
    ShowBoxes = true,
    ShowNames = true,
    ShowDistance = true,
    ShowHealth = true,
    ShowHighlights = true,
    TeamColors = true,

    -- All friendly/unknown NPC overlays are hidden by default.
    OtherNPCEnabled = false,
    MonsterEnabled = true,
    MonsterBoxes = true,
    MonsterNames = true,
    MonsterDistance = true,
    MonsterHealth = true,
    MonsterHighlights = true,

    -- Add your exact model names here or mark them through the Targets tab / M.
    MonsterModelNames = {},
    -- Real game scan: Workspace.DhabWild.Dhab_fa1f92
    WildlifeFolderName = "DhabWild",
    HandCatchFolderName = "DhabHandCatches",
    DhabQualityEnabled = true,

    HandCatchEnabled = true,
    HandCatchBoxes = true,
    HandCatchNames = true,
    HandCatchDistance = true,
    HandCatchHighlights = true,
    HandCatchQuality = true,

    -- Camera-only monster aim. Never automatically fires a weapon.
    AimEnabled = false,
    AimHoldRightMouse = false,
    AimShowCircle = true,
    AimRadius = 120,
    AimDistance = 350,
    AimSmoothness = 0.18,

    -- Uses an equipped Tool:Activate; no weapon remotes or damage hacks.
    AutoShootEnabled = false,
    AutoShootLineOfSight = true,
    AutoShootRate = 3, -- activation attempts per second (1-8)

    MinFOV = 40,
    MaxFOV = 120,
}