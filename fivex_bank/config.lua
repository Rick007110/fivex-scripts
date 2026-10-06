Config = {}

Config.Locale = 'en'

-- Cash lives in the fivex_jobcenter wallet. Bank balance lives here.
Config.StartingBalance = 2500

-- Teller counters (stand-here points). Verify in game and adjust if a counter is off.
Config.Branches = {
    { label = 'Fleeca — Legion Square',       coords = vector3(149.46, -1040.75, 29.37) },
    { label = 'Fleeca — Hawick',              coords = vector3(313.84, -279.09, 54.16) },
    { label = 'Fleeca — Burton',              coords = vector3(-351.53, -49.53, 49.04) },
    { label = 'Fleeca — Rockford Hills',      coords = vector3(-1212.98, -330.84, 37.79) },
    { label = 'Fleeca — Great Ocean Hwy',     coords = vector3(-2962.58, 482.63, 15.70) },
    { label = 'Fleeca — Route 68',            coords = vector3(1175.06, 2706.64, 38.09) },
    { label = 'Pacific Standard',             coords = vector3(246.64, 223.20, 106.29) },
    { label = 'Blaine County Savings',        coords = vector3(-113.22, 6470.03, 31.63) },
}

Config.Blip = {
    sprite = 108,
    color = 2,
    scale = 0.75,
    label = 'Bank',
}

Config.Marker = {
    type = 1,
    scale = vector3(0.55, 0.55, 0.45),
    color = { r = 61, g = 154, b = 106, a = 140 },
}

Config.InteractDistance = 1.6
Config.DrawDistance = 10.0
-- Server re-checks teller actions against this distance.
Config.BranchDistance = 4.0

Config.AtmModels = {
    'prop_atm_01',
    'prop_atm_02',
    'prop_atm_03',
    'prop_fleeca_atm',
}
Config.AtmDistance = 1.2

-- ATMs are found client-side (the server cannot see map props), so they get tighter limits.
Config.Atm = {
    MaxWithdraw = 5000,
    MaxDeposit = 5000,
    AllowTransfer = true,
    MaxTransfer = 10000,
}

Config.MaxAmount = 1000000      -- per transaction, any channel
Config.HistoryMax = 40
Config.NoteMaxLength = 40

Config.RateLimit = {
    Open    = { max = 6,  window = 10000 },
    Action  = { max = 8,  window = 10000 },
    Generic = { max = 12, window = 10000 },
}

-- Resources allowed to call AddMoney / RemoveMoney exports.
Config.TrustedResources = {
    fivex_dealership = true,
    fivex_knoway = true,
    fivex_police = true,
    ND_Core = true, -- FiveX compatibility core: lets sd-phone's Bank / Wallet apps move money
}

Config.KvpBalance = 'fivex_bank_bal_v1:'
Config.KvpAccount = 'fivex_bank_acct_v1:'
Config.KvpOwner   = 'fivex_bank_owner_v1:'
Config.KvpHistory = 'fivex_bank_tx_v1:'
