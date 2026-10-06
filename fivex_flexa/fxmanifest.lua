fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'fivex_flexa'
version '4.1.0'
description 'Flexa — the foldable: sd-phone that unfolds to a double-width screen'
author 'FiveX'

-- the App SDK stays served for pages built against Flexa (e.g. fivex_knoway)
files {
    'html/sdk/flexa-app.js',
}

shared_script 'config.lua'
client_script 'client/main.lua'

dependency 'sd-phone'

repository 'Rick007110/fivex-scripts'
dependency 'fivex_versioncheck'
server_script 'server/versioncheck.lua'
