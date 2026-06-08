--[[
    ari_garage — Config
    Version: 1.15.4-ari
    ─────────────────────────────────────────────────────────────
    All settings are documented inline.
    Do NOT edit anything outside of this file for base behaviour.
--]]

Config = {}

-- ─── LOCALE ────────────────────────────────────────────────────────────────────
Config.Locale = GetConvar('esx:locale', 'es')

-- ─── GENERAL ───────────────────────────────────────────────────────────────────

-- Distance (metres) at which garage markers become visible and blips become active
Config.DrawDistance = 12.0

-- Distance (metres) at which the player must be to interact with a marker
Config.InteractDistance = 1.5

-- Show floating 3D text above markers when player is within DrawDistance
Config.Show3DText = true

-- Use target system instead of markers? (reserved for custom integrations)
-- This version keeps the marker flow as the supported path.
Config.UseTarget = false

-- ─── IMPOUND ───────────────────────────────────────────────────────────────────

-- When a player parks a vehicle that is out-of-fuel, automatically impound it?
Config.ImpoundOnEmpty = true

-- Send a notification to the vehicle owner when their car is impounded by police?
Config.NotifyOnImpound = true

-- Fine multiplier based on vehicle condition (1.0 = no change, 1.5 = 50% extra if damaged)
Config.ImpoundDamageMult = 1.0

-- Depósito solo por menú del garaje (sin blips / sin punto [E] en el mundo)
Config.ImpoundMenuOnly = {
    ShowMapBlips = false,
    ShowWorldMarkers = false,
    --- Precio fijo al sacar embargado (stored = 2) desde el menú. nil = usar Cost del depósito del vehículo.
    ReleaseFeeOverride = nil,
    --- Si no hay override: Cost × este multiplicador (luego aplica ImpoundDamageMult).
    ReleaseFeeMultiplier = 1.0,
}

-- ─── BILLING ───────────────────────────────────────────────────────────────────

-- Payment method for impound fees: 'cash' | 'bank' | 'any'
Config.PaymentMethod = 'any'

-- ─── MARKERS ───────────────────────────────────────────────────────────────────
-- Type reference: https://docs.fivem.net/docs/game-references/markers/

Config.Markers = {
    EntryPoint = {
        Type    = 21,
        Size    = { x = 1.2, y = 1.2, z = 0.5 },
        Color   = { r = 80,  g = 220, b = 100 },
        Alpha   = 180,
        Bob     = true,    -- Animates marker bobbing up/down (client CPU cost: negligible)
        Rotate  = false,
    },
    GetOutPoint = {
        Type    = 21,
        Size    = { x = 1.2, y = 1.2, z = 0.5 },
        Color   = { r = 220, g = 60,  b = 60  },
        Alpha   = 180,
        Bob     = true,
        Rotate  = false,
    },
}

-- ─── BLIPS ─────────────────────────────────────────────────────────────────────
-- Sprite/colour reference: https://docs.fivem.net/docs/game-references/blips/

Config.GarageBlip = {
    Sprite  = 357,
    Scale   = 0.82,
    Colour  = 3,
    Display = 4,
    ShortRange = true,
}

Config.ImpoundBlip = {
    Sprite  = 524,
    Scale   = 0.82,
    Colour  = 1,
    Display = 4,
    ShortRange = true,
}

-- ─── NUI / UI ──────────────────────────────────────────────────────────────────

Config.UI = {
    -- Theme accent colour (hex) — used by the NUI
    AccentColor = '#A855F7',

    -- Show vehicle thumbnail images in the UI (requires model-named .webp in nui/img/vehicles/)
    ShowVehicleImages = false,

    -- Animate cards on open (staggered slide-in)
    AnimateCards = true,

    -- Show a fuel gauge in each vehicle card (requires ESX fuel resource exporting GetFuel)
    ShowFuelGauge = true,

    -- Sound when opening the garage menu (FiveM default audio)
    Sound = {
        Enabled   = true,
        Name      = 'CONFIRM_BEEP',
        Set       = 'HUD_MINI_GAME_SOUNDSET',
    },
}

-- ─── GARAGES ───────────────────────────────────────────────────────────────────
--[[
    Each garage entry supports:
        EntryPoint   — {x, y, z}   where the marker/interaction zone spawns
        SpawnPoint   — {x, y, z, heading} where the vehicle appears
        Label        — display name shown in the UI header
        ImpoundedName — key inside Config.Impounds to associate with
        AllowedJobs  — table of job names allowed; nil = everyone
        AllowedGrades — table of minimum grade per job, e.g. {mechanic=2}
        VehicleFilter — 'all' | 'car' | 'boat' | 'air' | 'bike'
        Sprite / Scale / Colour — blip overrides (optional, falls back to Config.GarageBlip)
--]]

Config.Garages = {
    VespucciBoulevard = {
        Label       = 'Vespucci Boulevard',
        EntryPoint  = { x = -285.2,   y = -886.5,  z = 31.0 },
        SpawnPoint  = { x = -309.3,   y = -897.0,  z = 31.0, heading = 351.8 },
        ImpoundedName = 'LosSantos',
        AllowedJobs   = nil,
        VehicleFilter = 'all',
        Sprite  = 357,
        Scale   = 0.8,
        Colour  = 3,
    },
    SanAndreasAvenue = {
        Label       = 'San Andreas Avenue',
        EntryPoint  = { x = 216.4,    y = -786.6,  z = 30.8 },
        SpawnPoint  = { x = 218.9,    y = -779.7,  z = 30.8, heading = 338.8 },
        ImpoundedName = 'LosSantos',
        AllowedJobs   = nil,
        VehicleFilter = 'all',
        Sprite  = 357,
        Scale   = 0.8,
        Colour  = 3,
    },
    AriMansion = {
        Label       = 'Ari Mansion',
        EntryPoint  = { x = -3209.09, y = 823.38,  z = 8.93 },
        SpawnPoint  = { x = -3203.22, y = 815.08,  z = 8.93, heading = 0.0 },
        ImpoundedName = 'LosSantos',
        AllowedJobs   = nil,
        VehicleFilter = 'all',
        Sprite  = 357,
        Scale   = 0.8,
        Colour  = 3,
    },
    PrisionDelNorte = {
    Label       = 'prision del norte',
    EntryPoint  = { x = 1870.45, y = 2588.65, z = 45.67 },
    SpawnPoint  = { x = 1876.28, y = 2588.37, z = 45.67, heading = 269.14 },
    ImpoundedName = 'LosSantos',
    AllowedJobs   = nil,
    VehicleFilter = 'all',
    Sprite  = 357,
    Scale   = 0.8,
    Colour  = 3,
},
    -- Example: mechanic-only garage
    --[[
    MechanicShop = {
        Label       = 'Mechanic Shop',
        EntryPoint  = { x = 0.0, y = 0.0, z = 0.0 },
        SpawnPoint  = { x = 5.0, y = 0.0, z = 0.0, heading = 180.0 },
        ImpoundedName = 'LosSantos',
        AllowedJobs   = { 'mechanic' },
        AllowedGrades = { mechanic = 0 },
        VehicleFilter = 'car',
    },
    --]]
}

-- ─── IMPOUNDS ──────────────────────────────────────────────────────────────────
--[[
    Each impound entry supports:
        GetOutPoint  — {x, y, z}   where the marker/interaction zone spawns
        SpawnPoint   — {x, y, z, heading} where the vehicle appears on release
        Cost         — base fee in $
        Label        — display name shown in the UI
        AllowedJobs  — if set, only these jobs can use restricted/free release flows
        AllowedGrades — minimum grade per job, e.g. {police=2}
        FreeRelease  — if AllowedJobs match the player, waive the fee
        Sprite / Scale / Colour — blip overrides (optional)
--]]

Config.Impounds = {
    LosSantos = {
        Label      = 'Los Santos Impound',
        GetOutPoint = { x = 400.7,  y = -1630.5, z = 29.3 },
        SpawnPoint  = { x = 401.9,  y = -1647.4, z = 29.2, heading = 323.3 },
        Cost       = 3000,
        AllowedJobs = nil,
        AllowedGrades = nil,
        FreeRelease = false,
        Sprite  = 524,
        Scale   = 0.8,
        Colour  = 1,
    },
    PaletoBay = {
        Label      = 'Paleto Bay Impound',
        GetOutPoint = { x = -211.4, y = 6206.5,  z = 31.4 },
        SpawnPoint  = { x = -204.6, y = 6221.6,  z = 30.5, heading = 227.2 },
        Cost       = 3000,
        AllowedJobs = nil,
        AllowedGrades = nil,
        FreeRelease = false,
        Sprite  = 524,
        Scale   = 0.8,
        Colour  = 1,
    },
    SandyShores = {
        Label      = 'Sandy Shores Impound',
        GetOutPoint = { x = 1728.2, y = 3709.3,  z = 33.2 },
        SpawnPoint  = { x = 1722.7, y = 3713.6,  z = 33.2, heading = 19.9 },
        Cost       = 3000,
        AllowedJobs = nil,
        AllowedGrades = nil,
        FreeRelease = false,
        Sprite  = 524,
        Scale   = 0.8,
        Colour  = 1,
    },
}

-- ─── ADMIN (ox_lib) ────────────────────────────────────────────────────────────
-- Menú para borrar filas de `owned_vehicles` (comando + callbacks servidor).
-- Los grupos deben coincidir con `Config.AdminGroups` de es_extended (o amplíalos aquí).
Config.AdminGarage = {
    Command = 'admingarage',
    -- Si true, registra un KeyMapping vacío (puedes asignar tecla en Ajustes → FiveM).
    KeyRegister = false,
    Groups = {
        ['owner'] = true,
        ['admin'] = true,
    },
}

-- ─── VERSION CHECK (GitHub) ────────────────────────────────────────────────────
-- Lightweight, server-side check that pings the GitHub Releases API on resource
-- start and prints a colored message in the FiveM console if there is a newer
-- version published in the upstream repository. No data is sent — just a single
-- HTTPS GET to api.github.com.
Config.VersionCheck = {
    Enabled  = true,
    Owner    = 'aariidev',
    Repo     = 'esx_garage-ari',
    -- Endpoint used. 'releases' = latest published release (recommended).
    -- Falls back to the newest tag automatically if no release exists yet.
    Endpoint = 'releases',
    -- Print "you are up to date" too, not only when there is a newer version
    Verbose  = true,
    -- Optional: re-check every N minutes (0 = only on resource start)
    IntervalMinutes = 0,
}

-- ─── EXPORTS ───────────────────────────────────────────────────────────────────
exports('getGarages',  function() return Config.Garages  end)
exports('getImpounds', function() return Config.Impounds end)
exports('getConfig',   function() return Config           end)
