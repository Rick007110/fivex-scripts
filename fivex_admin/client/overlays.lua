local blips = {}
local gamerTags = {}

local function wipeBlips()
    for id, blip in pairs(blips) do
        if DoesBlipExist(blip) then
            RemoveBlip(blip)
        end
        blips[id] = nil
    end
end

local function wipeTags()
    for id, tag in pairs(gamerTags) do
        if IsMpGamerTagActive(tag) then
            RemoveMpGamerTag(tag)
        end
        gamerTags[id] = nil
    end
end

function RefreshOverlays()
    if not (SelfState.blips) then
        wipeBlips()
    end
    if not (SelfState.names or SelfState.ids) then
        wipeTags()
    end
end

CreateThread(function()
    while true do
        local wantBlips = SelfState.blips
        local wantTags = SelfState.names or SelfState.ids
        if not wantBlips and not wantTags then
            wipeBlips()
            wipeTags()
            Wait(500)
        else
            Wait(0)
            local myId = PlayerId()
            local seen = {}
            for _, pid in ipairs(GetActivePlayers()) do
                if pid ~= myId then
                    local ped = GetPlayerPed(pid)
                    if DoesEntityExist(ped) then
                        local sid = GetPlayerServerId(pid)
                        seen[sid] = true
                        if wantBlips then
                            if not blips[sid] or not DoesBlipExist(blips[sid]) then
                                local blip = AddBlipForEntity(ped)
                                SetBlipSprite(blip, 1)
                                SetBlipColour(blip, 0)
                                SetBlipScale(blip, 0.75)
                                SetBlipCategory(blip, 7)
                                BeginTextCommandSetBlipName('STRING')
                                AddTextComponentSubstringPlayerName(GetPlayerName(pid) or 'Player')
                                EndTextCommandSetBlipName(blip)
                                blips[sid] = blip
                            end
                        end
                        if wantTags then
                            if not gamerTags[sid] or not IsMpGamerTagActive(gamerTags[sid]) then
                                gamerTags[sid] = CreateFakeMpGamerTag(ped, '', false, false, '', 0)
                            end
                            local tag = gamerTags[sid]
                            local label = ''
                            if SelfState.ids and SelfState.names then
                                label = ('[%s] %s'):format(sid, GetPlayerName(pid) or '')
                            elseif SelfState.ids then
                                label = tostring(sid)
                            else
                                label = GetPlayerName(pid) or ''
                            end
                            SetMpGamerTagName(tag, label)
                            SetMpGamerTagVisibility(tag, 0, true)
                            SetMpGamerTagAlpha(tag, 0, 255)
                        end
                    end
                end
            end
            for sid, blip in pairs(blips) do
                if not seen[sid] then
                    if DoesBlipExist(blip) then RemoveBlip(blip) end
                    blips[sid] = nil
                end
            end
            for sid, tag in pairs(gamerTags) do
                if not seen[sid] then
                    if IsMpGamerTagActive(tag) then RemoveMpGamerTag(tag) end
                    gamerTags[sid] = nil
                end
            end
            if not wantBlips then wipeBlips() end
            if not wantTags then wipeTags() end
        end
    end
end)

CreateThread(function()
    while true do
        if not SelfState.dev then
            Wait(500)
        else
            Wait(0)
            local ped = PlayerPedId()
            local c = GetEntityCoords(ped)
            local h = GetEntityHeading(ped)
            local speed = GetEntitySpeed(ped) * 3.6
            local veh = GetVehiclePedIsIn(ped, false)
            local aim = ''
            local hit, entity = GetEntityPlayerIsFreeAimingAt(PlayerId())
            if hit and entity and entity ~= 0 then
                aim = ('aim %s  model %s'):format(entity, GetEntityModel(entity))
            end
            local vehLine = ''
            if veh ~= 0 then
                vehLine = ('veh %s  %s'):format(GetDisplayNameFromVehicleModel(GetEntityModel(veh)), GetEntityModel(veh))
            end
            local text = ('x %.2f  y %.2f  z %.2f  h %.1f\n%.1f km/h\n%s\n%s'):format(c.x, c.y, c.z, h, speed, vehLine, aim)
            SetTextFont(4)
            SetTextScale(0.35, 0.35)
            SetTextColour(230, 237, 243, 220)
            SetTextOutline()
            SetTextDropshadow(1, 0, 0, 0, 200)
            SetTextEntry('STRING')
            AddTextComponentSubstringPlayerName(text)
            DrawText(0.012, 0.50)
        end
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    wipeBlips()
    wipeTags()
end)
