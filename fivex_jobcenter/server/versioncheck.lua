-- Auto-register with fivex_versioncheck (monorepo releases)
CreateThread(function()
    Wait(500)
    if GetResourceState('fivex_versioncheck') ~= 'started' then return end
    TriggerEvent(
        'fivex_versioncheck:register',
        GetCurrentResourceName(),
        GetResourceMetadata(GetCurrentResourceName(), 'repository', 0),
        GetResourceMetadata(GetCurrentResourceName(), 'version', 0),
        function(_) end
    )
end)
