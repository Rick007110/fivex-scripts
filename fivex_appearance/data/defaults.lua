--- Modest default appearances so the first model is dressed (not underwear).
--- Components follow GTA Online freemode slots 0–11.

Defaults = {}

Defaults.MaleModel = 'mp_m_freemode_01'
Defaults.FemaleModel = 'mp_f_freemode_01'

Defaults.MaleHash = joaat('mp_m_freemode_01')
Defaults.FemaleHash = joaat('mp_f_freemode_01')

--- 0–20 male, 21–41 female, 42–45 special.
Defaults.Parents = {
    { id = 0,  name = 'Benjamin', sex = 'm' },
    { id = 1,  name = 'Daniel',   sex = 'm' },
    { id = 2,  name = 'Joshua',   sex = 'm' },
    { id = 3,  name = 'Noah',     sex = 'm' },
    { id = 4,  name = 'Andrew',   sex = 'm' },
    { id = 5,  name = 'Joan',     sex = 'm' },
    { id = 6,  name = 'Alex',     sex = 'm' },
    { id = 7,  name = 'Isaac',    sex = 'm' },
    { id = 8,  name = 'Evan',     sex = 'm' },
    { id = 9,  name = 'Ethan',    sex = 'm' },
    { id = 10, name = 'Vincent',  sex = 'm' },
    { id = 11, name = 'Angel',    sex = 'm' },
    { id = 12, name = 'Diego',    sex = 'm' },
    { id = 13, name = 'Adrian',   sex = 'm' },
    { id = 14, name = 'Gabriel',  sex = 'm' },
    { id = 15, name = 'Michael',  sex = 'm' },
    { id = 16, name = 'Santiago', sex = 'm' },
    { id = 17, name = 'Kevin',    sex = 'm' },
    { id = 18, name = 'Louis',    sex = 'm' },
    { id = 19, name = 'Samuel',   sex = 'm' },
    { id = 20, name = 'Anthony',  sex = 'm' },
    { id = 21, name = 'Hannah',   sex = 'f' },
    { id = 22, name = 'Audrey',   sex = 'f' },
    { id = 23, name = 'Jasmine',  sex = 'f' },
    { id = 24, name = 'Giselle',  sex = 'f' },
    { id = 25, name = 'Amelia',   sex = 'f' },
    { id = 26, name = 'Isabella', sex = 'f' },
    { id = 27, name = 'Zoe',      sex = 'f' },
    { id = 28, name = 'Ava',      sex = 'f' },
    { id = 29, name = 'Camila',   sex = 'f' },
    { id = 30, name = 'Violet',   sex = 'f' },
    { id = 31, name = 'Sophia',   sex = 'f' },
    { id = 32, name = 'Evelyn',   sex = 'f' },
    { id = 33, name = 'Nicole',   sex = 'f' },
    { id = 34, name = 'Ashley',   sex = 'f' },
    { id = 35, name = 'Grace',    sex = 'f' },
    { id = 36, name = 'Brianna',  sex = 'f' },
    { id = 37, name = 'Natalie',  sex = 'f' },
    { id = 38, name = 'Olivia',   sex = 'f' },
    { id = 39, name = 'Elizabeth', sex = 'f' },
    { id = 40, name = 'Charlotte', sex = 'f' },
    { id = 41, name = 'Emma',     sex = 'f' },
    { id = 42, name = 'Misty',    sex = 's' },
    { id = 43, name = 'Niko',     sex = 's' },
    { id = 44, name = 'Claude',   sex = 's' },
    { id = 45, name = 'John',     sex = 's' },
}

--- Overlay metadata. colourType: 0 none, 1 hair palette, 2 makeup palette.
Defaults.Overlays = {
    { id = 0,  colourType = 0, barber = false },
    { id = 1,  colourType = 1, barber = true },
    { id = 2,  colourType = 1, barber = true },
    { id = 3,  colourType = 0, barber = false },
    { id = 4,  colourType = 2, barber = true },
    { id = 5,  colourType = 2, barber = false },
    { id = 6,  colourType = 0, barber = false },
    { id = 7,  colourType = 0, barber = false },
    { id = 8,  colourType = 2, barber = true },
    { id = 9,  colourType = 0, barber = false },
    { id = 10, colourType = 1, barber = false },
    { id = 11, colourType = 0, barber = false },
    { id = 12, colourType = 0, barber = false },
}

Defaults.ClothingComponents = { 1, 3, 4, 5, 6, 7, 8, 9, 10, 11 }
Defaults.PropIds = { 0, 1, 2, 6, 7 }

local function faceZero()
    local t = {}
    for i = 0, 19 do
        t[i] = 0.0
    end
    return t
end

local function overlaysOff()
    local t = {}
    for i = 0, 12 do
        local meta = Defaults.Overlays[i + 1]
        t[i] = {
            index = 255,
            opacity = 0.0,
            colourType = meta and meta.colourType or 0,
            colour = 0,
            secondColour = 0,
        }
    end
    return t
end

--- Male: white t-shirt, jeans, sneakers. Component 8=15 is the empty undershirt
--- required by most male tops; 11=0 is a basic tee; 4=4 jeans; 6=1 shoes.
function Defaults.Male()
    return {
        model = Defaults.MaleModel,
        headBlend = {
            shapeFirst = 0, shapeSecond = 21, shapeThird = 0,
            skinFirst = 0, skinSecond = 21, skinThird = 0,
            shapeMix = 0.5, skinMix = 0.5, thirdMix = 0.0,
        },
        faceFeatures = faceZero(),
        overlays = overlaysOff(),
        hair = { style = 3, texture = 0, color = 1, highlight = 1 },
        eyeColor = 0,
        components = {
            [0]  = { drawable = 0, texture = 0 },
            [1]  = { drawable = 0, texture = 0 },
            [2]  = { drawable = 3, texture = 0 },
            [3]  = { drawable = 0, texture = 0 },
            [4]  = { drawable = 4, texture = 0 },
            [5]  = { drawable = 0, texture = 0 },
            [6]  = { drawable = 1, texture = 0 },
            [7]  = { drawable = 0, texture = 0 },
            [8]  = { drawable = 15, texture = 0 },
            [9]  = { drawable = 0, texture = 0 },
            [10] = { drawable = 0, texture = 0 },
            [11] = { drawable = 0, texture = 0 },
        },
        props = {
            [0] = { drawable = -1, texture = 0 },
            [1] = { drawable = -1, texture = 0 },
            [2] = { drawable = -1, texture = 0 },
            [6] = { drawable = -1, texture = 0 },
            [7] = { drawable = -1, texture = 0 },
        },
        tattoos = {},
    }
end

--- Female: top + jeans + shoes. 8=2 is a compatible undershirt; 11=0 a basic top.
function Defaults.Female()
    return {
        model = Defaults.FemaleModel,
        headBlend = {
            shapeFirst = 21, shapeSecond = 0, shapeThird = 0,
            skinFirst = 21, skinSecond = 0, skinThird = 0,
            shapeMix = 0.5, skinMix = 0.5, thirdMix = 0.0,
        },
        faceFeatures = faceZero(),
        overlays = overlaysOff(),
        hair = { style = 4, texture = 0, color = 8, highlight = 8 },
        eyeColor = 0,
        components = {
            [0]  = { drawable = 0, texture = 0 },
            [1]  = { drawable = 0, texture = 0 },
            [2]  = { drawable = 4, texture = 0 },
            [3]  = { drawable = 14, texture = 0 },
            [4]  = { drawable = 1, texture = 0 },
            [5]  = { drawable = 0, texture = 0 },
            [6]  = { drawable = 1, texture = 0 },
            [7]  = { drawable = 0, texture = 0 },
            [8]  = { drawable = 2, texture = 0 },
            [9]  = { drawable = 0, texture = 0 },
            [10] = { drawable = 0, texture = 0 },
            [11] = { drawable = 0, texture = 0 },
        },
        props = {
            [0] = { drawable = -1, texture = 0 },
            [1] = { drawable = -1, texture = 0 },
            [2] = { drawable = -1, texture = 0 },
            [6] = { drawable = -1, texture = 0 },
            [7] = { drawable = -1, texture = 0 },
        },
        tattoos = {},
    }
end

function Defaults.ForModel(model)
    local name = Defaults.NormalizeModel(model)
    if name == Defaults.FemaleModel then
        return Defaults.Female()
    end
    return Defaults.Male()
end

function Defaults.NormalizeModel(model)
    if type(model) == 'number' then
        if model == Defaults.FemaleHash then return Defaults.FemaleModel end
        if model == Defaults.MaleHash then return Defaults.MaleModel end
        return nil
    end
    if type(model) ~= 'string' then return nil end
    local s = model:lower()
    if s == Defaults.FemaleModel then return Defaults.FemaleModel end
    if s == Defaults.MaleModel then return Defaults.MaleModel end
    return nil
end

function Defaults.IsAllowedModel(model)
    return Defaults.NormalizeModel(model) ~= nil
end
