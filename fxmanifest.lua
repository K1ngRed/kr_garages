fx_version 'cerulean'

game 'gta5'
lua54 'yes'

author 'KING RED'
description 'Sistema de Garajes Avanzado - ESX/QBCore Compatible'
version '4.0.0'

shared_scripts {
    'config.lua',
    'framework/init.lua',
    'shared/vehicle_data.lua' -- NECESARIO: Contiene el mapeo hash -> nombre del vehículo
}

client_scripts {
    'framework/client.lua',
    -- Core y utilidades (deben cargarse primero)
    'client/core.lua',
    'client/utils.lua',
    -- Funcionalidad de garajes
    'client/spawn.lua',
    'client/store.lua',
    'client/garage_menu.lua',
    'client/markers_thread.lua',
    'client/tracking.lua',
    'client/impound.lua',
    'client/init_garages.lua',
    -- Garajes privados y NUI
    'client/garage_markers.lua',
    'client/nui_callbacks.lua',
    'client/commands.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'framework/server.lua',
    -- Core y utilidades (deben cargarse primero)
    'server/core.lua',
    'server/vehicle_utils.lua',
    'server/garage_cache.lua',
    -- Funcionalidad principal
    'server/callbacks.lua',
    'server/vehicles.lua',
    'server/transfer.lua',
    'server/repair.lua',
    'server/tracking.lua',
    -- Administración
    'server/admin.lua',
    'server/admin_commands.lua',
    'server/impound.lua',
    'server/garages_crud.lua'
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/script.js',
    'html/locales/*.json',
    'html/images/*.png'
}