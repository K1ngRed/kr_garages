--[[
    client/core.lua
    Variables globales y cleanup del recurso
    
    NO MODIFICAR SI NO SABES LO QUE ESTAS HACIENDO
    Contiene variables compartidas entre todos los archivos del cliente
--]]

resourceStopping = false

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    resourceStopping = true
    
    -- Limpiar blips
    if garageBlips then
        for _, blip in pairs(garageBlips) do
            if DoesBlipExist(blip) then
                RemoveBlip(blip)
            end
        end
    end
    
    -- Cerrar NUI
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'hide' })
end)

-- Esperar framework con timeout
local waitAttempts = 0
while not FrameworkBridge do
    Wait(100)
    waitAttempts = waitAttempts + 1
    if waitAttempts > 100 then
        print('[kr_garages] ^1ERROR: FrameworkBridge timeout^7')
        return
    end
end

-- Variables globales (NO MODIFICAR)
currentGarage = nil
currentVehicles = {}
garageBlips = {}
isInsideGarageArea = false
nearbyPublicGarage = nil
spawnedVehicles = {}
lastSpawnTime = 0
SPAWN_COOLDOWN = 3000

vehicleCheckCompleted = false
PublicGaragesLoaded = false

-- Sprites de markers por tipo
GARAGE_MARKERS = {
    car = { sprite = 36, color = {52, 235, 216, 200}, scale = 1.0 },
    air = { sprite = 34, color = {52, 235, 216, 200}, scale = 1.2 },
    boat = { sprite = 1, color = {52, 235, 216, 200}, scale = 1.1 },
}

MAX_INTERACTION_HEIGHT = 2.5
playerInGarageZone = {}

-- Natives cacheadas para rendimiento
Wait = Wait
PlayerPedId = PlayerPedId
GetEntityCoords = GetEntityCoords
DrawMarker = DrawMarker
IsControlJustReleased = IsControlJustReleased
DeleteVehicle = DeleteVehicle
CreateVehicle = CreateVehicle
DoesEntityExist = DoesEntityExist
SetModelAsNoLongerNeeded = SetModelAsNoLongerNeeded
SetEntityAsMissionEntity = SetEntityAsMissionEntity

-- Eventos
RegisterNetEvent('kr_garages:client:VehicleCheckComplete', function(garageId)
    vehicleCheckCompleted = true
end)

-- Evento para eliminar un vehículo por placa (broadcast desde servidor)
-- Usado cuando se recupera un vehículo abandonado desde otro garaje
RegisterNetEvent('kr_garages:client:DeleteVehicleByPlate', function(plate)
    if not plate then return end
    
    local worldVehicles = GetGamePool('CVehicle')
    for _, veh in ipairs(worldVehicles) do
        if DoesEntityExist(veh) then
            local vehPlate = GetVehicleNumberPlateText(veh)
            if vehPlate then
                vehPlate = vehPlate:gsub('%s+', ' '):match('^%s*(.-)%s*$')
                if vehPlate == plate then
                    SetEntityAsMissionEntity(veh, true, true)
                    DeleteVehicle(veh)
                    break
                end
            end
        end
    end
end)

-- Evento: verificar qué vehículos de la lista NO existen en el mundo
RegisterNetEvent('kr_garages:client:VerifyVehiclesExist', function(plates, garageId)
    if not plates or #plates == 0 then return end

    local worldVehicles = GetGamePool('CVehicle')
    local worldPlates = {}

    -- Crear tabla con placas de vehículos que SÍ existen
    for _, veh in ipairs(worldVehicles) do
        if DoesEntityExist(veh) then
            local plate = FrameworkBridge.GetPlate(veh)
            if plate then
                worldPlates[plate] = true

                -- Verificar si está destruido
                local engineHealth = GetVehicleEngineHealth(veh)
                local bodyHealth = GetVehicleBodyHealth(veh)

                if engineHealth <= 100 or bodyHealth <= 100 then
                    TriggerServerEvent('kr_garages:server:UpdateDestroyedVehicle', plate, garageId, engineHealth, bodyHealth)
                end
            end
        end
    end

    -- Identificar vehículos que NO existen en el mundo
    local missingVehicles = {}
    for _, p in ipairs(plates) do
        if not worldPlates[p] then
            table.insert(missingVehicles, p)
        end
    end

    -- Reportar vehículos faltantes al servidor para marcarlos como destruidos
    if #missingVehicles > 0 then
        TriggerServerEvent('kr_garages:server:MarkVehiclesAsDestroyed', missingVehicles)
    end
end)
