fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'fivex_admin'
author 'FiveX'
version '1.1.0'
repository 'Rick007110/fivex-scripts'
description 'Standalone ACE-gated staff/admin menu with a professional NUI'

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/app.js',
    'permissions.cfg.example',
    'README.md',
}

shared_scripts {
    'config.lua',
    'locales/en.lua',
    'data/vehicles.lua',
    'data/weapons.lua',
    'data/props.lua',
    'data/peds.lua',
}

client_scripts {
    'client/main.lua',
    'client/noclip.lua',
    'client/spectate.lua',
    'client/self.lua',
    'client/vehicle.lua',
    'client/weapons.lua',
    'client/overlays.lua',
    'client/entities.lua',
}

server_scripts {
    'server/versioncheck.lua',
    'server/bans.lua',
    'server/players.lua',
    'server/world.lua',
    'server/records.lua',
    'server/main.lua',
}

dependency 'fivex_versioncheck'
