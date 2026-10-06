fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'fivex_gangwars'
author 'FiveX'
version '1.0.1'
repository 'Rick007110/fivex-scripts'
description 'Flashpoint — opt-in turf wave minigame (standalone, no framework)'

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/app.js',
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
dependency 'fivex_versioncheck'

