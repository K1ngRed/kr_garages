--[[
    framework/client.lua
    Bridge de framework para cliente
    
    NO MODIFICAR SI NO SABES LO QUE ESTAS HACIENDO
    Abstracción ESX/QB-Core - cambiar esto rompe todo
--]]

local Core = nil
local PlayerData = {}

-- Cleanup al reiniciar recurso
AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    FrameworkBridge = nil
end)

FrameworkBridge = {}

-- Esperar Config
while not Config do Wait(50) end

-- Inicializar Core
if Framework.IsQB() then
    Core = exports['qb-core']:GetCoreObject()
    
    RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
        PlayerData = Core.Functions.GetPlayerData()
        Wait(500)
        if CreateGarageBlips then CreateGarageBlips() end
    end)
    
    RegisterNetEvent('QBCore:Client:OnJobUpdate', function(job)
        PlayerData.job = job
    end)
    
    RegisterNetEvent('QBCore:Client:OnGangUpdate', function(gang)
        PlayerData.gang = gang
    end)
else
    -- ESX
    Core = exports["es_extended"]:getSharedObject()
    PlayerData = Core.GetPlayerData()
    
    RegisterNetEvent('esx:playerLoaded', function(xPlayer)
        PlayerData = xPlayer
        Wait(500)
        if CreateGarageBlips then CreateGarageBlips() end
    end)
    
    RegisterNetEvent('esx:setJob', function(job)
        PlayerData.job = job
    end)
    
    -- Obtener datos al reconectar
    CreateThread(function()
        local attempts = 0
        while (not PlayerData or not PlayerData.job) and attempts < 50 do
            Wait(100)
            PlayerData = Core.GetPlayerData()
            attempts = attempts + 1
        end
        Wait(500)
        if CreateGarageBlips then CreateGarageBlips() end
    end)
end

-- Funciones del bridge
function FrameworkBridge.GetPlayerData()
    return Framework.IsQB() and Core.Functions.GetPlayerData() or PlayerData
end

function FrameworkBridge.ShowNotification(message)
    if Framework.IsQB() then
        Core.Functions.Notify(message, 'primary', 5000)
    else
        TriggerEvent('esx:showNotification', message)
    end
end

function FrameworkBridge.ShowHelpNotification(message)
    if Framework.IsQB() then
        exports['qb-core']:DrawText(message, 'left')
    else
        BeginTextCommandDisplayHelp('STRING')
        AddTextComponentSubstringPlayerName(message)
        EndTextCommandDisplayHelp(0, false, true, -1)
    end
end

function FrameworkBridge.HideHelpNotification()
    if Framework.IsQB() then
        exports['qb-core']:HideText()
    else
        EndTextCommandDisplayHelp(0, false, false, -1)
    end
end

function FrameworkBridge.TriggerCallback(name, cb, ...)
    if Framework.IsQB() then
        Core.Functions.TriggerCallback(name, cb, ...)
    else
        Core.TriggerServerCallback(name, cb, ...)
    end
end

function FrameworkBridge.GetVehicleProperties(vehicle)
    if Framework.IsQB() then
        return Core.Functions.GetVehicleProperties(vehicle)
    else
        return Core.Game.GetVehicleProperties(vehicle)
    end
end

function FrameworkBridge.SetVehicleProperties(vehicle, props)
    if Framework.IsQB() then
        Core.Functions.SetVehicleProperties(vehicle, props)
    else
        Core.Game.SetVehicleProperties(vehicle, props)
    end
end

function FrameworkBridge.SpawnVehicle(model, coords, heading, cb)
    if Framework.IsQB() then
        Core.Functions.SpawnVehicle(model, cb, coords, true)
    else
        Core.Game.SpawnVehicle(model, coords, heading, cb)
    end
end

function FrameworkBridge.DeleteVehicle(vehicle)
    if Framework.IsQB() then
        Core.Functions.DeleteVehicle(vehicle)
    else
        Core.Game.DeleteVehicle(vehicle)
    end
end

function FrameworkBridge.GetPlate(vehicle)
    local plate = GetVehicleNumberPlateText(vehicle)
    if Framework.IsQB() then
        return Core.Shared.Trim(plate)
    else
        return Framework.Trim(plate)
    end
end

function FrameworkBridge.IsSpawnPointClear(coords, radius)
    if Framework.IsQB() then
        return Core.Functions.IsSpawnPointClear(coords, radius)
    else
        return Core.Game.IsSpawnPointClear(coords, radius)
    end
end

function FrameworkBridge.GetJobName()
    local data = FrameworkBridge.GetPlayerData()
    return data.job and data.job.name or nil
end

function FrameworkBridge.GetGangName()
    local data = FrameworkBridge.GetPlayerData()
    return data.gang and data.gang.name or nil
end

exports('GetFrameworkBridge', function()
    return FrameworkBridge
end)
