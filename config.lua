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
    CarsFolderName = "PlayersCars",
    CarsEnabled = true,
    CarBoxes = true,
    CarNames = true,
    CarDistance = true,
    CarHighlights = true,
    DhabQualityEnabled = false, -- unknown quality hidden by default
    DhabStatsEnabled = true, -- Tier, Length, Size

    HandCatchEnabled = true,
    HandCatchBoxes = true,
    HandCatchNames = true,
    HandCatchDistance = true,
    HandCatchHighlights = true,
    HandCatchQuality = false, -- hide unknown quality by default

    -- Camera-only monster aim. Never automatically fires a weapon.
    AimEnabled = false,
    AimHoldRightMouse = false,
    AimShowCircle = true,
    AimRadius = 120,
    AimDistance = 350,
    AimSmoothness = 0.18,

    -- Mouse mode simulates left click when the executor exposes mouse1click.
    -- Tool mode uses an equipped Tool:Activate. Neither modifies game remotes.
    AutoShootEnabled = false,
    AutoShootInputMode = "Mouse", -- "Mouse" left click, or "Tool"
    AutoShootLineOfSight = true,
    AutoShootRate = 3, -- activation attempts per second (1-8)
    AutoShootMaxDistance = 160, -- studs; live-Dhab gate

    -- On-foot Auto Hunt. Independent from the manual Aim/Shoot switches.
    -- Auto Hunt movement requires a living, unseated Humanoid character.
    AutoHuntEnabled = false,
    HuntAutoShoot = true,
    HuntPauseOnManualMove = true,
    HuntStopDistance = 28, -- studs (10-100)
    HuntSearchDistance = 700, -- studs (100-2000)
    HuntPriority = "Closest", -- Closest, Longest, Largest
    HuntMinLength = 0, -- studs
    HuntTierT1 = true,
    HuntTierT2 = true,
    HuntTierT3 = true,
    HuntTierT4 = true,
    HuntTierT5 = true,
    HuntTierT6 = true,
    HuntTierUnknown = false,
    HuntShootDistance = 85, -- studs; also subject to AutoShootMaxDistance

    -- Radar and session stats.
    RadarEnabled = false,
    RadarRange = 400, -- studs
    StatsEnabled = true,
    SaveSettingsEnabled = false, -- explicit opt-in, local file API required

    -- Local-only atmospheric visibility. OFF by default.
    AntiFogEnabled = false,

    CameraFOV = 0, -- 0 uses Roblox's initial camera FOV
    MinFOV = 40,
    MaxFOV = 120,
}