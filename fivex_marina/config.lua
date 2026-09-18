Config = {}
Config.JobId = 'marina'
Config.Locale = 'en'

Config.Duty = vector4(-802.9, -1364.6, 5.18, 80.0)
Config.DinghySpawn = vector4(-810.5, -1491.2, 0.15, 110.0)
Config.DockStand = vector3(-800.2, -1496.5, 1.6)

Config.Slips = {
    { id = 'A', coords = vector3(-793.4, -1501.5, 0.2) },
    { id = 'B', coords = vector3(-786.0, -1488.0, 0.2) },
    { id = 'C', coords = vector3(-772.5, -1505.8, 0.2) },
}

Config.FuelPump = vector3(-798.4, -1513.2, 1.6)
Config.DetailCenter = vector3(-816.2, -1346.8, 5.15)
Config.DetailPoints = {
    vector3(-816.2, -1346.8, 5.15),
    vector3(-818.6, -1348.6, 5.15),
    vector3(-813.8, -1348.4, 5.15),
    vector3(-816.2, -1344.6, 5.15),
}

Config.FetchSpawn = vector4(-880.0, -1550.0, 0.1, 30.0)
Config.FetchModel = joaat('speeder')

Config.Vehicle = {
    model = joaat('dinghy2'),
    fallback = joaat('dinghy'),
    plate = 'MARINA',
}

Config.PayDock = 280
Config.PayFuel = 180
Config.PayDetail = 220

Config.InteractDistance = 2.0
Config.DrawDistance = 18.0
Config.DutyRadius = 4.0
Config.DockRadius = 8.0
Config.DockSpeed = 8.0
Config.VehicleCooldown = 60000
Config.NextDelay = 4000

Config.Blip = {
    sprite = 410,
    color = 3,
    scale = 0.85,
    label = 'Marina',
}

Config.Marker = {
    type = 1,
    scale = vector3(1.4, 1.4, 0.5),
    color = { r = 91, g = 141, b = 239, a = 140 },
}

Config.Anim = {
    grab = { dict = 'mini@repair', clip = 'fixing_a_ped', ms = 2000 },
    pour = { dict = 'mini@repair', clip = 'fixing_a_player', ms = 3000 },
    detail = { dict = 'timetable@maid@cleaning_window@idle_a', clip = 'idle_a', ms = 2500, scenario = 'WORLD_HUMAN_MAID_CLEAN' },
}

Config.TaskOrder = { 'fetch', 'fuel', 'detail' }
