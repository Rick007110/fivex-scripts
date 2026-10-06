fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'fivex_bank'
author 'FiveX'
version '1.0.0'
repository 'Rick007110/fivex-scripts'
description 'Standalone bank — accounts, branches, ATMs, transfers, history'

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

dependency 'oxmysql'
dependency 'fivex_jobcenter'
dependency 'fivex_versioncheck'
