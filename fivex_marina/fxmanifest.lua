fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'fivex_marina'
author 'FiveX'
version '2.0.0'
repository 'Rick007110/fivex-scripts'
description 'Harbor Authority — career marina job: contracts, ranks, sea rescues, charters and a dispatch tablet'

dependency 'fivex_jobcenter'
dependency 'oxmysql'
dependency 'fivex_versioncheck'

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
    'client/util.lua',
    'client/main.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/versioncheck.lua',
    'server/db.lua',
    'server/main.lua',
}
