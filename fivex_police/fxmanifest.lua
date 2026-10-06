fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'fivex_police'
author 'FiveX'
version '1.0.0'
repository 'Rick007110/fivex-scripts'
description 'Realistic AI police: tuned cops, perimeter behaviour, scripted SWAT squads that clear buildings'

shared_script 'config.lua'

client_scripts {
    'client/common.lua',
    'client/police.lua',
    'client/swat.lua',
    'client/arrest.lua',
}

server_scripts {
    'server/versioncheck.lua',
    'server/main.lua',
}

dependency 'fivex_versioncheck'
