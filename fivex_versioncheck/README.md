# fivex_versioncheck

Version checker for the **fivex-scripts** monorepo. Unlike Eschiclers `version_control`, this supports **many resources in one GitHub repo** by matching **per-script release tags**.

## Install

Ensure this resource **before** other FiveX resources:

```
ensure fivex_versioncheck
ensure fivex_flexa
# …
```

## Release tags

Create a GitHub Release on `Rick007110/fivex-scripts` with tag:

```
{resourceName}-v{semver}
```

Examples: `fivex_flexa-v1.2.1`, `fivex_zombies-v1.0.7`

Bump `version` in that resource’s `fxmanifest.lua` to match, then publish the release.

## Register API (server)

```lua
TriggerEvent('fivex_versioncheck:register',
  GetCurrentResourceName(),
  GetResourceMetadata(GetCurrentResourceName(), 'repository', 0),
  GetResourceMetadata(GetCurrentResourceName(), 'version', 0),
  function(response)
    if response.success then
      -- response.obj:stop() / :start() / :check() / :setInterval(ms)
    end
  end
)
```

## onCheck

```lua
AddEventHandler('fivex_versioncheck:onCheck', function(resourceName, data)
  -- data.has_new_version, data.last_version, data.download_url
end)
```
