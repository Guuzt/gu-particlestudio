fx_version 'cerulean'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
game 'rdr3'

description 'gu-particlestudio — PTFX placement tool for RedM'
version '1.0.0'
author 'Betiucia Scripts'

ui_page 'nui/index.html'

files {
    'nui/index.html',
    'nui/fonts/*.ttf',
    'nui/images/*.png',
}

shared_scripts {
    'locale.lua',
    'config/*.lua',
}

client_scripts {
    'client/ptfx_assets_looped.lua',
    'client/ptfx_assets_non_looped.lua',
    'client/int.lua',
    'client/modules/nuimenu.lua',
    'client/modules/placer.lua',
    'client/modules/menu.lua',
    'client/client.lua',
}

server_scripts {
    'server/bridge.lua',
    'server/server.lua',
}

lua54 'yes'
