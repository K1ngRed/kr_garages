-- client/markers_thread.lua
-- Thread principal de markers para garajes públicos

-- Esperar a que FrameworkBridge esté disponible
while not FrameworkBridge do
    Wait(100)
end

-- ============================================
-- MARKERS THREAD
-- ============================================

CreateThread(function()
    -- Esperar a que Config esté disponible y los garajes se hayan cargado
    while not Config or not PublicGaragesLoaded do
        Wait(100)
        if resourceStopping then return end
    end
    
    -- Esperar un poco más para asegurar que todo esté listo
    Wait(500)
    
    local impounds = Config.Impounds or {}

    -- Cache de datos del jugador (se actualiza cada segundo)
    local cachedJobName = nil
    local cachedGangName = nil
    local lastJobCheck = 0
    local JOB_CHECK_INTERVAL = 1000
    
    while not resourceStopping do
        local sleep = 500
        local ped = PlayerPedId()
        local pos = GetEntityCoords(ped)
        local currentTime = GetGameTimer()
        
        -- Actualizar cache de job/gang periódicamente
        if currentTime - lastJobCheck > JOB_CHECK_INTERVAL then
            cachedJobName = FrameworkBridge.GetJobName()
            cachedGangName = FrameworkBridge.GetGangName()
            lastJobCheck = currentTime
        end
        
        -- Obtener garajes actualizados
        local garages = Config.Garages or {}
        local numGarages = #garages
        
        -- Pre-calcular si está en vehículo
        local vehicle = GetVehiclePedIsIn(ped, false)
        local isInVehicle = vehicle ~= 0 and GetPedInVehicleSeat(vehicle, -1) == ped
        local posVec2 = vector2(pos.x, pos.y)

        -- Garajes públicos
        for i = 1, numGarages do
            local garage = garages[i]
            if garage and garage.coords then
                -- Verificar acceso usando cache
                local hasAccess = true
                if garage.job then
                    hasAccess = (cachedJobName == garage.job)
                elseif garage.gang then
                    hasAccess = (cachedGangName == garage.gang)
                end
                
                if hasAccess then
                    local garageVec2 = vector2(garage.coords.x, garage.coords.y)
                    local dist2D = #(posVec2 - garageVec2)
                    local heightDiff = math.abs(pos.z - garage.coords.z)
                    local maxHeight = MAX_INTERACTION_HEIGHT
                    
                    local garageType = garage.garageType or 'public'
                    local isJobGarage = garageType == 'job'
                    
                    -- Distancias de interacción optimizadas
                    local interactionDist = 3.5
                    local markerViewDist = 12.0
                    
                    if isInVehicle then
                        if garage.type == 'air' then
                            interactionDist = 30.0
                            markerViewDist = 45.0
                        elseif garage.type == 'boat' then
                            interactionDist = 25.0
                            markerViewDist = 35.0
                        else
                            if isJobGarage then
                                interactionDist = 20.0
                                markerViewDist = 30.0
                            else
                                interactionDist = 15.0
                                markerViewDist = 22.0
                            end
                        end
                        maxHeight = 10.0
                    else
                        interactionDist = 3.5
                        markerViewDist = 12.0
                    end
                    
                    if dist2D < markerViewDist then
                        sleep = 0
                        
                        local vehicleType = garage.type or 'car'
                        local markerConfig = GARAGE_MARKERS[vehicleType] or GARAGE_MARKERS.car
                        
                        if dist2D < markerViewDist - 3.0 then
                            DrawMarker(markerConfig.sprite, 
                                garage.coords.x, garage.coords.y, garage.coords.z + 0.5, 
                                180.0, 0.0, 0.0, 0.0, 0.0, 0.0, 
                                markerConfig.scale, markerConfig.scale, markerConfig.scale, 
                                markerConfig.color[1], markerConfig.color[2], markerConfig.color[3], markerConfig.color[4], 
                                true, true, 2, true, nil, nil, false)
                        end
                        
                        local garageCoords = vector3(garage.coords.x, garage.coords.y, garage.coords.z)
                        local hasLOS = HasLineOfSight(pos, garageCoords, isInVehicle)
                        
                        if dist2D < interactionDist and heightDiff < maxHeight and hasLOS then
                            if not playerInGarageZone[garage.id] then
                                playerInGarageZone[garage.id] = true
                                PlayEnterZoneSound()
                            end
                            
                            if isInVehicle then
                                DrawInteractionText(garage.name, "store", vehicleType)
                                
                                if IsControlJustReleased(0, 38) then
                                    PlayInteractionSound()
                                    currentGarage = garage
                                    if StoreVehicle then
                                        StoreVehicle()
                                    end
                                end
                            else
                                DrawInteractionText(garage.name, "open", vehicleType)
                                
                                if IsControlJustReleased(0, 38) then
                                    PlayInteractionSound()
                                    OpenGarage(garage)
                                end
                            end
                        else
                            playerInGarageZone[garage.id] = nil
                        end
                    else
                        playerInGarageZone[garage.id] = nil
                    end
                end
            end
        end
        
        -- NOTA: Los impounds ahora usan NPCs con ox_target, no marcadores
        -- Ver client/impound.lua para el sistema de NPCs
        
        Wait(sleep)
    end
end)
