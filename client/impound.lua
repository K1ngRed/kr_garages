--[[
    client/impound.lua
    Sistema de depósito vehicular (impound)
    
    NO MODIFICAR SI NO SABES LO QUE ESTAS HACIENDO
    Este archivo maneja toda la lógica de confiscación y liberación de vehículos
--]]

-- Esperar framework
while not FrameworkBridge do Wait(100) end

-- Variables locales

local currentImpound = nil
local spawnedImpoundPeds = {}

-- Placas en proceso de confiscación (evita que tracking las guarde)
ImpoundingPlates = ImpoundingPlates or {}

-- Forward declaration
local OpenImpound

-- NPCs del impound

local function SpawnImpoundPeds()
    -- Limpiar peds anteriores
    for _, pedData in pairs(spawnedImpoundPeds) do
        if pedData.ped and DoesEntityExist(pedData.ped) then
            DeleteEntity(pedData.ped)
        end
    end
    spawnedImpoundPeds = {}
    
    for _, impound in pairs(Config.Impounds) do
        if impound.ped then
            local pedConfig = impound.ped
            local modelHash = GetHashKey(pedConfig.model)
            
            RequestModel(modelHash)
            local timeout = 0
            while not HasModelLoaded(modelHash) and timeout < 50 do
                Wait(100)
                timeout = timeout + 1
            end
            
            if HasModelLoaded(modelHash) then
                local coords = pedConfig.coords
                local ped = CreatePed(4, modelHash, coords.x, coords.y, coords.z - 1.0, coords.w or 0.0, false, true)
                
                if DoesEntityExist(ped) then
                    SetEntityInvincible(ped, true)
                    SetBlockingOfNonTemporaryEvents(ped, true)
                    FreezeEntityPosition(ped, true)
                    SetPedCanBeTargetted(ped, false)
                    SetPedCanRagdoll(ped, false)
                    SetPedFleeAttributes(ped, 0, false)
                    SetPedCombatAttributes(ped, 46, true)
                    
                    -- Aplicar escenario de animación
                    if pedConfig.scenario then
                        TaskStartScenarioInPlace(ped, pedConfig.scenario, 0, true)
                    end
                    
                    -- Guardar referencia
                    spawnedImpoundPeds[impound.id] = {
                        ped = ped,
                        impound = impound
                    }
                    
                    -- Registrar ox_target en el ped
                    if Config.Target and Config.Target == 'ox_target' then
                        exports.ox_target:addLocalEntity(ped, {
                            {
                                name = 'impound_' .. impound.id,
                                icon = 'fas fa-warehouse',
                                label = impound.name,
                                onSelect = function()
                                    OpenImpound(impound)
                                end,
                                distance = 2.5
                            }
                        })
                    elseif Config.Target and Config.Target == 'qb-target' then
                        exports['qb-target']:AddTargetEntity(ped, {
                            options = {
                                {
                                    type = "client",
                                    icon = 'fas fa-warehouse',
                                    label = impound.name,
                                    action = function()
                                        OpenImpound(impound)
                                    end,
                                    canInteract = function()
                                        return true
                                    end
                                }
                            },
                            distance = 2.5
                        })
                    end
                end
                
                SetModelAsNoLongerNeeded(modelHash)
            end
        end
    end
end

local function CleanupImpoundPeds()
    -- Eliminar targets y peds
    for impoundId, pedData in pairs(spawnedImpoundPeds) do
        if Config.Target and Config.Target == 'ox_target' and pedData.ped then
            pcall(function()
                exports.ox_target:removeLocalEntity(pedData.ped)
            end)
        elseif Config.Target and Config.Target == 'qb-target' and pedData.ped then
            pcall(function()
                exports['qb-target']:RemoveTargetEntity(pedData.ped)
            end)
        end
        
        if pedData.ped and DoesEntityExist(pedData.ped) then
            DeleteEntity(pedData.ped)
        end
    end
    spawnedImpoundPeds = {}
end

--[[
    Abre el menú del impound
    NO MODIFICAR - Lógica async crítica para rendimiento
--]]
OpenImpound = function(impound)
    if not impound then return end
    
    currentImpound = impound
    
    -- Abrir la NUI inmediatamente con estado de carga
    SendNUIMessage({
        action = 'openImpound',
        impound = {
            id = impound.id,
            name = impound.name
        },
        vehicles = nil, -- nil indica que está cargando
        releaseFee = Config.ImpoundSettings and Config.ImpoundSettings.DefaultFee or 500,
        locale = Config.Locale or 'es',
        loading = true
    })
    SetNuiFocus(true, true)
    
    -- Obtener vehículos confiscados del jugador en segundo plano
    FrameworkBridge.TriggerCallback('kr_garages:server:GetPlayerImpoundedVehicles', function(vehicles)
        -- Actualizar la NUI con los vehículos
        SendNUIMessage({
            action = 'updateImpoundVehicles',
            vehicles = vehicles or {},
            loading = false,
            isAdminView = false
        })
    end)
end

exports('OpenImpound', OpenImpound)

-- NUI Callbacks
RegisterNUICallback('releaseFromImpound', function(data, cb)
    if not data.id or not currentImpound then 
        cb({ success = false })
        return
    end
    
    -- Enviar solicitud al servidor
    TriggerServerEvent('kr_garages:server:ReleaseFromImpound', { 
        id = data.id,
        currentImpoundId = currentImpound.id
    })
    
    -- Cerrar NUI
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
    
    cb({ success = true })
end)

-- Eventos de red
RegisterNetEvent('kr_garages:client:DeleteImpoundedVehicle', function(netId)
    if not netId then return end
    
    local vehicle = NetworkGetEntityFromNetworkId(netId)
    if vehicle and vehicle ~= 0 and DoesEntityExist(vehicle) then
        -- Obtener la placa antes de eliminar
        local plate = GetVehicleNumberPlateText(vehicle)
        if plate then
            plate = string.gsub(plate, "^%s*(.-)%s*$", "%1") -- trim
            -- Marcar como incautado para que tracking lo ignore
            ImpoundingPlates[plate] = true
            -- Quitar de spawnedVehicles si existe
            if spawnedVehicles then
                spawnedVehicles[plate] = nil
            end
        end
        
        -- Eliminar el vehículo
        SetEntityAsMissionEntity(vehicle, true, true)
        DeleteVehicle(vehicle)
        
        -- Limpiar la placa después de un momento
        if plate then
            SetTimeout(5000, function()
                ImpoundingPlates[plate] = nil
            end)
        end
    end
end)

-- Evento de éxito de incautación (para el policía que incautó)
RegisterNetEvent('kr_garages:client:ImpoundSuccess', function(plate)
    if plate then
        -- Marcar como incautado
        ImpoundingPlates[plate] = true
        -- Quitar de spawnedVehicles si existe
        if spawnedVehicles then
            spawnedVehicles[plate] = nil
        end
        -- Limpiar después de un momento
        SetTimeout(5000, function()
            ImpoundingPlates[plate] = nil
        end)
    end
end)

-- Evento del servidor cuando un vehículo se libera exitosamente
RegisterNetEvent('kr_garages:client:ImpoundVehicleReleased', function(vehicleData, spawnCoords)
    if not vehicleData or not spawnCoords then return end
    
    -- Cerrar NUI
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'hide' })
    
    -- Obtener modelo del vehículo de múltiples fuentes
    local model = vehicleData.model
    local vehicleProps = nil
    
    -- Si vehicle es string JSON, decodificar
    if vehicleData.vehicle then
        if type(vehicleData.vehicle) == 'string' and #vehicleData.vehicle > 2 then
            local ok, decoded = pcall(json.decode, vehicleData.vehicle)
            if ok and type(decoded) == 'table' then
                vehicleProps = decoded
                if not model then
                    model = decoded.model or decoded.hash
                end
            end
        elseif type(vehicleData.vehicle) == 'table' then
            vehicleProps = vehicleData.vehicle
            if not model then
                model = vehicleData.vehicle.model or vehicleData.vehicle.hash
            end
        end
    end
    
    local modelHash = nil
    
    if type(model) == 'string' and model ~= '' and model ~= 'nil' then
        modelHash = GetHashKey(model)
    elseif type(model) == 'number' then
        modelHash = model
    else
        FrameworkBridge.ShowNotification('~r~Error: No se pudo obtener el modelo del vehículo')
        return
    end
    
    -- Verificar si el modelo es válido
    if not IsModelValid(modelHash) then
        FrameworkBridge.ShowNotification('~r~Error: El modelo del vehículo no existe')
        print(('[kr_garages] ERROR: Invalid model in impound: %s'):format(tostring(model)))
        return
    end
    
    RequestModel(modelHash)
    local timeout = 0
    while not HasModelLoaded(modelHash) and timeout < 5000 do
        Wait(10)
        timeout = timeout + 10
    end
    
    if not HasModelLoaded(modelHash) then
        FrameworkBridge.ShowNotification('~r~Error al cargar el modelo del vehículo')
        return
    end
    
    local vehicle = CreateVehicle(modelHash, spawnCoords.x, spawnCoords.y, spawnCoords.z, spawnCoords.w or 0.0, true, false)
    
    SetModelAsNoLongerNeeded(modelHash)
    
    if not DoesEntityExist(vehicle) then
        FrameworkBridge.ShowNotification('~r~Error al crear el vehículo')
        return
    end
    
    -- Esperar un frame para que el vehículo se inicialice completamente
    Wait(100)
    
    -- Aplicar propiedades del vehículo (usar vehicleProps ya decodificado si existe)
    if vehicleProps and type(vehicleProps) == 'table' then
        -- Usar ox_lib primero (más completo)
        if lib and lib.setVehicleProperties then
            lib.setVehicleProperties(vehicle, vehicleProps)
        elseif FrameworkBridge and FrameworkBridge.SetVehicleProperties then
            FrameworkBridge.SetVehicleProperties(vehicle, vehicleProps)
        elseif ESX and ESX.Game and ESX.Game.SetVehicleProperties then
            ESX.Game.SetVehicleProperties(vehicle, vehicleProps)
        end
    end
    
    -- Establecer placa después de aplicar propiedades
    Wait(50)
    SetVehicleNumberPlateText(vehicle, vehicleData.plate)
    
    -- Dar llaves del vehículo
    TaskWarpPedIntoVehicle(PlayerPedId(), vehicle, -1)
    SetVehicleEngineOn(vehicle, true, true, false)
    
    FrameworkBridge.ShowNotification('~g~Vehículo liberado del depósito')
    
    currentImpound = nil
end)

-- Evento fallback: spawnear vehículo cerca del jugador (si no hay spawn point configurado)
RegisterNetEvent('kr_garages:client:SpawnVehicleNearPlayer', function(vehicleData)
    if not vehicleData then return end
    
    -- Obtener modelo del vehículo
    local model = vehicleData.model
    
    if not model and vehicleData.vehicle then
        local vehicleProps = vehicleData.vehicle
        if type(vehicleProps) == 'string' then
            local ok, decoded = pcall(json.decode, vehicleProps)
            if ok and decoded then
                model = decoded.model or decoded.hash
            end
        elseif type(vehicleProps) == 'table' then
            model = vehicleProps.model or vehicleProps.hash
        end
    end
    
    local modelHash = nil
    if type(model) == 'string' then
        modelHash = GetHashKey(model)
    elseif type(model) == 'number' then
        modelHash = model
    else
        FrameworkBridge.ShowNotification('~r~Error: Modelo de vehículo inválido')
        return
    end
    
    if not IsModelValid(modelHash) then
        FrameworkBridge.ShowNotification('~r~Error: El modelo del vehículo no existe')
        return
    end
    
    RequestModel(modelHash)
    local timeout = 0
    while not HasModelLoaded(modelHash) and timeout < 5000 do
        Wait(10)
        timeout = timeout + 10
    end
    
    if not HasModelLoaded(modelHash) then
        FrameworkBridge.ShowNotification('~r~Error al cargar el modelo del vehículo')
        return
    end
    
    -- Buscar posición cerca del jugador
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)
    local heading = GetEntityHeading(playerPed)
    
    -- Buscar una posición libre para el vehículo
    local spawnCoords = GetOffsetFromEntityInWorldCoords(playerPed, 0.0, 5.0, 0.0)
    
    local vehicle = CreateVehicle(modelHash, spawnCoords.x, spawnCoords.y, spawnCoords.z, heading + 90.0, true, false)
    SetModelAsNoLongerNeeded(modelHash)
    
    if not DoesEntityExist(vehicle) then
        FrameworkBridge.ShowNotification('~r~Error al crear el vehículo')
        return
    end
    
    -- Esperar un frame para que el vehículo se inicialice completamente
    Wait(100)
    
    -- Aplicar propiedades del vehículo
    local vehicleProps = vehicleData.vehicle or vehicleData.props
    if vehicleProps then
        local props = vehicleProps
        if type(props) == 'string' then
            local ok, decoded = pcall(json.decode, props)
            if ok then
                props = decoded
            end
        end
        
        if type(props) == 'table' then
            -- Usar ox_lib primero (más completo)
            if lib and lib.setVehicleProperties then
                lib.setVehicleProperties(vehicle, props)
            elseif FrameworkBridge and FrameworkBridge.SetVehicleProperties then
                FrameworkBridge.SetVehicleProperties(vehicle, props)
            elseif ESX and ESX.Game and ESX.Game.SetVehicleProperties then
                ESX.Game.SetVehicleProperties(vehicle, props)
            end
        end
    end
    
    Wait(50)
    SetVehicleNumberPlateText(vehicle, vehicleData.plate)
    SetVehicleOnGroundProperly(vehicle)
    
    FrameworkBridge.ShowNotification('~g~Vehículo liberado del depósito')
    currentImpound = nil
end)

-- Evento cuando se confisca un vehículo exitosamente
RegisterNetEvent('kr_garages:client:VehicleImpounded', function(plate)
    FrameworkBridge.ShowNotification('~g~Vehículo con placa ' .. plate .. ' confiscado exitosamente')
end)

-- ============================================
-- BLIPS DE IMPOUND EN EL MAPA
-- ============================================

local impoundBlips = {}

local function CreateImpoundBlips()
    -- Limpiar blips existentes
    for _, blip in pairs(impoundBlips) do
        if DoesBlipExist(blip) then
            RemoveBlip(blip)
        end
    end
    impoundBlips = {}
    
    -- Crear blips para cada impound
    for _, impound in ipairs(Config.Impounds or {}) do
        if impound.blip and impound.coords then
            local blip = AddBlipForCoord(impound.coords.x, impound.coords.y, impound.coords.z)
            SetBlipSprite(blip, impound.blip.sprite or 524)
            SetBlipDisplay(blip, impound.blip.display or 4)
            SetBlipScale(blip, impound.blip.scale or 0.8)
            SetBlipColour(blip, impound.blip.color or 40)
            SetBlipAsShortRange(blip, impound.blip.shortRange ~= false)
            BeginTextCommandSetBlipName("STRING")
            AddTextComponentString(impound.name or 'Depósito')
            EndTextCommandSetBlipName(blip)
            
            impoundBlips[impound.id] = blip
        end
    end
end

local function CleanupImpoundBlips()
    for _, blip in pairs(impoundBlips) do
        if DoesBlipExist(blip) then
            RemoveBlip(blip)
        end
    end
    impoundBlips = {}
end

-- ============================================
-- SPAWN IMPOUND NPCS ON RESOURCE START
-- ============================================

CreateThread(function()
    while not Config or not Config.Impounds do
        Wait(500)
    end
    
    -- Esperar un momento para asegurar que todo está cargado
    Wait(2000)
    
    -- Crear blips en el mapa
    CreateImpoundBlips()
    
    -- Spawn de los NPCs del impound
    SpawnImpoundPeds()
end)

-- Cleanup al detener el recurso
AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() == resourceName then
        CleanupImpoundPeds()
        CleanupImpoundBlips()
    end
end)

-- ============================================
-- FALLBACK: Interacción con NPC sin ox_target
-- ============================================

-- Si no hay ox_target, usar interacción con tecla E
CreateThread(function()
    while not Config or not Config.Impounds do
        Wait(500)
    end
    
    -- Si hay ox_target o qb-target, no necesitamos este thread
    if Config.Target and (Config.Target == 'ox_target' or Config.Target == 'qb-target') then
        return
    end
    
    -- Thread de fallback para interacción sin target system
    while true do
        if resourceStopping then return end
        
        local playerPed = PlayerPedId()
        local playerCoords = GetEntityCoords(playerPed)
        local nearestPed = nil
        local nearestImpound = nil
        local nearestDist = math.huge
        
        for impoundId, pedData in pairs(spawnedImpoundPeds) do
            if pedData.ped and DoesEntityExist(pedData.ped) then
                local pedCoords = GetEntityCoords(pedData.ped)
                local dist = #(playerCoords - pedCoords)
                
                if dist < 3.0 and dist < nearestDist then
                    nearestDist = dist
                    nearestPed = pedData.ped
                    nearestImpound = pedData.impound
                end
            end
        end
        
        if nearestPed and nearestImpound then
            -- Mostrar texto de interacción
            DrawInteractionText(nearestImpound.name, "open", "impound")
            
            -- Detectar tecla E
            if IsControlJustReleased(0, 38) then
                PlayInteractionSound()
                OpenImpound(nearestImpound)
            end
            
            Wait(0)
        else
            Wait(500)
        end
    end
end)

-- ============================================
-- SISTEMA DE INCAUTACIÓN (para policías)
-- ============================================

-- Evento del servidor para abrir menú de incautación
RegisterNetEvent('kr_garages:client:OpenImpoundMenu', function()
    local ped = PlayerPedId()
    local vehicle = nil
    
    -- Primero verificar si está en un vehículo
    if IsPedInAnyVehicle(ped, false) then
        vehicle = GetVehiclePedIsIn(ped, false)
    else
        -- Buscar vehículo cercano
        vehicle = GetClosestVehicle(GetEntityCoords(ped), 5.0, 0, 71)
    end
    
    if not vehicle or vehicle == 0 then
        FrameworkBridge.ShowNotification('~r~No hay ningún vehículo cercano para confiscar')
        return
    end
    
    local plate = GetVehicleNumberPlateText(vehicle)
    if not plate then
        FrameworkBridge.ShowNotification('~r~No se pudo obtener la placa del vehículo')
        return
    end
    
    plate = string.gsub(plate, "^%s*(.-)%s*$", "%1") -- trim
    local netId = NetworkGetNetworkIdFromEntity(vehicle)
    local model = GetEntityModel(vehicle)
    local modelName = GetDisplayNameFromVehicleModel(model):lower()
    
    -- Obtener propiedades COMPLETAS del vehículo usando el framework
    -- Esto incluye colores, mods, extras, etc.
    local vehicleProps = nil
    
    -- Usar lib.getVehicleProperties si está disponible (ox_lib)
    if lib and lib.getVehicleProperties then
        vehicleProps = lib.getVehicleProperties(vehicle)
    elseif FrameworkBridge and FrameworkBridge.GetVehicleProperties then
        vehicleProps = FrameworkBridge.GetVehicleProperties(vehicle)
    end
    
    -- Si no se pudo obtener las propiedades, crear unas básicas
    if not vehicleProps or type(vehicleProps) ~= 'table' then
        vehicleProps = {
            model = model,
            plate = plate
        }
    end
    
    -- Asegurarnos de que el modelo y nombre estén incluidos
    vehicleProps.model = vehicleProps.model or model
    vehicleProps.modelName = modelName
    vehicleProps.modelLabel = modelName:upper()
    
    -- Obtener ubicaciones de impound
    FrameworkBridge.TriggerCallback('kr_garages:getImpoundLocations', function(locations)
        if not locations or #locations == 0 then
            FrameworkBridge.ShowNotification('~r~No hay ubicaciones de impound configuradas')
            return
        end
        
        -- Obtener razones de impound
        FrameworkBridge.TriggerCallback('kr_garages:getImpoundReasons', function(reasons)
            -- Abrir NUI para incautar
            SendNUIMessage({
                action = 'openImpoundForm',
                plate = plate,
                modelName = modelName:upper(),
                netId = netId,
                vehicleProps = vehicleProps,
                locations = locations,
                reasons = reasons or {
                    'Estacionamiento ilegal',
                    'Vehículo abandonado',
                    'Vehículo robado',
                    'Infracción de tráfico',
                    'Evidencia de crimen',
                    'Otro'
                },
                defaultFee = Config.ImpoundPrice or 500
            })
            SetNuiFocus(true, true)
        end)
    end)
end)

-- ============================================
-- SISTEMA DE PROGRESO Y ANIMACIÓN
-- ============================================

local isDoingImpound = false
local impoundProp = nil

-- Función para mostrar barra de progreso nativa con animación de clipboard
local function ShowProgressBar(duration, label, onComplete, onCancel)
    if isDoingImpound then return end
    isDoingImpound = true
    
    local ped = PlayerPedId()
    local startTime = GetGameTimer()
    local endTime = startTime + duration
    
    -- Cargar diccionario de animación
    local animDict = 'missheistdockssetup1clipboard@base'
    RequestAnimDict(animDict)
    local timeout = 0
    while not HasAnimDictLoaded(animDict) and timeout < 50 do
        Wait(100)
        timeout = timeout + 1
    end
    
    -- Cargar modelo del prop (clipboard)
    local propModel = GetHashKey('p_amb_clipboard_01')
    RequestModel(propModel)
    timeout = 0
    while not HasModelLoaded(propModel) and timeout < 50 do
        Wait(100)
        timeout = timeout + 1
    end
    
    -- Crear y attachear prop de clipboard
    local coords = GetEntityCoords(ped)
    impoundProp = CreateObject(propModel, coords.x, coords.y, coords.z, true, true, true)
    
    if impoundProp and DoesEntityExist(impoundProp) then
        local boneIndex = GetPedBoneIndex(ped, 18905) -- SKEL_L_Hand
        AttachEntityToEntity(impoundProp, ped, boneIndex, 0.16, 0.08, 0.1, -130.0, -50.0, 0.0, true, true, false, true, 1, true)
    end
    
    -- Iniciar animación
    if HasAnimDictLoaded(animDict) then
        TaskPlayAnim(ped, animDict, 'base', 8.0, -8.0, -1, 49, 0, false, false, false)
    end
    
    -- Thread para mostrar la barra de progreso
    CreateThread(function()
        while GetGameTimer() < endTime and isDoingImpound do
            Wait(0)
            
            -- Permitir cancelar con tecla X o Backspace
            if IsControlJustPressed(0, 73) or IsControlJustPressed(0, 194) then -- X key o Backspace
                -- Cancelar
                ClearPedTasks(ped)
                if impoundProp and DoesEntityExist(impoundProp) then
                    DeleteObject(impoundProp)
                    impoundProp = nil
                end
                isDoingImpound = false
                FrameworkBridge.ShowNotification('~r~Confiscación cancelada')
                if onCancel then onCancel() end
                return
            end
            
            -- Calcular progreso
            local progress = (GetGameTimer() - startTime) / duration
            local barWidth = 0.15
            local barHeight = 0.02
            local barX = 0.5
            local barY = 0.88
            
            -- Fondo oscuro de la barra
            DrawRect(barX, barY, barWidth + 0.006, barHeight + 0.012, 0, 0, 0, 200)
            -- Borde
            DrawRect(barX, barY, barWidth + 0.002, barHeight + 0.006, 50, 50, 50, 255)
            -- Fondo de la barra
            DrawRect(barX, barY, barWidth, barHeight, 30, 30, 30, 255)
            -- Barra de progreso (azul policial)
            local fillWidth = barWidth * progress
            DrawRect(barX - (barWidth / 2) + (fillWidth / 2), barY, fillWidth, barHeight, 59, 130, 246, 255)
            
            -- Texto del label
            SetTextFont(4)
            SetTextScale(0.38, 0.38)
            SetTextColour(255, 255, 255, 255)
            SetTextCentre(true)
            SetTextDropshadow(1, 0, 0, 0, 255)
            BeginTextCommandDisplayText('STRING')
            AddTextComponentSubstringPlayerName(label)
            EndTextCommandDisplayText(barX, barY - 0.045)
            
            -- Texto de cancelar
            SetTextFont(4)
            SetTextScale(0.30, 0.30)
            SetTextColour(200, 200, 200, 200)
            SetTextCentre(true)
            BeginTextCommandDisplayText('STRING')
            AddTextComponentSubstringPlayerName('Presiona ~r~X~s~ para cancelar')
            EndTextCommandDisplayText(barX, barY + 0.018)
        end
        
        -- Verificar si fue completado (no cancelado)
        if isDoingImpound then
            -- Completado exitosamente
            ClearPedTasks(ped)
            if impoundProp and DoesEntityExist(impoundProp) then
                DeleteObject(impoundProp)
                impoundProp = nil
            end
            isDoingImpound = false
            
            if onComplete then onComplete() end
        end
    end)
end

-- Callback NUI para confirmar incautación
RegisterNUICallback('confirmImpound', function(data, cb)
    if not data or not data.plate then
        cb({ success = false })
        return
    end
    
    -- Cerrar NUI primero
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'hide' })
    
    cb({ success = true })
    
    -- Mostrar barra de progreso con animación
    ShowProgressBar(5000, '~b~Registrando confiscación...', function()
        -- Al completar
        -- Marcar la placa como incautándose
        ImpoundingPlates[data.plate] = true
        
        TriggerServerEvent('kr_garages:server:ImpoundVehicle', {
            plate = data.plate,
            impoundId = data.impoundId or 'impound_a',
            fee = tonumber(data.fee) or 500,
            reason = data.reason or 'Sin razón especificada',
            vehicleProps = data.vehicleProps,
            netId = data.netId
        })
    end, function()
        -- Al cancelar
        ImpoundingPlates[data.plate] = nil
    end)
end)

-- Callback NUI para cancelar
RegisterNUICallback('cancelImpound', function(data, cb)
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'hide' })
    cb({ success = true })
end)

-- Callback NUI para liberar sin pago (policía/admin)
RegisterNUICallback('policeReleaseFromImpound', function(data, cb)
    if not data.id then 
        cb({ success = false })
        return
    end
    
    -- Enviar solicitud al servidor
    TriggerServerEvent('kr_garages:server:PoliceReleaseFromImpound', { 
        id = data.id,
        garage = 'central_garage'
    })
    
    -- Cerrar NUI
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
    
    cb({ success = true })
end)

-- Callback NUI para eliminar del sistema (admin-only)
RegisterNUICallback('deleteFromImpound', function(data, cb)
    if not data.id then 
        cb({ success = false })
        return
    end
    
    -- Enviar solicitud al servidor
    TriggerServerEvent('kr_garages:server:DeleteFromImpound', { 
        id = data.id
    })
    
    -- Cerrar NUI
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
    
    cb({ success = true })
end)

-- Evento para abrir el panel de admin del impound (comando /verimpound)
RegisterNetEvent('kr_garages:client:OpenImpoundAdmin', function()
    -- Abrir NUI con estado de carga usando el mismo impound view
    SendNUIMessage({
        action = 'openImpound',
        impound = {
            id = 'admin',
            name = 'Todos los Vehiculos Confiscados'
        },
        vehicles = nil,
        releaseFee = 0,
        locale = Config.Locale or 'es',
        loading = true,
        isAdmin = true
    })
    SetNuiFocus(true, true)
    
    -- Obtener todos los vehículos del impound (ahora incluye isFullAdmin)
    FrameworkBridge.TriggerCallback('kr_garages:getAllImpoundedVehicles', function(vehicles, isFullAdmin)
        SendNUIMessage({
            action = 'updateImpoundVehicles',
            vehicles = vehicles or {},
            loading = false,
            isFullAdmin = isFullAdmin or false,
            isAdminView = true
        })
    end)
end)
