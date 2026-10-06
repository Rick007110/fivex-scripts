fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'fivex_knoway'
author 'FiveX'
version '1.0.0'
repository 'Rick007110/fivex-scripts'
description 'KnoWay — book a driverless taxi from your Flexa phone'

-- ride HUD (Go / Cancel); the phone app page runs inside Flexa
ui_page 'html/hud.html'

files {
    'html/hud.html',
    'html/hud.css',
    'html/hud.js',
    'html/app.html',
    'html/app.css',
    'html/app.js',
    'html/logo.svg',
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

dependency 'fivex_flexa'
dependency 'fivex_bank'
dependency 'fivex_jobcenter'
dependency 'fivex_versioncheck'
