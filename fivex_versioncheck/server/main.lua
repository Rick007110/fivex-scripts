--[[
  fivex_versioncheck — monorepo-safe GitHub Releases checker.
  Preferred tag: {resource}-v{semver}  (also {resource}/{semver})
]]

local DEFAULT_INTERVAL_MS = 24 * 60 * 60 * 1000
local registered = {}

local function trim(s)
    if type(s) ~= 'string' then return '' end
    return (s:gsub('^%s+', ''):gsub('%s+$', ''))
end

local function parseSemver(v)
    v = trim(v or ''):gsub('^[vV]', '')
    local a, b, c = v:match('^(%d+)%.(%d+)%.(%d+)')
    if not a then
        a, b = v:match('^(%d+)%.(%d+)$')
        c = 0
    end
    if not a then
        a = v:match('^(%d+)$')
        b, c = 0, 0
    end
    if not a then return nil end
    return { tonumber(a) or 0, tonumber(b) or 0, tonumber(c) or 0, raw = v }
end

local function cmpSemver(a, b)
    if not a or not b then return 0 end
    for i = 1, 3 do
        if a[i] ~= b[i] then
            if a[i] < b[i] then return -1 end
            return 1
        end
    end
    return 0
end

local function extractVersionFromTag(tag, resource)
    if type(tag) ~= 'string' or tag == '' then return nil end
    local esc = resource:gsub('(%W)', '%%%1')
    local v = tag:match('^' .. esc .. '%-v?([%d%.]+)$')
        or tag:match('^' .. esc .. '/v?([%d%.]+)$')
    if v then return parseSemver(v) end
    return nil
end

local function githubApi(path, cb)
    PerformHttpRequest('https://api.github.com' .. path, function(status, body)
        if status ~= 200 or not body or body == '' then
            cb(nil, status)
            return
        end
        local ok, data = pcall(json.decode, body)
        if not ok then
            cb(nil, status)
            return
        end
        cb(data, status)
    end, 'GET', '', {
        ['User-Agent'] = 'fivex_versioncheck',
        ['Accept'] = 'application/vnd.github+json',
    })
end

local function makeObj(resource, repo, localVersion)
    local interval = DEFAULT_INTERVAL_MS
    local running = true
    local generation = 0

    local obj = {}

    function obj.check()
        if type(repo) ~= 'string' or not repo:find('/') then
            print(('[fivex_versioncheck] %s: invalid repository %s'):format(resource, tostring(repo)))
            return
        end
        local owner, name = repo:match('^([^/]+)/([^/]+)$')
        if not owner then return end

        githubApi(('/repos/%s/%s/releases?per_page=40'):format(owner, name), function(releases, status)
            local localSv = parseSemver(localVersion)
            local best, bestTag, bestUrl = nil, nil, nil

            if type(releases) == 'table' then
                for i = 1, #releases do
                    local rel = releases[i]
                    if type(rel) == 'table' and not rel.draft then
                        local tag = rel.tag_name or ''
                        local sv = extractVersionFromTag(tag, resource)
                        if sv and (not best or cmpSemver(sv, best) > 0) then
                            best, bestTag = sv, tag
                            bestUrl = rel.html_url
                                or (('https://github.com/%s/%s/releases/tag/%s'):format(owner, name, tag))
                        end
                    end
                end
            elseif status and status ~= 200 then
                print(('[fivex_versioncheck] %s: GitHub HTTP %s'):format(resource, tostring(status)))
            end

            local hasNew = false
            local last = localVersion
            if best and localSv and cmpSemver(best, localSv) > 0 then
                hasNew = true
                last = best.raw
                print(('^3[fivex_versioncheck]^7 %s: update available ^2%s^7 → ^2%s^7  %s'):format(
                    resource, tostring(localVersion), last, tostring(bestUrl)
                ))
            end

            TriggerEvent('fivex_versioncheck:onCheck', resource, {
                has_new_version = hasNew,
                last_version = last,
                download_url = bestUrl,
                tag = bestTag,
            })
        end)
    end

    function obj.stop()
        running = false
        generation = generation + 1
    end

    function obj.start()
        running = true
        generation = generation + 1
        local gen = generation
        CreateThread(function()
            while running and gen == generation do
                Wait(interval)
                if not running or gen ~= generation then break end
                obj.check()
            end
        end)
    end

    function obj.setInterval(ms)
        ms = tonumber(ms)
        if not ms or ms < 60000 then ms = DEFAULT_INTERVAL_MS end
        interval = ms
        obj.stop()
        obj.start()
    end

    SetTimeout(2500, function()
        if running then obj.check() end
    end)
    obj.start()
    return obj
end

AddEventHandler('fivex_versioncheck:register', function(resource, repo, version, cb)
    resource = trim(resource)
    repo = trim(repo)
    version = trim(version)
    if resource == '' then
        if type(cb) == 'function' then cb({ success = false, error = 'no_resource' }) end
        return
    end
    if registered[resource] then
        if type(cb) == 'function' then cb({ success = true, obj = registered[resource], already = true }) end
        return
    end
    local obj = makeObj(resource, repo ~= '' and repo or 'Rick007110/fivex-scripts', version ~= '' and version or '0.0.0')
    registered[resource] = obj
    print(('[fivex_versioncheck] registered %s @ %s (repo %s)'):format(resource, version, repo))
    if type(cb) == 'function' then cb({ success = true, obj = obj }) end
end)

print('^2[fivex_versioncheck]^7 ready — tag releases as {resource}-v{semver}')
