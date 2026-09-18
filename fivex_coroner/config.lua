Config = {}
Config.JobId = 'coroner'
Config.Locale = 'en'

Config.Duty = vector4(240.8, -1379.5, 33.74, 140.0)
Config.Garage = vector4(227.47,-1355.59,30.58,138.5)
Config.Delivery = vector3(263.22,-1350.34,31.96)

Config.Vehicle = {
    model = joaat('rumpo'),
    plate = 'CORONER',
    capacity = 2,
}

Config.PayPerBody = 350
Config.InteractDistance = 2.0
Config.DrawDistance = 18.0
Config.PickupRadius = 25.0
Config.DeliverRadius = 15.0
Config.LoadRadius = 8.0
Config.LoadInteract = 4.0
Config.DutyRadius = 4.0
Config.VehicleCooldown = 60000
Config.NextDelay = 5000

Config.Blip = {
    sprite = 310,
    color = 40,
    scale = 0.85,
    label = 'Morgue',
}

Config.Marker = {
    type = 1,
    scale = vector3(1.1, 1.1, 0.55),
    color = { r = 91, g = 141, b = 239, a = 140 },
}

Config.PedModels = {
    joaat('a_m_m_skater_01'),
    joaat('a_f_y_hipster_01'),
    joaat('a_m_y_beach_01'),
    joaat('a_m_m_business_01'),
    joaat('a_f_y_vinewood_01'),
    joaat('a_m_y_hipster_01'),
    joaat('a_m_m_soucent_01'),
    joaat('a_f_m_bevhills_01'),
}

-- On-foot LS call pool (no interiors)
Config.Calls = {
    vector3(160.2, -987.5, 30.09),
    vector3(-1214.4, -1452.0, 4.37),
    vector3(844.3, -1035.4, 28.19),
    vector3(1142.0, -390.5, 67.0),
    vector3(-1850.2, -1230.5, 13.02),
    vector3(85.4, -1553.8, 29.6),
    vector3(418.5, -807.4, 29.34),
    vector3(-1034.5, -2733.2, 20.17),
    vector3(595.2, -3116.5, 6.07),
    vector3(252.5, -1670.8, 29.66),
}

Config.Anim = {
    bag = { dict = 'amb@medic@standing@kneel@base', clip = 'base', ms = 4000 },
    load = { dict = 'mini@repair', clip = 'fixing_a_ped', ms = 2500 },
    deliver = { dict = 'mini@repair', clip = 'fixing_a_player', ms = 3000 },
}
