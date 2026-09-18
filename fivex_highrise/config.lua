Config = {}
Config.JobId = 'highrise'
Config.Locale = 'en'

Config.Duty = vector4(-351.85, -141.22, 39.15, 210.0)
Config.Garage = vector4(-355.40, -149.80, 39.10, 210.0)

Config.Vehicle = {
    model = joaat('bison'),
    plate = 'WASHER',
}

Config.PayPerBuilding = 500
Config.GiveParachute = false
Config.InteractDistance = 2.0
Config.DrawDistance = 18.0
Config.DutyRadius = 4.0
Config.DoorRadius = 8.0
Config.WindowRadius = 8.0
Config.VehicleCooldown = 60000
Config.NextDelay = 5000
Config.FallGrace = 8.0

Config.Blip = {
    sprite = 475,
    color = 3,
    scale = 0.85,
    label = 'Window Depot',
}

Config.Marker = {
    type = 1,
    scale = vector3(1.0, 1.0, 0.5),
    color = { r = 91, g = 141, b = 239, a = 140 },
}

Config.Anim = {
    scrub = { dict = 'timetable@maid@cleaning_window@idle_a', clip = 'idle_a', ms = 3000, scenario = 'WORLD_HUMAN_MAID_CLEAN' },
}

-- Walkable roof equipment / exterior bays (not glass hang). Clustered on solid roofs.
Config.Buildings = {
    {
        id = 'arcadius',
        label = 'Arcadius',
        groundDoor = vector3(-144.5, -577.2, 32.42),
        roof = vector4(-139.0, -620.8, 168.82, 180.0),
        groundReturn = vector4(-144.5, -577.2, 32.42, 340.0),
        windows = {
            vector3(-141.5, -618.2, 168.82),
            vector3(-136.6, -618.2, 168.82),
            vector3(-141.5, -623.4, 168.82),
            vector3(-136.6, -623.4, 168.82),
            vector3(-139.0, -616.8, 168.82),
            vector3(-139.0, -624.8, 168.82),
        },
    },
    {
        id = 'mazebank',
        label = 'Maze Bank',
        groundDoor = vector3(-66.7, -802.8, 44.23),
        roof = vector4(-75.2, -819.2, 326.18, 250.0),
        groundReturn = vector4(-66.7, -802.8, 44.23, 70.0),
        windows = {
            vector3(-75.2, -819.2, 326.18),
            vector3(-70.2, -819.2, 326.18),
            vector3(-80.2, -819.2, 326.18),
            vector3(-75.2, -814.4, 326.18),
            vector3(-75.2, -824.0, 326.18),
            vector3(-70.4, -814.6, 326.18),
            vector3(-80.0, -823.8, 326.18),
        },
    },
    {
        id = 'fib',
        label = 'FIB',
        groundDoor = vector3(109.3, -744.2, 45.75),
        roof = vector4(136.1, -749.0, 258.15, 160.0),
        groundReturn = vector4(109.3, -744.2, 45.75, 340.0),
        windows = {
            vector3(136.1, -749.0, 258.15),
            vector3(140.4, -749.0, 258.15),
            vector3(131.8, -749.0, 258.15),
            vector3(136.1, -745.2, 258.15),
            vector3(136.1, -752.8, 258.15),
            vector3(140.2, -745.4, 258.15),
        },
    },
    {
        id = 'mazewest',
        label = 'Maze Bank West',
        groundDoor = vector3(-1370.0, -503.3, 33.16),
        roof = vector4(-1367.15, -471.55, 84.50, 30.0),
        groundReturn = vector4(-1370.0, -503.3, 33.16, 210.0),
        windows = {
            vector3(-1367.15, -471.55, 84.50),
            vector3(-1365.55, -471.55, 84.50),
            vector3(-1368.70, -471.55, 84.50),
            vector3(-1367.15, -470.00, 84.50),
            vector3(-1367.15, -473.10, 84.50),
            vector3(-1365.55, -470.00, 84.50),
        },
    },
}
