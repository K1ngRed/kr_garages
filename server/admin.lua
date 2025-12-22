--[[
    server/admin.lua
    Panel admin de garajes públicos
    
    NO MODIFICAR SI NO SABES LO QUE ESTAS HACIENDO
    Solo admins autorizados pueden usar estas funciones
--]]

RegisterNetEvent('kr_garages:server:SavePublicGarage')
AddEventHandler('kr_garages:server:SavePublicGarage', function(garageData, isEdit)
    local src = source
    local xPlayer = FrameworkBridge.GetPlayer(src)
    if not xPlayer then return end
    
    local group = FrameworkBridge.GetGroup(xPlayer)
    if not ADMIN_GROUPS_CACHE[group] then
        TriggerClientEvent('kr_garages:client:PublicGarageSaved', src, false, 'No tienes permisos de administrador')
        return
    end
    
    if not garageData or not garageData.id or not garageData.name then
        TriggerClientEvent('kr_garages:client:PublicGarageSaved', src, false, 'Datos del garaje incompletos')
        return
    end
    
    local identifier = GetPlayerIdentifier(xPlayer)
    local spawnPointsJson = json.encode(garageData.spawnPoints or {})
    
    if isEdit then
        MySQL.update('UPDATE public_garages SET name = ?, type = ?, coord_x = ?, coord_y = ?, coord_z = ?, radius = ?, spawn_points = ?, blip_sprite = ?, blip_color = ?, blip_scale = ? WHERE id = ?', {
            garageData.name,
            garageData.type or 'car',
            garageData.coords and garageData.coords.x or 0,
            garageData.coords and garageData.coords.y or 0,
            garageData.coords and garageData.coords.z or 0,
            garageData.radius or 15.0,
            spawnPointsJson,
            garageData.blip and garageData.blip.sprite or 357,
            garageData.blip and garageData.blip.color or 47,
            garageData.blip and garageData.blip.scale or 0.6,
            garageData.id
        }, function(affectedRows)
            if affectedRows > 0 then
                if Config and Config.Garages then
                    for i, g in ipairs(Config.Garages) do
                        if g.id == garageData.id then
                            Config.Garages[i] = {
                                id = garageData.id,
                                name = garageData.name,
                                type = garageData.type or 'car',
                                garageType = 'public',
                                coords = vector3(garageData.coords.x or 0, garageData.coords.y or 0, garageData.coords.z or 0),
                                radius = garageData.radius or 15.0,
                                spawnPoints = (function()
                                    local sps = {}
                                    for _, sp in ipairs(garageData.spawnPoints or {}) do
                                        table.insert(sps, vector4(sp.x or 0, sp.y or 0, sp.z or 0, sp.heading or 0))
                                    end
                                    return sps
                                end)(),
                                blip = garageData.blip or {sprite = 357, color = 47, scale = 0.6}
                            }
                            break
                        end
                    end
                end
                
                print('[kr_garages] ADMIN ' .. FrameworkBridge.GetPlayerName(xPlayer) .. ' actualizó garaje público: ' .. garageData.id)
                TriggerClientEvent('kr_garages:client:PublicGarageSaved', src, true, 'Garaje actualizado correctamente')
                RefreshCacheAndNotifyClients()
            else
                TriggerClientEvent('kr_garages:client:PublicGarageSaved', src, false, 'Error al actualizar el garaje')
            end
        end)
    else
        MySQL.insert('INSERT INTO public_garages (id, name, type, coord_x, coord_y, coord_z, radius, spawn_points, blip_sprite, blip_color, blip_scale, created_by) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)', {
            garageData.id,
            garageData.name,
            garageData.type or 'car',
            garageData.coords and garageData.coords.x or 0,
            garageData.coords and garageData.coords.y or 0,
            garageData.coords and garageData.coords.z or 0,
            garageData.radius or 15.0,
            spawnPointsJson,
            garageData.blip and garageData.blip.sprite or 357,
            garageData.blip and garageData.blip.color or 47,
            garageData.blip and garageData.blip.scale or 0.6,
            identifier
        }, function(insertId)
            if insertId then
                if Config and Config.Garages then
                    table.insert(Config.Garages, {
                        id = garageData.id,
                        name = garageData.name,
                        type = garageData.type or 'car',
                        garageType = 'public',
                        coords = vector3(garageData.coords.x or 0, garageData.coords.y or 0, garageData.coords.z or 0),
                        radius = garageData.radius or 15.0,
                        spawnPoints = (function()
                            local sps = {}
                            for _, sp in ipairs(garageData.spawnPoints or {}) do
                                table.insert(sps, vector4(sp.x or 0, sp.y or 0, sp.z or 0, sp.heading or 0))
                            end
                            return sps
                        end)(),
                        blip = garageData.blip or {sprite = 357, color = 47, scale = 0.6}
                    })
                end
                
                print('[kr_garages] ADMIN ' .. FrameworkBridge.GetPlayerName(xPlayer) .. ' creó garaje público: ' .. garageData.id)
                TriggerClientEvent('kr_garages:client:PublicGarageSaved', src, true, 'Garaje creado correctamente')
                RefreshCacheAndNotifyClients()
            else
                TriggerClientEvent('kr_garages:client:PublicGarageSaved', src, false, 'Error al crear el garaje (¿ID duplicado?)')
            end
        end)
    end
end)

-- ============================================
-- ELIMINAR GARAJE PÚBLICO
-- ============================================

RegisterNetEvent('kr_garages:server:DeletePublicGarage')
AddEventHandler('kr_garages:server:DeletePublicGarage', function(garageId)
    local src = source
    local xPlayer = FrameworkBridge.GetPlayer(src)
    if not xPlayer then return end
    
    local group = FrameworkBridge.GetGroup(xPlayer)
    if not ADMIN_GROUPS_CACHE[group] then
        TriggerClientEvent('kr_garages:client:PublicGarageDeleted', src, false, 'No tienes permisos de administrador')
        return
    end
    
    MySQL.query('DELETE FROM public_garages WHERE id = ?', {garageId}, function(result)
        if result and result.affectedRows > 0 then
            if Config and Config.Garages then
                for i, g in ipairs(Config.Garages) do
                    if g.id == garageId then
                        table.remove(Config.Garages, i)
                        break
                    end
                end
            end
            
            print('[kr_garages] ADMIN ' .. FrameworkBridge.GetPlayerName(xPlayer) .. ' eliminó garaje público: ' .. tostring(garageId))
            
            TriggerClientEvent('kr_garages:client:PublicGarageDeleted', -1, garageId)
            RefreshCacheAndNotifyClients()
            
            TriggerClientEvent('kr_garages:client:PublicGarageSaved', src, true, 'Garaje eliminado correctamente')
        else
            TriggerClientEvent('kr_garages:client:PublicGarageSaved', src, false, 'El garaje no existe en la base de datos')
        end
    end)
end)
