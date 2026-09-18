fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'fivex_flexa'
version '1.2.1'
repository 'Rick007110/fivex-scripts'
description 'Flexa — foldable phone by Whiz Mobile (standalone)'
author 'FiveX'

ui_page 'html/index.html'

files {
    'html/**',
    'gallery/**',
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
