Config = {}

Config.Locale = 'en'

-- Mission Row / City Hall steps (Legion Square sidewalk)
Config.Center = vector4(-266.0, -960.4, 31.22, 200.0)
Config.PedModel = joaat('a_m_y_business_03')
Config.PedScenario = 'WORLD_HUMAN_CLIPBOARD'

Config.Blip = {
    sprite = 407,
    color = 3,
    scale = 0.85,
    label = 'Job Center',
}

Config.InteractDistance = 2.0
Config.DrawDistance = 12.0
Config.OpenDistance = 3.0
Config.ApplyDistance = 4.0

Config.Marker = {
    type = 1,
    scale = vector3(0.55, 0.55, 0.45),
    color = { r = 91, g = 141, b = 239, a = 140 },
}

Config.Jobs = {
    { id = 'coroner',  label = 'Coroner',           blurb = 'Recover the dead. Tag them. Bring them in.' },
    { id = 'highrise', label = 'High-rise washer',  blurb = 'Windows, ledges, city roofs. Don\'t fall.' },
    { id = 'marina',   label = 'Marina handler',    blurb = 'Dock boats, fuel, detail, keep the slips moving.' },
}

Config.ValidJobs = {
    coroner = true,
    highrise = true,
    marina = true,
}

Config.RateLimit = {
    Apply = { max = 5, window = 20000 },
    Pay   = { max = 20, window = 30000 },
    Generic = { max = 12, window = 10000 },
}

Config.PayClamp = { min = 1, max = 5000 }

Config.KvpJob = 'fivex_job_v1:'
Config.KvpPay = 'fivex_job_pay_v1:'
