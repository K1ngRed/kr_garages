-- kr_garages - GPL-3.0
-- Copyright (C) 2025 K1ngRed
-- This program is free software: you can redistribute it and/or modify
-- it under the terms of the GNU General Public License as published by
-- the Free Software Foundation, either version 3 of the License, or
-- (at your option) any later version.
-- This program is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the LICENSE file.

--[[
    server/core.lua
    Funciones y utilidades del servidor
    
    NO MODIFICAR SI NO SABES LO QUE ESTAS HACIENDO
    Contiene helpers críticos usados en todo el servidor
--]]

-- Esperar framework
while not FrameworkBridge do Wait(100) end

-- Helpers básicos
function GetPlayerIdentifier(xPlayer)
    return FrameworkBridge.GetIdentifier(xPlayer)
end

-- Log de transferencias
function LogVehicleTransfer(plate, fromIdentifier, toIdentifier, fromGarage, toGarage, transferType)
    MySQL.insert('INSERT INTO vehicle_transfer_logs (plate, from_identifier, to_identifier, from_garage, to_garage, transfer_type) VALUES (?, ?, ?, ?, ?, ?)', {
        plate,
        fromIdentifier,
        toIdentifier or fromIdentifier,
        fromGarage or 'unknown',
        toGarage or 'unknown',
        transferType
    })
end

-- Clave de garaje normalizada
function GetGarageKey(garageId)
    if type(garageId) == 'number' then
        return ('private_%s'):format(garageId)
    end
    if type(garageId) == 'string' and garageId ~= '' then
        return garageId
    end
    return 'central_garage'
end

-- Tipo de garaje privado
function GetPrivateGarageType(garageId, cb)
    if type(garageId) ~= 'number' then return cb(nil) end
    MySQL.scalar('SELECT type FROM private_garages WHERE id = ?', { garageId }, function(t)
        cb(t)
    end)
end

-- Cache de grupos admin
ADMIN_GROUPS_CACHE = {}
for _, group in ipairs(Config.AdminGroups or {'admin', 'superadmin'}) do
    ADMIN_GROUPS_CACHE[group] = true
end

function IsPlayerAdmin(xPlayer)
    if not xPlayer then return false end
    local group = FrameworkBridge.GetGroup(xPlayer)
    return ADMIN_GROUPS_CACHE[group] == true
end

--[[
    Cálculo de costo de reparación
    NO MODIFICAR - Lógica de precios del sistema
--]]
function CalculateRepairCost(engineHealth, bodyHealth, fuel, inGarage, existsInWorld)
    engineHealth = (engineHealth ~= nil) and tonumber(engineHealth) or 1000
    bodyHealth = (bodyHealth ~= nil) and tonumber(bodyHealth) or 1000
    fuel = (fuel ~= nil) and tonumber(fuel) or 100
    
    local isDestroyed = (engineHealth <= 0 and bodyHealth <= 0 and fuel <= 0)
    
    local hasEngineDamage = (engineHealth < 1000)
    local hasBodyDamage = (bodyHealth < 1000)
    local hasFuelLoss = (fuel < 100)
    local hasDamage = (hasEngineDamage or hasBodyDamage or hasFuelLoss)
    local onlyFuelDamage = (hasFuelLoss and not hasEngineDamage and not hasBodyDamage)
    
    if not hasDamage and inGarage then
        return 0, false, false
    end
    
    local fuelOnlyPrice = Config.RepairSystem.RecoverPrice or 750
    
    local engineDamage = math.max(0, 100 - (engineHealth / 10))
    local bodyDamage = math.max(0, 100 - (bodyHealth / 10))
    local fuelDamage = math.max(0, 100 - fuel)
    local totalDamage = (engineDamage + bodyDamage + fuelDamage) / 3
    
    local repairCost = 0
    
    if isDestroyed or (not inGarage and not existsInWorld) then
        repairCost = Config.RepairSystem.MaxRepairCost
    elseif onlyFuelDamage then
        repairCost = fuelOnlyPrice
    elseif existsInWorld then
        if hasDamage then
            repairCost = Config.RepairSystem.RepairPrice + (totalDamage * Config.RepairSystem.PricePerDamage)
            repairCost = math.min(repairCost, Config.RepairSystem.MaxRepairCost)
        else
            repairCost = fuelOnlyPrice
        end
    elseif hasDamage then
        repairCost = Config.RepairSystem.RepairPrice + (totalDamage * Config.RepairSystem.PricePerDamage)
        repairCost = math.min(repairCost, Config.RepairSystem.MaxRepairCost)
    end
    
    return math.floor(repairCost), isDestroyed, hasDamage
end
