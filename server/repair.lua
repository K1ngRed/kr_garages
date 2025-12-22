--[[
    server/repair.lua
    Sistema de reparación de vehículos
    
    NO MODIFICAR SI NO SABES LO QUE ESTAS HACIENDO
    Cobra dinero y resetea estado del vehículo
--]]

FrameworkBridge.RegisterCallback('kr_garages:server:RepairAndSpawnVehicle', function(source, cb, plate, garageId)
    local xPlayer = FrameworkBridge.GetPlayer(source)
    if not xPlayer then return cb(false, nil, 'Jugador inválido') end
    local identifier = GetPlayerIdentifier(xPlayer)
    if not plate or type(plate) ~= 'string' then return cb(false, nil, 'Placa inválida') end
    
    MySQL.query('SELECT vehicle, plate, fuel, engine, body, in_garage, garage_id FROM owned_vehicles WHERE plate = ? AND owner = ?', {
        plate, identifier
    }, function(rows)
        if not rows or not rows[1] then 
            return cb(false, nil, 'Vehículo no encontrado') 
        end
        local row = rows[1]
        
        local engineHealth = (row.engine ~= nil) and row.engine or 1000
        local bodyHealth = (row.body ~= nil) and row.body or 1000
        local existsInWorld = (row.in_garage == 0 or row.in_garage == false)
        local inGarage = (row.in_garage == 1 or row.in_garage == true)
        local fuelValue = (row.fuel ~= nil) and row.fuel or 100
        
        local isDestroyed = (engineHealth <= 0 and bodyHealth <= 0 and fuelValue <= 0)
        local hasDamage = (engineHealth < 1000 or bodyHealth < 1000 or fuelValue < 100)
        
        if inGarage and not hasDamage then
            return cb(false, nil, 'Este vehículo no necesita reparación. Usa Usar Vehículo.')
        end
        
        local repairCost = CalculateRepairCost(engineHealth, bodyHealth, fuelValue, inGarage, existsInWorld)
        
        local playerMoney = FrameworkBridge.GetBankMoney(xPlayer)
        
        if playerMoney < repairCost then
            return cb(false, nil, ('No tienes suficiente dinero. Necesitas $%d'):format(repairCost))
        end
        
        FrameworkBridge.RemoveBankMoney(xPlayer, repairCost)
        
        MySQL.update('UPDATE owned_vehicles SET engine = 1000, body = 1000, fuel = 100, in_garage = 0 WHERE plate = ? AND owner = ?', {
            plate, identifier
        }, function(affectedRows)
            if not affectedRows or affectedRows == 0 then
                FrameworkBridge.AddBankMoney(xPlayer, repairCost)
                return cb(false, nil, 'Error al reparar el vehículo en la base de datos')
            end
            
            FrameworkBridge.ShowNotification(source, ('~g~Vehículo reparado por $%d'):format(repairCost))
            
            MySQL.query('SELECT vehicle, fuel FROM owned_vehicles WHERE plate = ? AND owner = ?', {
                plate, identifier
            }, function(updatedRows)
                if not updatedRows or not updatedRows[1] then
                    return cb(false, nil, 'Error al obtener datos del vehículo')
                end
                
                local props = {}
                if type(updatedRows[1].vehicle) == 'string' and updatedRows[1].vehicle ~= '' then
                    local ok, data = pcall(json.decode, updatedRows[1].vehicle)
                    if ok and type(data) == 'table' then 
                        props = data 
                    end
                end
                
                local model = nil
                
                if props.model and type(props.model) == 'string' and props.model ~= '' then
                    model = string.lower(props.model)
                elseif props.modelName and type(props.modelName) == 'string' and props.modelName ~= '' then
                    model = string.lower(props.modelName)
                elseif props.modelLabel and type(props.modelLabel) == 'string' and props.modelLabel ~= '' then
                    model = string.lower(props.modelLabel)
                elseif props.model and type(props.model) == 'number' then
                    if VehicleData and VehicleData.GetByHash then
                        local vInfo = VehicleData.GetByHash(props.model)
                        if vInfo then 
                            model = vInfo.name 
                        end
                    end
                    if not model then
                        model = props.model
                        print(('[kr_garages] WARNING: Passing hash %s to client for spawn'):format(props.model))
                    end
                elseif props.modelHash and type(props.modelHash) == 'number' then
                    if VehicleData and VehicleData.GetByHash then
                        local vInfo = VehicleData.GetByHash(props.modelHash)
                        if vInfo then 
                            model = vInfo.name 
                        end
                    end
                    if not model then
                        model = props.modelHash
                    end
                end
                
                if not model then
                    return cb(false, nil, 'No se pudo determinar el modelo del vehículo. Contacta a un admin.')
                end
                
                props.model = model
                
                cb(true, {
                    plate = plate,
                    props = props,
                    model = model,
                    vehicle = model,
                    fuel = 100,
                    engine = 1000,
                    body = 1000
                })
            end)
        end)
    end)
end)

-- ============================================
-- RECOVER AND SPAWN VEHICLE
-- ============================================

FrameworkBridge.RegisterCallback('kr_garages:server:RecoverAndSpawnVehicle', function(source, cb, plate, garageId)
    local xPlayer = FrameworkBridge.GetPlayer(source)
    if not xPlayer then return cb(false, nil, 'Jugador inválido') end
    local identifier = GetPlayerIdentifier(xPlayer)
    if not plate or type(plate) ~= 'string' then return cb(false, nil, 'Placa inválida') end
    if not garageId then return cb(false, nil, 'Garaje no especificado') end
    
    local normalizedGarageId = tostring(garageId)
    
    MySQL.query('SELECT vehicle, plate, fuel, engine, body, in_garage, garage_id FROM owned_vehicles WHERE plate = ? AND owner = ?', {
        plate, identifier
    }, function(rows)
        if not rows or not rows[1] then 
            return cb(false, nil, 'Vehículo no encontrado') 
        end
        local row = rows[1]
        
        if row.in_garage == 1 or row.in_garage == true then
            return cb(false, nil, 'Este vehículo ya está en el garaje.')
        end
        
        local engineHealth = (row.engine ~= nil) and row.engine or 1000
        local bodyHealth = (row.body ~= nil) and row.body or 1000
        local fuelValue = (row.fuel ~= nil) and row.fuel or 100
        
        local hasDamage = (engineHealth < 1000 or bodyHealth < 1000 or fuelValue < 100)
        
        local recoverCost = CalculateRepairCost(engineHealth, bodyHealth, fuelValue, false, true)
        
        local playerCash = FrameworkBridge.GetMoney(xPlayer) or 0
        local playerBank = FrameworkBridge.GetBankMoney(xPlayer) or 0
        
        if playerCash < recoverCost and playerBank < recoverCost then
            return cb(false, nil, ('No tienes suficiente dinero. Necesitas $%d'):format(recoverCost))
        end
        
        local paidFromCash = false
        if playerCash >= recoverCost then
            FrameworkBridge.RemoveMoney(xPlayer, recoverCost)
            paidFromCash = true
        else
            FrameworkBridge.RemoveBankMoney(xPlayer, recoverCost)
        end
        
        MySQL.update('UPDATE owned_vehicles SET engine = 1000, body = 1000, fuel = 100, in_garage = 1, garage_id = ? WHERE plate = ? AND owner = ?', {
            normalizedGarageId,
            plate, 
            identifier
        }, function(affectedRows)
            if not affectedRows or affectedRows == 0 then
                if paidFromCash then
                    FrameworkBridge.AddMoney(xPlayer, recoverCost)
                else
                    FrameworkBridge.AddBankMoney(xPlayer, recoverCost)
                end
                return cb(false, nil, 'Error al recuperar el vehículo en la base de datos')
            end
            
            local notifyMsg = ('~g~Vehículo recuperado y reparado por $%d'):format(recoverCost)
            FrameworkBridge.ShowNotification(source, notifyMsg)
            
            TriggerClientEvent('kr_garages:client:DeleteVehicleByPlate', -1, plate)
            
            cb(true, { success = true, plate = plate, garageId = normalizedGarageId })
        end)
    end)
end)

-- ============================================
-- REPAIR ONLY VEHICLE (sin spawn)
-- ============================================

FrameworkBridge.RegisterCallback('kr_garages:server:RepairOnlyVehicle', function(source, cb, plate, garageId)
    local xPlayer = FrameworkBridge.GetPlayer(source)
    if not xPlayer then return cb(false, 'Jugador inválido') end
    local identifier = GetPlayerIdentifier(xPlayer)
    if not plate or type(plate) ~= 'string' then return cb(false, 'Placa inválida') end
    
    MySQL.query('SELECT vehicle, plate, fuel, engine, body, in_garage, garage_id FROM owned_vehicles WHERE plate = ? AND owner = ?', {
        plate, identifier
    }, function(rows)
        if not rows or not rows[1] then 
            return cb(false, 'Vehículo no encontrado') 
        end
        local row = rows[1]
        
        local engineHealth = (row.engine ~= nil) and row.engine or 1000
        local bodyHealth = (row.body ~= nil) and row.body or 1000
        local fuelValue = (row.fuel ~= nil) and row.fuel or 100
        local inGarage = (row.in_garage == 1 or row.in_garage == true)
        local existsInWorld = not inGarage
        
        local hasDamage = (engineHealth < 1000 or bodyHealth < 1000 or fuelValue < 100)
        
        if not hasDamage and inGarage then
            return cb(false, 'Este vehículo no necesita reparación')
        end
        
        local repairCost = CalculateRepairCost(engineHealth, bodyHealth, fuelValue, inGarage, existsInWorld)
        
        local playerMoney = FrameworkBridge.GetBankMoney(xPlayer)
        
        if playerMoney < repairCost then
            return cb(false, ('No tienes suficiente dinero. Necesitas $%d'):format(repairCost))
        end
        
        FrameworkBridge.RemoveBankMoney(xPlayer, repairCost)
        
        MySQL.update('UPDATE owned_vehicles SET engine = 1000, body = 1000, fuel = 100, in_garage = 1 WHERE plate = ? AND owner = ?', {
            plate, identifier
        }, function(affectedRows)
            if not affectedRows or affectedRows == 0 then
                FrameworkBridge.AddBankMoney(xPlayer, repairCost)
                return cb(false, 'Error al reparar el vehículo en la base de datos')
            end
            
            FrameworkBridge.ShowNotification(source, ('~g~Vehículo reparado por $%d'):format(repairCost))
            cb(true)
        end)
    end)
end)
