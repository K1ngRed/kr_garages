-- client/init_garages.lua
-- Inicialización de garajes públicos desde la base de datos

-- Esperar a que FrameworkBridge esté disponible
while not FrameworkBridge do
    Wait(100)
end

-- ============================================
-- LOAD PUBLIC GARAGES FROM SERVER
-- ============================================

local function LoadPublicGaragesFromServer()
    FrameworkBridge.TriggerCallback('kr_garages:server:GetPublicGaragesForClient', function(garages)
        if not garages then 
            print('[kr_garages] ^1Error: No se pudieron cargar garajes públicos^7')
            return 
        end
        
        -- Limpiar Config.Garages existente
        Config.Garages = {}
        
        -- Agregar los garajes recibidos del servidor
        for _, garage in ipairs(garages) do
            local spawnPoints = {}
            if garage.spawnPoints then
                for _, sp in ipairs(garage.spawnPoints) do
                    table.insert(spawnPoints, vector4(
                        sp.x or 0, 
                        sp.y or 0, 
                        sp.z or 0, 
                        sp.heading or 0
                    ))
                end
            end
            
            table.insert(Config.Garages, {
                id = garage.id,
                name = garage.name,
                type = garage.type or 'car',
                garageType = 'public',
                coords = vector3(
                    garage.coords.x or 0, 
                    garage.coords.y or 0, 
                    garage.coords.z or 0
                ),
                radius = garage.radius or 15.0,
                spawnPoints = spawnPoints,
                blip = garage.blip or {sprite = 357, color = 47, scale = 0.6}
            })
        end
        
        PublicGaragesLoaded = true
        
        -- Crear blips después de cargar
        CreateGarageBlips()
    end)
end

-- ============================================
-- INITIALIZATION THREAD
-- ============================================

CreateThread(function()
    -- Esperar a que el jugador esté completamente cargado
    while not FrameworkBridge.GetPlayerData() do
        Wait(500)
        if resourceStopping then return end
    end
    
    -- Esperar un poco más para asegurar que todo esté listo
    Wait(2000)
    if resourceStopping then return end
    
    -- Cargar garajes públicos desde el servidor (base de datos)
    LoadPublicGaragesFromServer()
end)

-- NOTA: El evento 'kr_garages:client:RefreshGarageBlips' está manejado en garage_markers.lua
-- para evitar duplicados y conflictos
