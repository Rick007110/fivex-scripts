fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'fivex_zombies'
author 'FiveX'
version '1.0.6'
repository 'Rick007110/fivex-scripts'
description 'Staff-triggered zombie apocalypse for vanilla CFX (no framework)'

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/app.js',
    'html/audio/alarm.ogg',
    'html/**',
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
