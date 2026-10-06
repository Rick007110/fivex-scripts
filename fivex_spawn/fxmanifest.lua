fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'fivex_spawn'
author 'FiveX'
version '1.0.0'
repository 'Rick007110/fivex-scripts'
description 'Spawn selector on join (last location + places) and hospital respawns — replaces random spawnpoints'

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/app.js',
}

shared_script 'config.lua'

client_script 'client/main.lua'

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/versioncheck.lua',
    'server/db.lua',
    'server/main.lua',
}

dependency 'spawnmanager'
dependency 'oxmysql'
dependency 'fivex_versioncheck'
