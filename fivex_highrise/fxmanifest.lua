fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'fivex_highrise'
author 'FiveX'
version '1.0.2'
repository 'Rick007110/fivex-scripts'
description 'Standalone high-rise window washer — roofs, bays, service lifts'

dependency 'fivex_jobcenter'
dependency 'fivex_versioncheck'

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
