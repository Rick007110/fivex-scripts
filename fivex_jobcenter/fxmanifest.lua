fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'fivex_jobcenter'
author 'FiveX'
version '1.0.1'
repository 'Rick007110/fivex-scripts'
description 'Standalone job board — apply, pay wallet, duty state'

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
    'server/versioncheck.lua',
    'server/main.lua',
}

dependency 'fivex_versioncheck'
