-- server/garage_cache.lua
-- Cache de garajes públicos

-- ============================================
-- CACHE DE GARAJES PÚBLICOS
-- ============================================

PublicGaragesCache = {}
PublicGaragesCacheValid = false

-- Función para obtener garajes del cache o BD
function GetPublicGaragesFromCache(callback)
    if PublicGaragesCacheValid and #PublicGaragesCache > 0 then
        callback(PublicGaragesCache)
        return
    end
    
    MySQL.query('SELECT * FROM public_garages', {}, function(results)
        if not results then 
            callback({})
            return 
        end
        
        PublicGaragesCache = {}
        for _, row in ipairs(results) do
            local spawnPoints = {}
            if row.spawn_points and row.spawn_points ~= '' then
                local success, parsed = pcall(json.decode, row.spawn_points)
                if success and parsed then
                    spawnPoints = parsed
                end
            end
            
            table.insert(PublicGaragesCache, {
                id = row.id,
                name = row.name,
                type = row.type or 'car',
                garageType = 'public',
                coords = {x = row.coord_x or 0, y = row.coord_y or 0, z = row.coord_z or 0},
                radius = row.radius or 15.0,
                spawnPoints = spawnPoints,
                blip = {
                    sprite = row.blip_sprite or 357,
                    color = row.blip_color or 47,
                    scale = row.blip_scale or 0.6
                }
            })
        end
        
        PublicGaragesCacheValid = true
        callback(PublicGaragesCache)
    end)
end

-- Función para refrescar cache y notificar a todos los clientes
function RefreshCacheAndNotifyClients()
    PublicGaragesCacheValid = false
    GetPublicGaragesFromCache(function(garages)
        TriggerClientEvent('kr_garages:client:RefreshGarageBlips', -1)
    end)
end

-- Invalidar cache
function InvalidateGarageCache()
    PublicGaragesCacheValid = false
    PublicGaragesCache = {}
end

-- ============================================
-- CARGAR GARAJES AL INICIAR
-- ============================================

CreateThread(function()
    Wait(1000)
    GetPublicGaragesFromCache(function(garages)
        if Config and Config.Garages then
            -- Limpiar garajes públicos existentes en Config
            local nonPublicGarages = {}
            for _, g in ipairs(Config.Garages) do
                if g.garageType ~= 'public' then
                    table.insert(nonPublicGarages, g)
                end
            end
            Config.Garages = nonPublicGarages
            
            -- Agregar garajes públicos desde la BD
            for _, garage in ipairs(garages) do
                local spawnPoints = {}
                if garage.spawnPoints then
                    for _, sp in ipairs(garage.spawnPoints) do
                        table.insert(spawnPoints, vector4(sp.x or 0, sp.y or 0, sp.z or 0, sp.heading or 0))
                    end
                end
                
                table.insert(Config.Garages, {
                    id = garage.id,
                    name = garage.name,
                    type = garage.type or 'car',
                    garageType = 'public',
                    coords = vector3(garage.coords.x or 0, garage.coords.y or 0, garage.coords.z or 0),
                    radius = garage.radius or 15.0,
                    spawnPoints = spawnPoints,
                    blip = garage.blip or {sprite = 357, color = 47, scale = 0.6}
                })
            end
        end
    end)
end)
