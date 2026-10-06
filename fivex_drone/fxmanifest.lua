fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'fivex_drone'
author 'FiveX'
version '1.0.0'
repository 'Rick007110/fivex-scripts'
description 'FPV racing / freestyle drone — acro physics, goggles OSD, synced for everyone with live motor sound'

-- goggles OSD + WebAudio motor synth (never takes focus)
ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/app.js',
    'README.md',
}

shared_scripts {
    'config.lua',
    'locales/en.lua',
}

client_scripts {
    'client/math.lua',
    'client/flight.lua',
    'client/main.lua',
}

server_scripts {
    'server/versioncheck.lua',
    'server/main.lua',
}
