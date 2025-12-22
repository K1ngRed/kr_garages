-- client/garage_markers.lua

-- Esperar a que FrameworkBridge esté disponible
while not FrameworkBridge do
    Wait(100)
end
-- Maneja blips y markers de garajes privados

local GARAGE_SPRITES = {
    car = 50,
    air = 359,
    boat = 427,
    house = 40,
    apartment = 475,
    misc = 478
}

local GARAGE_TEXT = {
    car = "Garage",
    air = "Hangar",
    boat = "Marina",
    house = "Garage",
    apartment = "Garage",
    misc = "Garage"
}

-- Markers flotantes por tipo de garaje
local GARAGE_MARKERS = {
    car = { sprite = 36, color = {66, 182, 245, 200}, scale = 0.9 },    -- Marker de coche (azul privado)
    air = { sprite = 34, color = {66, 182, 245, 200}, scale = 1.1 },    -- Marker de flecha hacia arriba
    boat = { sprite = 1, color = {66, 182, 245, 200}, scale = 1.0 },    -- Marker cilindro
}

-- Sonido de interacción
local function PlayInteractionSound()
    PlaySoundFrontend(-1, "SELECT", "HUD_FRONTEND_DEFAULT_SOUNDSET", true)
end

-- Sonido al entrar en zona
local function PlayEnterZoneSound()
    PlaySoundFrontend(-1, "NAV_UP_DOWN", "HUD_FRONTEND_DEFAULT_SOUNDSET", true)
end

-- Track de zonas para no repetir sonido
local playerInPrivateZone = {}

local PrivateGarages = {}
local PrivateGarageBlips = {}
local UpdatingGarages = {}

-- ============================================
-- UTILITY FUNCTIONS
-- ============================================

local function spriteForType(t)
    return GARAGE_SPRITES[t] or GARAGE_SPRITES.car
end

local function labelForType(t)
    return GARAGE_TEXT[t] or GARAGE_TEXT.car
end

local function markerForType(t)
    return GARAGE_MARKERS[t] or GARAGE_MARKERS.car
end

local function DrawInteractionText(garageName, action, garageType)
    local actionText = ""
    
    if action == "store" then
        actionText = "Guardar en "
    else
        actionText = "Abrir "
    end
    
    local restText = actionText .. garageName
    local fullText = "[E] " .. restText
    
    -- Fuente 0 = Chalet London (más redondeada)
    local fontId = 0
    local textScale = 0.28
    
    -- Calcular ancho real del texto usando nativas
    SetTextFont(fontId)
    SetTextScale(0.0, textScale)
    BeginTextCommandGetWidth("STRING")
    AddTextComponentSubstringPlayerName(fullText)
    local textWidth = EndTextCommandGetWidth(true)
    
    -- Calcular ancho de [E] para posicionar el resto
    SetTextFont(fontId)
    SetTextScale(0.0, textScale)
    BeginTextCommandGetWidth("STRING")
    AddTextComponentSubstringPlayerName("[E] ")
    local eWidth = EndTextCommandGetWidth(true)
    
    -- Padding mínimo e igual arriba/abajo
    local paddingH = 0.003
    local paddingV = 0.003
    local containerWidth = textWidth + (paddingH * 2)
    local textHeight = 0.016
    local containerHeight = textHeight + (paddingV * 2)
    
    local containerX = 0.008 + (containerWidth / 2)
    local containerY = 0.030
    local textStartX = 0.008 + paddingH
    local textY = containerY - (textHeight / 2) - 0.001
    
    -- Fondo del contenedor
    DrawRect(containerX, containerY, containerWidth, containerHeight, 0, 0, 0, 180)
    
    -- Dibujar [E] en azul
    SetTextFont(fontId)
    SetTextProportional(true)
    SetTextScale(0.0, textScale)
    SetTextColour(66, 182, 245, 255)
    SetTextDropshadow(1, 0, 0, 0, 255)
    SetTextJustification(1)
    BeginTextCommandDisplayText("STRING")
    AddTextComponentSubstringPlayerName("[E]")
    EndTextCommandDisplayText(textStartX, textY)
    
    -- Dibujar resto del texto en blanco
    SetTextFont(fontId)
    SetTextProportional(true)
    SetTextScale(0.0, textScale)
    SetTextColour(255, 255, 255, 255)
    SetTextDropshadow(1, 0, 0, 0, 200)
    SetTextJustification(1)
    BeginTextCommandDisplayText("STRING")
    AddTextComponentSubstringPlayerName(" " .. restText)
    EndTextCommandDisplayText(textStartX + eWidth - 0.003, textY)
end

local function ensureVector3(x, y, z)
    if type(x) == "vector3" then
        return x
    end
    
    if type(x) == "table" and x.x then
        return vector3(x.x, x.y, x.z)
    end
    
    return vector3(x or 0.0, y or 0.0, z or 0.0)
end

-- ============================================
-- BLIP MANAGEMENT (PROXIMIDAD)
-- ============================================

local PROXIMITY_DISTANCE = 100.0 -- Distancia para mostrar blip

local function createBlip(g)
    if not g or not g.coords then return end
    
    -- Remover blip existente
    if PrivateGarageBlips[g.id] and DoesBlipExist(PrivateGarageBlips[g.id]) then
        RemoveBlip(PrivateGarageBlips[g.id])
    end
    
    -- Crear nuevo blip
    local blip = AddBlipForCoord(g.coords.x, g.coords.y, g.coords.z)
    SetBlipSprite(blip, spriteForType(g.type))
    SetBlipColour(blip, 3)
    SetBlipScale(blip, 0.7)
    SetBlipAsShortRange(blip, true)
    SetBlipDisplay(blip, 6)
    
    -- Inicialmente oculto
    SetBlipAlpha(blip, 0)
    
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString(g.name or labelForType(g.type))
    EndTextCommandSetBlipName(blip)
    
    PrivateGarageBlips[g.id] = blip
end

local function removeBlip(id)
    local blip = PrivateGarageBlips[id]
    if blip and DoesBlipExist(blip) then
        RemoveBlip(blip)
    end
    PrivateGarageBlips[id] = nil
end

local function updateBlipVisibility()
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)
    
    for id, garage in pairs(PrivateGarages) do
        local blip = PrivateGarageBlips[id]
        if blip and DoesBlipExist(blip) then
            local distance = #(playerCoords - garage.coords)
            
            if distance <= PROXIMITY_DISTANCE then
                -- Fade in del blip
                SetBlipAlpha(blip, 255)
            else
                -- Fade out del blip
                SetBlipAlpha(blip, 0)
            end
        end
    end
end

-- ============================================
-- GARAGE INTERACTION
-- ============================================

local function openGarageNUI(entry)
    if not entry then return end
    
    -- Para garajes privados, siempre usar los datos del cache que se actualizan automáticamente
    local garageData = entry
    if entry.id and PrivateGarages[entry.id] then
        garageData = PrivateGarages[entry.id]
    end
    
    -- Obtener posición del jugador (para calcular distancia a vehículos)
    local playerCoords = GetEntityCoords(PlayerPedId())
    
    -- Verificar qué vehículos existen en el mundo ANTES de abrir el garaje
    local worldVehicles = GetGamePool('CVehicle')
    local nearbyPlates = {}      -- Vehículos cerca del jugador (< 150m) = "Ya está fuera"
    local allPlatesInWorld = {}  -- Todos los vehículos detectados en el mundo
    local vehicleStates = {}     -- Estado del vehículo (engine, body, fuel)
    
    local MAX_NEARBY_DISTANCE = 150.0
    
    for _, veh in ipairs(worldVehicles) do
        if DoesEntityExist(veh) then
            local plate = GetVehicleNumberPlateText(veh)
            if plate then
                plate = plate:gsub('%s+', ' '):match('^%s*(.-)%s*$')
                table.insert(allPlatesInWorld, plate)
                
                -- Calcular distancia al jugador
                local vehCoords = GetEntityCoords(veh)
                local distanceToPlayer = #(vehCoords - playerCoords)
                
                if distanceToPlayer <= MAX_NEARBY_DISTANCE then
                    table.insert(nearbyPlates, plate)
                end
                
                -- Obtener estado del vehículo
                vehicleStates[plate] = {
                    engine = GetVehicleEngineHealth(veh),
                    body = GetVehicleBodyHealth(veh),
                    fuel = GetVehicleFuelLevel(veh) or 100
                }
            end
        end
    end
    
    -- Enviar lista de placas cercanas, todas las placas y estados al servidor
    TriggerServerEvent('kr_garages:server:CheckAllVehiclesStatus', garageData.id, nearbyPlates, allPlatesInWorld, vehicleStates)
    
    -- Esperar brevemente para que el servidor procese y luego obtener vehículos
    Citizen.SetTimeout(100, function()
        FrameworkBridge.TriggerCallback('kr_garages:server:GetVehicles', function(vehicles)
        -- Si no hay vehículos Y es un garaje privado, puede estar eliminado
        if not vehicles or (#vehicles == 0 and garageData.id) then
            -- Verificar si el garaje aún existe
            FrameworkBridge.TriggerCallback('kr_garages:server:GetPrivateGarages', function(garages)
                local exists = false
                for _, g in ipairs(garages or {}) do
                    if g.id == garageData.id then
                        exists = true
                        break
                    end
                end
                
                if not exists then
                    FrameworkBridge.ShowNotification('~r~Este garaje ya no existe')
                    -- Remover del cache local
                    PrivateGarages[garageData.id] = nil
                    removeBlip(garageData.id)
                    return
                end
                
                -- Garaje existe pero no tiene vehículos
                local garage = {
                    id = garageData.id,
                    name = garageData.name,
                    type = garageData.type,
                    garageType = 'private',
                    isOwner = garageData.isOwner,
                    canEdit = garageData.canEdit,
                    spawnPoints = garageData.spawnPoints or {{x = garageData.coords.x, y = garageData.coords.y, z = garageData.coords.z, w = garageData.heading or 0.0}}
                }
                
                -- Actualizar currentGarage global
                exports.kr_garages:UpdateCurrentGarage(garage)
                
                SendNUIMessage({
                    action = 'openGarage',
                    garage = garage,
                    vehicles = vehicles,
                    locale = Config.Locale or 'es'
                })
                SetNuiFocus(true, true)
            end)
        else
            -- Tiene vehículos o es garaje público
            local garage = {
                id = garageData.id,
                name = garageData.name,
                type = garageData.type,
                garageType = 'private',
                isOwner = garageData.isOwner,
                canEdit = garageData.canEdit,
                spawnPoints = garageData.spawnPoints or {{x = garageData.coords.x, y = garageData.coords.y, z = garageData.coords.z, w = garageData.heading or 0.0}}
            }
            
            -- Actualizar currentGarage global
            exports.kr_garages:UpdateCurrentGarage(garage)
            
            SendNUIMessage({
                action = 'openGarage',
                garage = garage,
                vehicles = vehicles,
                locale = Config.Locale or 'es'
            })
            SetNuiFocus(true, true)
        end
    end, garageData.id)
    end) -- Cerrar Citizen.SetTimeout
end

-- ============================================
-- LOAD PRIVATE GARAGES
-- ============================================

local function loadPrivateGarages()
    FrameworkBridge.TriggerCallback('kr_garages:server:GetPrivateGarages', function(garages)
        -- Limpiar garajes anteriores
        for id, _ in pairs(PrivateGarages) do
            removeBlip(id)
        end
        PrivateGarages = {}
        
        if type(garages) ~= "table" then
            garages = {}
        end
        
        -- Procesar cada garaje
        for idx, g in ipairs(garages) do
            local coords = ensureVector3(
                g.spawn_x or g.x or (g.coords and g.coords.x),
                g.spawn_y or g.y or (g.coords and g.coords.y),
                g.spawn_z or g.z or (g.coords and g.coords.z)
            )
            local heading = g.spawn_h or g.heading or g.h or 0.0
            
            local entry = {
                id = g.id or g.ID or g._id or (idx + 1000),
                name = g.name or g.garage or "Private Garage",
                type = g.type or g.category or "car",
                coords = coords,
                heading = heading,
                radius = g.radius or 5.0,
                isOwner = g.isOwner,
                spawnPoints = {{x = coords.x, y = coords.y, z = coords.z, w = heading}}
            }
            
            PrivateGarages[entry.id] = entry
            createBlip(entry)
        end
    end)
end

-- ============================================
-- PROXIMITY THREAD
-- ============================================

local MAX_INTERACTION_HEIGHT = 2.5 -- ~altura de un ped

CreateThread(function()
    local ped, pcoords
    while true do
        ped = PlayerPedId()
        pcoords = GetEntityCoords(ped)
        local sleep = 1000
        
        -- Actualizar visibilidad de blips por proximidad
        updateBlipVisibility()
        
        for id, g in pairs(PrivateGarages) do
            -- Ignorar garajes que están siendo actualizados
            if g.coords and not UpdatingGarages[id] then
                local dist2D = #(vector2(pcoords.x, pcoords.y) - vector2(g.coords.x, g.coords.y))
                local heightDiff = math.abs(pcoords.z - g.coords.z)
                local garageRadius = g.radius or 5.0
                local markerViewDist = garageRadius + 20.0
                
                if dist2D < markerViewDist then
                    sleep = 0
                    
                    -- Obtener configuración del marker según tipo de garaje
                    local garageType = g.type or 'car'
                    local markerConfig = markerForType(garageType)
                    
                    -- Dibujar marker flotante según tipo (a altura de cintura)
                    if dist2D < markerViewDist - 5.0 then
                        DrawMarker(markerConfig.sprite, 
                            g.coords.x, g.coords.y, g.coords.z + 0.5, 
                            180.0, 0.0, 0.0, 0.0, 0.0, 0.0, 
                            markerConfig.scale, markerConfig.scale, markerConfig.scale, 
                            markerConfig.color[1], markerConfig.color[2], markerConfig.color[3], markerConfig.color[4], 
                            true, true, 2, true, nil, nil, false)
                    end
                    
                    if dist2D < garageRadius + 1.0 and heightDiff < MAX_INTERACTION_HEIGHT then
                        -- Sonido al entrar en zona de interacción
                        if not playerInPrivateZone[id] then
                            playerInPrivateZone[id] = true
                            PlayEnterZoneSound()
                        end
                        
                        -- Obtener datos frescos del cache para el mensaje
                        local fresh = PrivateGarages[id]
                        if fresh and not UpdatingGarages[id] then
                            local vehicle = GetVehiclePedIsIn(ped, false)
                            local isInVehicle = vehicle ~= 0 and GetPedInVehicleSeat(vehicle, -1) == ped
                            
                            if isInVehicle then
                                DrawInteractionText(fresh.name or labelForType(fresh.type), "store", garageType)
                                
                                if IsControlJustPressed(0, 38) then -- E
                                    PlayInteractionSound()
                                    -- Llamar a StoreVehicle del main.lua con el garaje actual
                                    exports.kr_garages:StoreVehicleInPrivateGarage(fresh)
                                end
                            else
                                DrawInteractionText(fresh.name or labelForType(fresh.type), "open", garageType)
                                
                                if IsControlJustPressed(0, 38) then -- E
                                    PlayInteractionSound()
                                    -- Pasar el ID para que openGarageNUI busque en el cache
                                    openGarageNUI(PrivateGarages[id])
                                end
                            end
                        end
                    else
                        -- Fuera de zona, resetear tracking
                        playerInPrivateZone[id] = nil
                    end
                else
                    playerInPrivateZone[id] = nil
                end
            end
        end
        
        Wait(sleep)
    end
end)

-- ============================================
-- PUBLIC GARAGES BLIPS MANAGEMENT
-- ============================================

local PublicGarageBlips = {}
local isRefreshing = false -- Prevenir refreshes simultáneos

local function CreatePublicGarageBlips()
    -- Prevenir llamadas simultáneas
    if isRefreshing then return end
    isRefreshing = true
    
    -- Solicitar garajes públicos al servidor (el servidor usa cache)
    FrameworkBridge.TriggerCallback('kr_garages:server:GetPublicGaragesForClient', function(garages)
        if not garages then 
            isRefreshing = false
            return 
        end
        
        -- Eliminar blips antiguos de forma eficiente
        for id, blip in pairs(PublicGarageBlips) do
            if DoesBlipExist(blip) then
                RemoveBlip(blip)
            end
        end
        PublicGarageBlips = {}
        
        -- Actualizar Config.Garages con los datos del servidor
        local newGarages = {}
        local numGarages = #garages
        
        for i = 1, numGarages do
            local garage = garages[i]
            
            -- Parsear spawn points de forma optimizada
            local spawnPoints = {}
            local gSpawnPoints = garage.spawnPoints
            if gSpawnPoints then
                for j = 1, #gSpawnPoints do
                    local sp = gSpawnPoints[j]
                    spawnPoints[j] = vector4(sp.x or 0, sp.y or 0, sp.z or 0, sp.heading or 0)
                end
            end
            
            -- Obtener valores de blip una sola vez
            local gBlip = garage.blip
            local sprite = gBlip and gBlip.sprite or 357
            local color = gBlip and gBlip.color or 47
            local scale = gBlip and gBlip.scale or 0.6
            
            -- Crear coords una sola vez
            local gCoords = garage.coords
            local coordX = gCoords and gCoords.x or 0
            local coordY = gCoords and gCoords.y or 0
            local coordZ = gCoords and gCoords.z or 0
            
            -- Agregar a nueva tabla de garajes
            newGarages[i] = {
                id = garage.id,
                name = garage.name,
                type = garage.type or 'car',
                garageType = 'public',
                coords = vector3(coordX, coordY, coordZ),
                radius = garage.radius or 15.0,
                spawnPoints = spawnPoints,
                blip = {sprite = sprite, color = color, scale = scale}
            }
            
            -- Crear blip optimizado
            local blip = AddBlipForCoord(coordX, coordY, coordZ)
            SetBlipSprite(blip, sprite)
            SetBlipDisplay(blip, 4)
            SetBlipScale(blip, scale)
            SetBlipColour(blip, color)
            SetBlipAsShortRange(blip, true)
            BeginTextCommandSetBlipName("STRING")
            AddTextComponentString(garage.name or "Garaje")
            EndTextCommandSetBlipName(blip)
            
            PublicGarageBlips[garage.id] = blip
        end
        
        -- Reemplazar Config.Garages de una sola vez (más eficiente)
        Config.Garages = newGarages
        
        -- Marcar que los garajes públicos están cargados
        PublicGaragesLoaded = true
        isRefreshing = false
    end)
end

-- Función para eliminar un blip de garaje público específico
local function RemovePublicGarageBlip(garageId)
    if PublicGarageBlips[garageId] then
        if DoesBlipExist(PublicGarageBlips[garageId]) then
            RemoveBlip(PublicGarageBlips[garageId])
        end
        PublicGarageBlips[garageId] = nil
        
        -- También eliminar de Config.Garages
        if Config and Config.Garages then
            for i, garage in ipairs(Config.Garages) do
                if garage.id == garageId then
                    table.remove(Config.Garages, i)
                    break
                end
            end
        end
    end
end

-- ============================================
-- EVENTS
-- ============================================

-- Cargar al iniciar (optimizado - reducidos waits)
AddEventHandler('onClientResourceStart', function(res)
    if res == GetCurrentResourceName() then
        Wait(300) -- Reducido de 500ms
        loadPrivateGarages()
        CreatePublicGarageBlips() -- Sin wait adicional - el servidor usa cache
    end
end)

-- Cargar cuando el jugador spawnea
RegisterNetEvent('esx:playerLoaded', function(_)
    Wait(300) -- Reducido de 500ms
    loadPrivateGarages()
    CreatePublicGarageBlips() -- Sin wait adicional
end)

-- Recargar garajes privados cuando el servidor lo solicita
RegisterNetEvent('kr_garages:client:ReloadPrivateGarages', function()
    loadPrivateGarages()
end)

-- Garaje privado creado
RegisterNetEvent('kr_garages:client:PrivateGarageCreated', function(data)
    if not data then return end
    
    local coords = ensureVector3(
        data.x or (data.coords and data.coords.x),
        data.y or (data.coords and data.coords.y),
        data.z or (data.coords and data.coords.z)
    )
    local heading = data.heading or 0.0
    
    local entry = {
        id = data.id or math.random(100000, 999999),
        name = data.name or "Private Garage",
        type = data.type or "car",
        coords = coords,
        heading = heading,
        radius = data.radius or 5.0,
        spawnPoints = {{x = coords.x, y = coords.y, z = coords.z, w = heading}}
    }
    
    PrivateGarages[entry.id] = entry
    createBlip(entry)
end)

-- Garaje privado actualizado
RegisterNetEvent('kr_garages:client:PrivateGarageUpdated', function(data)
    if not data or not data.id then return end
    
    UpdatingGarages[data.id] = true
    removeBlip(data.id)
    PrivateGarages[data.id] = nil
    
    Citizen.Wait(100)
    
    UpdatingGarages[data.id] = nil
    loadPrivateGarages()
    
    FrameworkBridge.ShowNotification('~g~Garaje actualizado correctamente')
end)

-- Garaje privado eliminado
RegisterNetEvent('kr_garages:client:PrivateGarageDeleted', function(garageId)
    if not garageId then return end
    
    -- Convertir a número para asegurar consistencia
    local gid = tonumber(garageId)
    if not gid then return end
    
    -- Remover del cache
    PrivateGarages[gid] = nil
    
    -- Remover blip
    removeBlip(gid)
    
    -- Notificación opcional (comentar si no quieres)
    -- FrameworkBridge.ShowNotification('~r~Garaje privado eliminado')
end)

-- Evento para refrescar blips de garajes públicos (llamado desde el servidor)
RegisterNetEvent('kr_garages:client:RefreshGarageBlips')
AddEventHandler('kr_garages:client:RefreshGarageBlips', function()
    CreatePublicGarageBlips()
end)

-- Evento para eliminar un garaje público específico
RegisterNetEvent('kr_garages:client:PublicGarageDeleted')
AddEventHandler('kr_garages:client:PublicGarageDeleted', function(garageId)
    RemovePublicGarageBlip(garageId)
end)

-- ============================================
-- EXPORTS
-- ============================================

exports('GetPrivateGarages', function()
    return PrivateGarages
end)

exports('RefreshPrivateGarages', loadPrivateGarages)
exports('RefreshPublicGarageBlips', CreatePublicGarageBlips)
