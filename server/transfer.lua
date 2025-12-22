--[[
    server/transfer.lua
    Sistema de transferencia de vehículos
    
    NO MODIFICAR SI NO SABES LO QUE ESTAS HACIENDO
    Maneja movimiento de vehículos entre garajes y jugadores
--]]

-- Obtener garajes para transferencia
RegisterNetEvent('kr_garages:server:GetTransferGarages', function()
    local src = source
    local xPlayer = FrameworkBridge.GetPlayer(src)
    local allGarages = {}
    
    -- 1. Agregar garajes públicos del config (excluir job y private)
    if Config and Config.Garages then
        for _, garage in ipairs(Config.Garages) do
            if garage.garageType == 'public' then
                table.insert(allGarages, {
                    id = garage.id,
                    name = garage.name or garage.id,
                    type = garage.type or garage.vehicleType or 'car',
                    garageType = 'public'
                })
            end
        end
    end
    
    -- 2. Agregar garajes privados del jugador
    if xPlayer then
        local identifier = GetPlayerIdentifier(xPlayer)
        if identifier then
            MySQL.query([[
                SELECT DISTINCT pg.id, pg.name, pg.type
                FROM private_garages pg
                LEFT JOIN private_garage_owners pgo ON pg.id = pgo.garage_id
                WHERE pg.owner = ? OR pgo.identifier = ?
            ]], { identifier, identifier }, function(privateGarages)
                if privateGarages then
                    for _, pg in ipairs(privateGarages) do
                        table.insert(allGarages, {
                            id = tonumber(pg.id) or pg.id,
                            name = (pg.name or 'Garaje Privado') .. ' (Privado)',
                            type = pg.type or 'car',
                            garageType = 'private'
                        })
                    end
                end
                
                TriggerClientEvent('kr_garages:client:ReceiveTransferGarages', src, allGarages)
            end)
        else
            TriggerClientEvent('kr_garages:client:ReceiveTransferGarages', src, allGarages)
        end
    else
        TriggerClientEvent('kr_garages:client:ReceiveTransferGarages', src, allGarages)
    end
end)

-- ============================================
-- TRANSFERIR VEHÍCULO
-- ============================================

RegisterNetEvent('kr_garages:server:TransferVehicle', function(plate, targetGarageId, transferType)
    local src = source
    local xPlayer = FrameworkBridge.GetPlayer(src)
    
    if not xPlayer then return end
    
    local identifier = GetPlayerIdentifier(xPlayer)
    
    if transferType == 'player' then
        -- Transferir a otro jugador (cambiar owner)
        MySQL.query('SELECT in_garage FROM owned_vehicles WHERE plate = ? AND owner = ?', {
            plate, identifier
        }, function(vehCheck)
            if not vehCheck or not vehCheck[1] then
                FrameworkBridge.ShowNotification(src, '~r~Vehículo no encontrado')
                return
            end
            
            local isOutside = (vehCheck[1].in_garage == 0 or vehCheck[1].in_garage == false)
            if isOutside then
                FrameworkBridge.ShowNotification(src, '~r~No puedes transferir un vehículo que está fuera del garaje. Debes guardarlo primero.')
                return
            end
            
            MySQL.query('SELECT identifier FROM users WHERE identifier = ?', { targetGarageId }, function(targetUser)
                if not targetUser or not targetUser[1] then
                    FrameworkBridge.ShowNotification(src, '~r~Jugador destino no encontrado')
                    return
                end
                
                MySQL.scalar('SELECT garage_id FROM owned_vehicles WHERE plate = ? AND owner = ?', { plate, identifier }, function(currentGarageId)
                    MySQL.update('UPDATE owned_vehicles SET owner = ?, in_garage = 1, engine = 1000, body = 1000, fuel = 100 WHERE plate = ? AND owner = ?', {
                        targetGarageId, plate, identifier
                    }, function(affectedRows)
                        if affectedRows > 0 then
                            LogVehicleTransfer(plate, identifier, targetGarageId, currentGarageId or 'unknown', 'player_garage', 'player')
                            FrameworkBridge.ShowNotification(src, '~g~Vehículo transferido exitosamente')
                        else
                            FrameworkBridge.ShowNotification(src, '~r~Error al transferir el vehículo')
                        end
                    end)
                end)
            end)
        end)
        
    elseif transferType == 'garage' then
        -- Transferir a otro garaje
        local transferPrice = Config.TransferPrice or 500
        local playerMoney = FrameworkBridge.GetMoney(xPlayer)
        local playerBank = FrameworkBridge.GetBankMoney(xPlayer)
        
        if playerMoney < transferPrice and playerBank < transferPrice then
            FrameworkBridge.ShowNotification(src, ('~r~No tienes suficiente dinero. Necesitas $%s'):format(transferPrice))
            return
        end
        
        -- Función para realizar la transferencia
        local function doTransfer(garageId, isPrivate, vehicleType, targetGarageType)
            if vehicleType and targetGarageType and vehicleType ~= targetGarageType then
                FrameworkBridge.ShowNotification(src, ('~r~No puedes transferir un vehículo tipo %s a un garaje tipo %s'):format(vehicleType, targetGarageType))
                return
            end
            
            if playerMoney >= transferPrice then
                FrameworkBridge.RemoveMoney(xPlayer, transferPrice)
                FrameworkBridge.ShowNotification(src, ('~y~Se cobraron $%s de tu efectivo'):format(transferPrice))
            else
                FrameworkBridge.RemoveBankMoney(xPlayer, transferPrice)
                FrameworkBridge.ShowNotification(src, ('~y~Se cobraron $%s de tu banco'):format(transferPrice))
            end
            
            local normalizedGarageId = isPrivate and ('private_%s'):format(garageId) or tostring(garageId)
            
            if isPrivate then
                MySQL.query('SELECT id FROM private_garages WHERE id = ? AND (owner = ? OR id IN (SELECT garage_id FROM private_garage_owners WHERE identifier = ?))', {
                    garageId, identifier, identifier
                }, function(accessCheck)
                    if not accessCheck or not accessCheck[1] then
                        TriggerClientEvent('esx:showNotification', src, '~r~No tienes acceso al garaje destino')
                        return
                    end
                    
                    MySQL.scalar('SELECT garage_id FROM owned_vehicles WHERE plate = ? AND owner = ?', { plate, identifier }, function(currentGarageId)
                        MySQL.update('UPDATE owned_vehicles SET garage_id = ?, in_garage = 1, engine = 1000, body = 1000, fuel = 100 WHERE plate = ? AND owner = ?', {
                            normalizedGarageId, plate, identifier
                        }, function(affectedRows)
                            if affectedRows > 0 then
                                LogVehicleTransfer(plate, identifier, identifier, currentGarageId or 'unknown', normalizedGarageId, 'garage')
                                TriggerClientEvent('esx:showNotification', src, '~g~Vehículo transferido al garaje exitosamente')
                                Citizen.SetTimeout(200, function()
                                    TriggerClientEvent('kr_garages:client:VehicleTransferred', src)
                                end)
                            else
                                TriggerClientEvent('esx:showNotification', src, '~r~Error: No se pudo transferir el vehículo')
                            end
                        end)
                    end)
                end)
            else
                MySQL.scalar('SELECT garage_id FROM owned_vehicles WHERE plate = ? AND owner = ?', { plate, identifier }, function(currentGarageId)
                    MySQL.update('UPDATE owned_vehicles SET garage_id = ?, in_garage = 1, engine = 1000, body = 1000, fuel = 100 WHERE plate = ? AND owner = ?', {
                        normalizedGarageId, plate, identifier
                    }, function(affectedRows)
                        if affectedRows > 0 then
                            LogVehicleTransfer(plate, identifier, identifier, currentGarageId or 'unknown', normalizedGarageId, 'garage')
                            TriggerClientEvent('esx:showNotification', src, '~g~Vehículo transferido al garaje exitosamente')
                            Citizen.SetTimeout(200, function()
                                TriggerClientEvent('kr_garages:client:VehicleTransferred', src)
                            end)
                        else
                            TriggerClientEvent('esx:showNotification', src, '~r~Error: No se pudo transferir el vehículo')
                        end
                    end)
                end)
            end
        end
        
        -- Obtener tipo de vehículo para validar compatibilidad
        MySQL.query('SELECT vehicle, in_garage FROM owned_vehicles WHERE plate = ? AND owner = ?', {
            plate, identifier
        }, function(vehRows)
            if not vehRows or not vehRows[1] then
                TriggerClientEvent('esx:showNotification', src, '~r~Vehículo no encontrado')
                return
            end
            
            local isOutside = (vehRows[1].in_garage == 0 or vehRows[1].in_garage == false)
            if isOutside then
                TriggerClientEvent('esx:showNotification', src, '~r~No puedes transferir un vehículo que está fuera del garaje. Debes guardarlo primero.')
                return
            end
            
            local vehicleType = nil
            if vehRows[1].vehicle then
                local ok, props = pcall(json.decode, vehRows[1].vehicle)
                if ok and props and props._vehicleType then
                    vehicleType = props._vehicleType
                end
            end
            
            local asNumber = tonumber(targetGarageId)
            
            if asNumber then
                local query = 'SELECT pg.type FROM private_garages pg LEFT JOIN private_garage_owners pgo ON pg.id = pgo.garage_id WHERE pg.id = ? AND (pg.owner = ? OR pgo.identifier = ?) LIMIT 1'
                local params = {asNumber, identifier, identifier}
                
                MySQL.query(query, params, function(result)
                    local pgType = result and result[1] and result[1].type or nil
                    if not pgType then
                        FrameworkBridge.ShowNotification(src, '~r~Garaje privado no encontrado o no tienes acceso')
                        return
                    end
                    doTransfer(asNumber, true, vehicleType, pgType)
                end)
            else
                local targetGarageType = nil
                local targetGarageData = nil
                if Config and Config.Garages then
                    for _, g in ipairs(Config.Garages) do
                        if g.id == targetGarageId then
                            targetGarageType = g.vehicleType or g.type
                            targetGarageData = g
                            break
                        end
                    end
                end
                
                if targetGarageData and targetGarageData.garageType == 'job' then
                    FrameworkBridge.ShowNotification(src, '~r~No puedes transferir vehículos a un garaje de trabajo')
                    return
                end
                
                doTransfer(targetGarageId, false, vehicleType, targetGarageType)
            end
        end)
    else
        FrameworkBridge.ShowNotification(src, '~r~Tipo de transferencia inválido')
    end
end)

-- ============================================
-- BRING VEHICLE HERE
-- ============================================

RegisterNetEvent('kr_garages:server:BringVehicleHere', function(plate, targetGarageId)
    local src = source
    local xPlayer = FrameworkBridge.GetPlayer(src)
    
    if not xPlayer then return end
    
    local identifier = GetPlayerIdentifier(xPlayer)
    local transferPrice = Config.TransferPrice or 500
    
    local playerMoney = FrameworkBridge.GetMoney(xPlayer)
    local playerBank = FrameworkBridge.GetBankMoney(xPlayer)
    
    if playerMoney < transferPrice and playerBank < transferPrice then
        FrameworkBridge.ShowNotification(src, ('~r~No tienes suficiente dinero. Necesitas $%s'):format(transferPrice))
        return
    end
    
    MySQL.query('SELECT plate, garage_id, in_garage FROM owned_vehicles WHERE plate = ? AND owner = ?', {
        plate, identifier
    }, function(rows)
        if not rows or not rows[1] then
            FrameworkBridge.ShowNotification(src, '~r~Vehículo no encontrado')
            return
        end
        
        local row = rows[1]
        
        if row.in_garage == 0 or row.in_garage == false then
            FrameworkBridge.ShowNotification(src, '~r~Este vehículo está fuera del garaje. Debes guardarlo primero.')
            return
        end
        
        local currentGarageId = tostring(row.garage_id)
        local targetGarageStr = tostring(targetGarageId)
        
        if currentGarageId == targetGarageStr then
            FrameworkBridge.ShowNotification(src, '~y~Este vehículo ya está en este garaje')
            return
        end
        
        if playerMoney >= transferPrice then
            FrameworkBridge.RemoveMoney(xPlayer, transferPrice)
            FrameworkBridge.ShowNotification(src, ('~y~Se cobraron $%s de tu efectivo'):format(transferPrice))
        else
            FrameworkBridge.RemoveBankMoney(xPlayer, transferPrice)
            FrameworkBridge.ShowNotification(src, ('~y~Se cobraron $%s de tu banco'):format(transferPrice))
        end
        
        MySQL.update('UPDATE owned_vehicles SET garage_id = ?, engine = 1000, body = 1000, fuel = 100 WHERE plate = ? AND owner = ?', {
            targetGarageStr, plate, identifier
        }, function(affectedRows)
            if affectedRows > 0 then
                FrameworkBridge.ShowNotification(src, '~g~Vehículo traído exitosamente a este garaje')
                
                if LogVehicleTransfer then
                    LogVehicleTransfer(plate, identifier, identifier, currentGarageId, targetGarageStr, 'garage')
                end
                
                Citizen.SetTimeout(200, function()
                    TriggerClientEvent('kr_garages:client:VehicleTransferred', src)
                end)
            else
                FrameworkBridge.ShowNotification(src, '~r~Error al transferir el vehículo')
            end
        end)
    end)
end)

-- ============================================
-- EVENTO CUANDO UN VEHÍCULO ES ELIMINADO
-- ============================================

RegisterNetEvent('kr_garages:server:VehicleDeleted')
AddEventHandler('kr_garages:server:VehicleDeleted', function(plate)
    local src = source
    local xPlayer = FrameworkBridge.GetPlayer(src)
    if not xPlayer then return end
    
    local identifier = GetPlayerIdentifier(xPlayer)
    
    -- Primero verificar si el vehículo aún existe en owned_vehicles
    -- (podría haber sido incautado/eliminado por otro sistema)
    MySQL.scalar('SELECT COUNT(*) FROM owned_vehicles WHERE plate = ? AND owner = ?', {
        plate, identifier
    }, function(count)
        if count and count > 0 then
            -- El vehículo existe, actualizarlo a guardado
            MySQL.update('UPDATE owned_vehicles SET in_garage = 1 WHERE plate = ? AND owner = ? AND in_garage = 0', {
                plate, identifier
            }, function(affectedRows)
                if affectedRows and affectedRows > 0 then
                    FrameworkBridge.ShowNotification(src, '~y~El vehículo fue devuelto al garaje automáticamente')
                end
                -- Si affectedRows es 0, significa que ya estaba guardado (in_garage = 1)
            end)
        end
        -- Si count es 0, el vehículo fue incautado/eliminado, no hacer nada
    end)
end)

-- ============================================
-- TRANSFER VEHICLE CALLBACK (Legacy)
-- ============================================

FrameworkBridge.RegisterCallback('kr_garages:server:TransferVehicle', function(source, cb, data)
    local xPlayer = FrameworkBridge.GetPlayer(source)
    if not xPlayer then return cb(false, 'Jugador inválido') end
    local identifier = GetPlayerIdentifier(xPlayer)

    local plate = data and data.plate
    if not plate or type(plate) ~= 'string' or plate:match('%S') == nil then
        return cb(false, 'Sin placa')
    end
    if #plate > 12 then return cb(false, 'Placa demasiado larga') end

    local TRANSFER_COST = Config.TransferPrice or 500

    MySQL.query('SELECT plate, in_garage FROM owned_vehicles WHERE plate = ? AND owner = ?', { plate, identifier }, function(rows)
        if not rows or not rows[1] then return cb(false, 'No eres dueño') end
        
        local isOutside = (rows[1].in_garage == 0 or rows[1].in_garage == false)
        if isOutside then
            return cb(false, 'No puedes transferir un vehículo que está fuera del garaje. Guárdalo primero.')
        end

        if data.targetIdentifier and data.targetIdentifier ~= '' then
            MySQL.scalar('SELECT identifier FROM users WHERE identifier = ? LIMIT 1', { data.targetIdentifier }, function(existing)
                if not existing then
                    return cb(false, 'Jugador objetivo no encontrado')
                end

                MySQL.update('UPDATE owned_vehicles SET owner = ?, garage_id = ?, engine = 1000, body = 1000, fuel = 100 WHERE plate = ? AND owner = ?', {
                    data.targetIdentifier, 'central_garage', plate, identifier
                }, function(aff)
                    cb(aff and aff > 0, aff and nil or 'No se transfirió')
                end)
            end)
            return
        end

        if data.targetGarageId then
            if FrameworkBridge.GetMoney(xPlayer) < TRANSFER_COST then
                return cb(false, 'No tienes suficiente dinero ($' .. TRANSFER_COST .. ')')
            end

            local gkey = GetGarageKey(data.targetGarageId)
            
            if type(data.targetGarageId) == 'number' then
                MySQL.query('SELECT id FROM private_garages WHERE id = ? AND JSON_CONTAINS(owners, JSON_QUOTE(?))', 
                    { data.targetGarageId, identifier },
                    function(garageRows)
                        if not garageRows or not garageRows[1] then
                            return cb(false, 'No tienes permisos en ese garaje privado')
                        end
                        
                        FrameworkBridge.RemoveMoney(xPlayer, TRANSFER_COST)
                        
                        MySQL.update('UPDATE owned_vehicles SET garage_id = ?, in_garage = 1, engine = 1000, body = 1000, fuel = 100 WHERE plate = ? AND owner = ?', {
                            gkey, plate, identifier
                        }, function(aff)
                            if aff and aff > 0 then
                                cb(true, 'Transferido a garaje privado. Costo: $' .. TRANSFER_COST)
                            else
                                FrameworkBridge.AddMoney(xPlayer, TRANSFER_COST)
                                cb(false, 'No se movió')
                            end
                        end)
                    end
                )
                return
            end
            
            FrameworkBridge.RemoveMoney(xPlayer, TRANSFER_COST)
            
            MySQL.update('UPDATE owned_vehicles SET garage_id = ?, in_garage = 1, engine = 1000, body = 1000, fuel = 100 WHERE plate = ? AND owner = ?', {
                gkey, plate, identifier
            }, function(aff)
                if aff and aff > 0 then
                    cb(true, 'Transferido. Costo: $' .. TRANSFER_COST)
                else
                    FrameworkBridge.AddMoney(xPlayer, TRANSFER_COST)
                    cb(false, 'No se movió')
                end
            end)
            return
        end

        cb(false, 'Datos incompletos')
    end)
end)
