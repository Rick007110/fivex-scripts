fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'fivex_appearance'
author 'FiveX'
version '1.0.3'
repository 'Rick007110/fivex-scripts'
description 'Standalone character creator and clothing / barber / tattoo shops'

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
    'data/defaults.lua',
    'data/tattoos.lua',
}

client_scripts {
    'client/appearance.lua',
    'client/camera.lua',
    'client/main.lua',
}

server_scripts {
    'server/versioncheck.lua',
    'server/main.lua',
}

dependency 'fivex_versioncheck'
