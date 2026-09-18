# FiveX Scripts

Public monorepo for FiveX FiveM resources.

**Layout:** one folder per resource on `main` (not branch-per-script).  
**Versioning:** [`fivex_versioncheck`](./fivex_versioncheck) — GitHub Releases with tags `{resource}-v{semver}` (Eschiclers `version_control` does not support multiple scripts in one repo).

## Resources

- `fivex_admin/`
- `fivex_appearance/`
- `fivex_coroner/`
- `fivex_flexa/`
- `fivex_gangwars/`
- `fivex_highrise/`
- `fivex_jobcenter/`
- `fivex_marina/`
- `fivex_rollover/`
- `fivex_staffvest/`
- `fivex_versioncheck/`
- `fivex_zombies/`

## Install

1. Copy the resource folders you need into your server `resources` tree (e.g. `resources/[fivex]/`).
2. In `server.cfg`, start the checker **first**:

```cfg
ensure fivex_versioncheck
ensure fivex_jobcenter
ensure fivex_flexa
# …other fivex_* …
```

3. Restore any omitted binaries (see [OMITTED_ASSETS.md](./OMITTED_ASSETS.md)) from your live server if required.

## Shipping a new version

1. Bump `version` in that resource’s `fxmanifest.lua`.
2. Merge to `main`.
3. Create a GitHub **Release** with tag exactly:

```text
fivex_flexa-v1.2.2
```

Servers running `fivex_versioncheck` will print an update notice when a newer tag exists for that resource.

## License / authorship

FiveX / 112 Play Theory — Rick V. Rijsewijk.
