-- Builds Config.Catalog from data/vehicles.lua + config overrides. Shared: client and server see the same list.
local enabled = {}
for _, c in ipairs(Config.Categories) do enabled[c.id] = true end

local mult = tonumber(Config.PriceMultiplier) or 1.0
local function nice(p)
    local step = p < 5000 and 100 or p < 20000 and 500 or p < 100000 and 1000 or 5000
    return math.max(1, math.floor(p / step + 0.5) * step)
end

Config.Catalog = {}
for _, v in ipairs(GeneratedCatalog or {}) do
    if enabled[v.category] and not Config.ExcludeModels[v.model] then
        local price = Config.PriceOverrides[v.model] or nice(v.price * mult)
        Config.Catalog[#Config.Catalog + 1] = {
            model = v.model, label = v.label, brand = v.brand, price = price,
            category = v.category, type = v.type,
        }
    end
end
GeneratedCatalog = nil
