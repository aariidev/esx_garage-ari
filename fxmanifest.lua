fx_version 'cerulean'
game 'gta5'

author 'Ari / ESX-Framework'
description 'ari_garage - Advanced Vehicle Garage & Impound System'

version '1.16.1-ari'
legacyversion '1.16.0-ari'

repository 'https://github.com/aariidev/esx_garage-ari'

lua54 'yes'

shared_scripts {
    '@ox_lib/init.lua',
    '@es_extended/imports.lua',
}

dependencies {
    'ox_lib',
}

server_scripts {
    '@es_extended/locale.lua',
    'locales/*.lua',
    '@oxmysql/lib/MySQL.lua',
    'config.lua',
    'server/main.lua',
    'server/admin.lua',
    'server/version_check.lua'
}

client_scripts {
    '@es_extended/locale.lua',
    'locales/*.lua',
    'config.lua',
    'client/main.lua',
    'client/admin.lua'
}

ui_page 'nui/ui.html'

files {
    'nui/ui.html',
    'nui/js/*.js',
    'nui/css/*.css'
}
