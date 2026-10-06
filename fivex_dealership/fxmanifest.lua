fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'fivex_dealership'
author 'FiveX'
version '1.0.0'
repository 'Rick007110/fivex-scripts'
description 'Standalone vehicle dealership and garages — buy, store, recover, sell back'

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
    'data/vehicles.lua',
    'shared/catalog.lua',
    'locales/en.lua',
}

client_scripts {
    'client/main.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/versioncheck.lua',
    'server/db.lua',
    'server/main.lua',
}

dependency 'fivex_jobcenter'
dependency 'fivex_bank'
dependency 'oxmysql'
dependency 'fivex_versioncheck'
