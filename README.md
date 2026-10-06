# FiveX Scripts

Public monorepo for FiveX FiveM resources.

**Layout:** one folder per resource on `main` (not branch-per-script).  
**Versioning:** [`fivex_versioncheck`](./fivex_versioncheck) — GitHub Releases with tags `{resource}-v{semver}` (Eschiclers `version_control` does not support multiple scripts in one repo).

## Resources

- `fivex_admin/`
- `fivex_appearance/`
- `fivex_bank/`
- `fivex_coroner/`
- `fivex_dealership/`
- `fivex_drone/`
- `fivex_flexa/`
- `fivex_gangwars/`
- `fivex_highrise/`
- `fivex_jobcenter/`
- `fivex_knoway/`
- `fivex_marina/`
- `fivex_police/`
- `fivex_rollover/`
- `fivex_spawn/`
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

Releases are automatic. On every push to `main`, [`.github/workflows/release.yml`](./.github/workflows/release.yml):

1. finds the resource folders that changed in the push;
2. reads `version` from each folder's `fxmanifest.lua` — if that version was already released, it bumps the
   patch number and commits the new `fxmanifest.lua` (`[skip ci]`);
3. publishes a GitHub **Release** tagged `{resource}-v{version}` (e.g. `fivex_flexa-v4.1.1`) with
   `{resource}-v{version}.zip` attached (the resource folder, ready to unzip into `resources/`).

Bump `version` yourself for a minor / major release. To re-release specific folders, run the workflow by hand
(Actions → *Release changed resources* → *Run workflow*, optionally listing folders).

Servers running `fivex_versioncheck` print an update notice when a newer tag exists for that resource.

## License / authorship

FiveX — Rick007110
