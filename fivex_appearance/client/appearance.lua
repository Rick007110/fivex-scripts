--- Get / set / apply / randomize local appearance. Client-side only.

Appearance = {}

local function at(t, i)
    if type(t) ~= 'table' then return nil end
    local v = t[i]
    if v ~= nil then return v end
    return t[tostring(i)]
end

local function clamp(n, lo, hi)
    n = tonumber(n)
    if not n then return lo end
    if n < lo then return lo end
    if n > hi then return hi end
    return n
end

local function clampInt(n, lo, hi)
    return math.floor(clamp(n, lo, hi) + 0.0)
end

function Appearance.Clone(src)
    if type(src) ~= 'table' then return nil end
    return json.decode(json.encode(src))
end

function Appearance.EmptyOverlays()
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

function Appearance.EmptyFace()
    local t = {}
    for i = 0, 19 do
        t[i] = 0.0
    end
    return t
end

function Appearance.IsMale(model)
    return Defaults.NormalizeModel(model) == Defaults.MaleModel
end

function Appearance.ModelName(model)
    return Defaults.NormalizeModel(model) or Defaults.MaleModel
end

function Appearance.ModelHash(model)
    local name = Appearance.ModelName(model)
    return joaat(name)
end

local function readComp(t, i, fallback)
    local c = at(t, i)
    if type(c) ~= 'table' then
        return { drawable = fallback or 0, texture = 0 }
    end
    return {
        drawable = clampInt(c.drawable, -1, 512),
        texture = clampInt(c.texture, 0, 128),
    }
end

function Appearance.Normalize(data)
    if type(data) ~= 'table' then
        return Defaults.Male()
    end
    local model = Defaults.NormalizeModel(data.model) or Defaults.MaleModel
    local base = Defaults.ForModel(model)
    local hb = type(data.headBlend) == 'table' and data.headBlend or base.headBlend
    local hair = type(data.hair) == 'table' and data.hair or base.hair
    local out = {
        model = model,
        headBlend = {
            shapeFirst = clampInt(hb.shapeFirst, 0, Config.MaxParent),
            shapeSecond = clampInt(hb.shapeSecond, 0, Config.MaxParent),
            shapeThird = clampInt(hb.shapeThird, 0, Config.MaxParent),
            skinFirst = clampInt(hb.skinFirst, 0, Config.MaxParent),
            skinSecond = clampInt(hb.skinSecond, 0, Config.MaxParent),
            skinThird = clampInt(hb.skinThird, 0, Config.MaxParent),
            shapeMix = clamp(hb.shapeMix, 0.0, 1.0),
            skinMix = clamp(hb.skinMix, 0.0, 1.0),
            thirdMix = clamp(hb.thirdMix, 0.0, 1.0),
        },
        faceFeatures = Appearance.EmptyFace(),
        overlays = Appearance.EmptyOverlays(),
        hair = {
            style = clampInt(hair.style, 0, 512),
            texture = clampInt(hair.texture, 0, 128),
            color = clampInt(hair.color, 0, 63),
            highlight = clampInt(hair.highlight, 0, 63),
        },
        eyeColor = clampInt(data.eyeColor, 0, 31),
        components = {},
        props = {},
        tattoos = {},
    }
    for i = 0, 19 do
        local v = at(data.faceFeatures, i)
        if v == nil then v = at(base.faceFeatures, i) end
        out.faceFeatures[i] = clamp(v or 0.0, -1.0, 1.0)
    end
    for i = 0, 12 do
        local ov = at(data.overlays, i) or at(base.overlays, i)
        local meta = Defaults.Overlays[i + 1]
        if type(ov) == 'table' then
            out.overlays[i] = {
                index = clampInt(ov.index, 0, 255),
                opacity = clamp(ov.opacity, 0.0, 1.0),
                colourType = clampInt(ov.colourType or (meta and meta.colourType) or 0, 0, 2),
                colour = clampInt(ov.colour, 0, 63),
                secondColour = clampInt(ov.secondColour, 0, 63),
            }
        end
    end
    local comps = type(data.components) == 'table' and data.components or base.components
    for i = 0, 11 do
        out.components[i] = readComp(comps, i, 0)
        if out.components[i].drawable < 0 then
            out.components[i].drawable = 0
        end
    end
    if type(data.hair) == 'table' then
        out.components[2] = { drawable = out.hair.style, texture = out.hair.texture }
    else
        out.hair.style = out.components[2].drawable
        out.hair.texture = out.components[2].texture
    end
    -- Config.Blacklist: fall back to the model default, else drawable 0.
    for i = 0, 11 do
        local c = out.components[i]
        if Appearance.Blacklisted(model, 'component', i, c.drawable) then
            local fb = at(base.components, i)
            local d = fb and fb.drawable or 0
            if Appearance.Blacklisted(model, 'component', i, d) then d = 0 end
            out.components[i] = { drawable = d, texture = 0 }
        end
    end
    out.hair.style = out.components[2].drawable
    out.hair.texture = out.components[2].texture
    local props = type(data.props) == 'table' and data.props or base.props
    for _, pid in ipairs(Defaults.PropIds) do
        out.props[pid] = readComp(props, pid, -1)
        if out.props[pid].drawable < -1 then
            out.props[pid].drawable = -1
        end
        if out.props[pid].drawable >= 0 and Appearance.Blacklisted(model, 'prop', pid, out.props[pid].drawable) then
            out.props[pid] = { drawable = -1, texture = 0 }
        end
    end
    local tats = data.tattoos
    if type(tats) == 'table' then
        local maxT = Config.MaxTattoos or 48
        local n = 0
        for i = 1, #tats do
            local t = tats[i]
            if type(t) == 'table' and n < maxT then
                local rec = TattooLookup(t.collection, t.overlay)
                if rec then
                    n = n + 1
                    out.tattoos[n] = { collection = rec.collection, overlay = rec.overlay, zone = rec.zone }
                end
            end
        end
    end
    return out
end

function Appearance.Blacklisted(model, kind, slot, drawable)
    local name = Appearance.ModelName(model)
    local bag
    if kind == 'prop' then
        bag = Config.PropBlacklist and Config.PropBlacklist[name]
    else
        bag = Config.Blacklist and Config.Blacklist[name]
    end
    if type(bag) ~= 'table' then return false end
    local list = at(bag, slot) or bag[slot]
    if type(list) ~= 'table' then return false end
    for i = 1, #list do
        if list[i] == drawable then return true end
    end
    return false
end

function Appearance.EnumerateComponent(ped, componentId)
    componentId = tonumber(componentId) or 0
    local n = GetNumberOfPedDrawableVariations(ped, componentId)
    local model = GetEntityModel(ped)
    local items = {}
    for d = 0, n - 1 do
        if not Appearance.Blacklisted(model, 'component', componentId, d) then
            local tex = GetNumberOfPedTextureVariations(ped, componentId, d)
            if tex and tex > 0 then
                items[#items + 1] = { id = d, textures = tex }
            end
        end
    end
    return items
end

function Appearance.EnumerateProp(ped, propId)
    propId = tonumber(propId) or 0
    local n = GetNumberOfPedPropDrawableVariations(ped, propId)
    local model = GetEntityModel(ped)
    local items = { { id = -1, textures = 1 } }
    for d = 0, n - 1 do
        if not Appearance.Blacklisted(model, 'prop', propId, d) then
            local tex = GetNumberOfPedPropTextureVariations(ped, propId, d)
            if tex > 0 then
                items[#items + 1] = { id = d, textures = tex }
            end
        end
    end
    return items
end

function Appearance.TextureCount(ped, kind, slot, drawable)
    if kind == 'prop' then
        if drawable == nil or drawable < 0 then return 1 end
        return GetNumberOfPedPropTextureVariations(ped, slot, drawable)
    end
    return GetNumberOfPedTextureVariations(ped, slot, drawable or 0)
end

local function requestModel(hash, timeoutMs)
    if not hash or hash == 0 then return false end
    if not IsModelInCdimage(hash) or not IsModelValid(hash) then return false end
    RequestModel(hash)
    local deadline = GetGameTimer() + (timeoutMs or 5000)
    while not HasModelLoaded(hash) do
        if GetGameTimer() > deadline then
            return false
        end
        Wait(10)
    end
    return true
end

function Appearance.Apply(data, opts)
    opts = opts or {}
    data = Appearance.Normalize(data)
    local hash = joaat(data.model)
    local ped = PlayerPedId()
    local current = GetEntityModel(ped)
    if current ~= hash then
        if not requestModel(hash, 5000) then
            return false, 'model'
        end
        SetPlayerModel(PlayerId(), hash)
        Wait(0)
        ped = PlayerPedId()
        SetPedDefaultComponentVariation(ped)
        Wait(0)
        ped = PlayerPedId()
        SetModelAsNoLongerNeeded(hash)
        if Cam and Cam.IsOpen and Cam.IsOpen() and Cam.Retarget then
            Cam.Retarget()
        end
        local modest = Defaults.ForModel(data.model)
        for i = 0, 11 do
            local c = at(modest.components, i)
            if c then
                SetPedComponentVariation(ped, i, c.drawable, c.texture, 0)
            end
        end
    end
    ped = PlayerPedId()

    local hb = data.headBlend
    SetPedHeadBlendData(
        ped,
        hb.shapeFirst, hb.shapeSecond, hb.shapeThird,
        hb.skinFirst, hb.skinSecond, hb.skinThird,
        hb.shapeMix + 0.0, hb.skinMix + 0.0, hb.thirdMix + 0.0,
        false
    )
    local blendDeadline = GetGameTimer() + 800
    while GetGameTimer() < blendDeadline do
        local finished = false
        pcall(function()
            finished = HasPedHeadBlendFinished(ped)
        end)
        if finished then break end
        Wait(0)
    end

    for i = 0, 19 do
        SetPedFaceFeature(ped, i, (at(data.faceFeatures, i) or 0.0) + 0.0)
    end

    for i = 0, 12 do
        local ov = at(data.overlays, i)
        if ov then
            local idx = ov.index
            if idx == nil then idx = 255 end
            local opacity = ov.opacity or 0.0
            if idx >= 255 or opacity <= 0.001 then
                SetPedHeadOverlay(ped, i, 255, 0.0)
            else
                SetPedHeadOverlay(ped, i, idx, opacity + 0.0)
                local ct = ov.colourType or 0
                if ct > 0 then
                    SetPedHeadOverlayColor(ped, i, ct, ov.colour or 0, ov.secondColour or 0)
                end
            end
        else
            SetPedHeadOverlay(ped, i, 255, 0.0)
        end
    end

    for i = 0, 11 do
        local c = at(data.components, i)
        if c then
            SetPedComponentVariation(ped, i, c.drawable, c.texture, 0)
        end
    end
    SetPedComponentVariation(ped, 2, data.hair.style, data.hair.texture, 0)
    SetPedHairColor(ped, data.hair.color, data.hair.highlight)
    SetPedEyeColor(ped, data.eyeColor)

    ClearAllPedProps(ped)
    for _, pid in ipairs(Defaults.PropIds) do
        local p = at(data.props, pid)
        if p and p.drawable ~= nil and p.drawable >= 0 then
            SetPedPropIndex(ped, pid, p.drawable, p.texture or 0, true)
        else
            ClearPedProp(ped, pid)
        end
    end

    ClearPedDecorations(ped)
    local tats = data.tattoos or {}
    for i = 1, #tats do
        local t = tats[i]
        if type(t) == 'table' then
            local col = t.collection
            local ov = t.overlay
            if type(col) == 'string' then col = joaat(col) end
            if type(ov) == 'string' then ov = joaat(ov) end
            if col and ov then
                AddPedDecorationFromHashes(ped, col, ov)
            end
        end
    end

    return true
end

function Appearance.GetCurrent()
    local ped = PlayerPedId()
    local model = Appearance.ModelName(GetEntityModel(ped))
    local data = Defaults.ForModel(model)
    data.model = model

    -- Head blend is not read back (GET_PED_HEAD_BLEND_DATA needs a struct); keep model defaults.
    -- Callers typically have the working table already. We still read components.
    data.eyeColor = GetPedEyeColor(ped)

    for i = 0, 11 do
        data.components[i] = {
            drawable = GetPedDrawableVariation(ped, i),
            texture = GetPedTextureVariation(ped, i),
        }
    end
    data.hair.style = data.components[2].drawable
    data.hair.texture = data.components[2].texture
    local hc, hh = 0, 0
    pcall(function()
        hc = GetPedHairColor(ped)
        hh = GetPedHairHighlightColor(ped)
    end)
    data.hair.color = hc or 0
    data.hair.highlight = hh or 0

    for _, pid in ipairs(Defaults.PropIds) do
        local d = GetPedPropIndex(ped, pid)
        local tex = 0
        if d >= 0 then
            tex = GetPedPropTextureIndex(ped, pid)
        end
        data.props[pid] = { drawable = d, texture = tex }
    end

    for i = 0, 12 do
        local idx = GetPedHeadOverlayValue(ped, i)
        local opacity = 0.0
        pcall(function()
            opacity = GetPedHeadOverlayNum and 0.0 or 0.0
        end)
        local meta = Defaults.Overlays[i + 1]
        data.overlays[i] = {
            index = idx or 255,
            opacity = (idx and idx < 255) and 1.0 or 0.0,
            colourType = meta and meta.colourType or 0,
            colour = 0,
            secondColour = 0,
        }
    end

    return data
end

function Appearance.Randomize(data, tab, sexModel)
    data = Appearance.Normalize(data)
    local ped = PlayerPedId()
    local function randItem(items)
        if not items or #items == 0 then return nil end
        return items[math.random(1, #items)]
    end
    local function randComp(slot)
        local items = Appearance.EnumerateComponent(ped, slot)
        local it = randItem(items)
        if it then
            local tex = math.max(0, (it.textures or 1) - 1)
            data.components[slot] = { drawable = it.id, texture = math.random(0, tex) }
        end
    end
    local function randProp(slot)
        local items = Appearance.EnumerateProp(ped, slot)
        local it = randItem(items)
        if it then
            local tex = math.max(0, (it.textures or 1) - 1)
            data.props[slot] = { drawable = it.id, texture = it.id < 0 and 0 or math.random(0, tex) }
        end
    end
    local function randHair()
        randComp(2)
        data.hair.style = data.components[2].drawable
        data.hair.texture = data.components[2].texture
        data.hair.color = math.random(0, 63)
        data.hair.highlight = math.random(0, 63)
    end
    local function randHeritage()
        data.headBlend.shapeFirst = math.random(0, Config.MaxParent)
        data.headBlend.shapeSecond = math.random(0, Config.MaxParent)
        data.headBlend.skinFirst = math.random(0, Config.MaxParent)
        data.headBlend.skinSecond = math.random(0, Config.MaxParent)
        data.headBlend.shapeMix = math.random() 
        data.headBlend.skinMix = math.random()
        data.headBlend.thirdMix = 0.0
    end
    local function randFace()
        for i = 0, 19 do
            data.faceFeatures[i] = (math.random() * 2.0) - 1.0
        end
    end
    local function randOverlay(id, forceOn)
        local maxIdx = GetPedHeadOverlayNum(id) or 0
        if maxIdx <= 0 then
            data.overlays[id].index = 255
            data.overlays[id].opacity = 0.0
            return
        end
        if forceOn or math.random() > 0.45 then
            data.overlays[id].index = math.random(0, math.max(0, maxIdx - 1))
            data.overlays[id].opacity = 0.35 + math.random() * 0.65
            data.overlays[id].colour = math.random(0, 63)
            data.overlays[id].secondColour = math.random(0, 63)
        else
            data.overlays[id].index = 255
            data.overlays[id].opacity = 0.0
        end
    end

    tab = tab or 'all'
    if tab == 'identity' and sexModel then
        data = Defaults.ForModel(sexModel)
        return Appearance.Normalize(data)
    end
    if tab == 'heritage' or tab == 'all' then randHeritage() end
    if tab == 'face' or tab == 'all' then randFace() end
    if tab == 'hair' or tab == 'all' then randHair() end
    if tab == 'overlays' or tab == 'all' then
        for i = 0, 12 do
            randOverlay(i, false)
        end
    end
    if tab == 'eyes' or tab == 'all' then
        data.eyeColor = math.random(0, 31)
    end
    if tab == 'clothing' or tab == 'all' then
        for _, id in ipairs(Defaults.ClothingComponents) do
            randComp(id)
        end
    end
    if tab == 'props' or tab == 'all' then
        for _, id in ipairs(Defaults.PropIds) do
            randProp(id)
        end
    end
    return Appearance.Normalize(data)
end

function Appearance.ToNui(data)
    data = Appearance.Normalize(data)
    local ff, ov, comps, props = {}, {}, {}, {}
    for i = 0, 19 do ff[tostring(i)] = data.faceFeatures[i] end
    for i = 0, 12 do ov[tostring(i)] = data.overlays[i] end
    for i = 0, 11 do comps[tostring(i)] = data.components[i] end
    for _, pid in ipairs(Defaults.PropIds) do
        props[tostring(pid)] = data.props[pid]
    end
    return {
        model = data.model,
        headBlend = data.headBlend,
        faceFeatures = ff,
        overlays = ov,
        hair = data.hair,
        eyeColor = data.eyeColor,
        components = comps,
        props = props,
        tattoos = data.tattoos,
    }
end

function Appearance.OverlayMax(id)
    local n = GetPedHeadOverlayNum(id)
    if not n or n < 0 then return 0 end
    return n
end

function Appearance.PaletteCounts()
    local hair = Config.HairColors or 64
    local makeup = Config.MakeupColors or 64
    pcall(function()
        local n = GetNumHairColors()
        if n and n > 0 then hair = n end
    end)
    pcall(function()
        local n = GetNumMakeupColors()
        if n and n > 0 then makeup = n end
    end)
    return { hair = hair, makeup = makeup, eyes = Config.EyeColors or 32 }
end
