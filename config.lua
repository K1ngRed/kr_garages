--[[
================================================================================
                                                                         
        ██╗  ██╗██╗███╗   ██╗ ██████╗     ██████╗ ███████╗██████╗        
        ██║ ██╔╝██║████╗  ██║██╔════╝     ██╔══██╗██╔════╝██╔══██╗       
        █████╔╝ ██║██╔██╗ ██║██║  ███╗    ██████╔╝█████╗  ██║  ██║       
        ██╔═██╗ ██║██║╚██╗██║██║   ██║    ██╔══██╗██╔══╝  ██║  ██║       
        ██║  ██╗██║██║ ╚████║╚██████╔╝    ██║  ██║███████╗██████╔╝       
        ╚═╝  ╚═╝╚═╝╚═╝  ╚═══╝ ╚═════╝     ╚═╝  ╚═╝╚══════╝╚═════╝        
                                                                         
             🔱 KR Garages - Sistema de Garajes Avanzado 🔱             
                                                                         
================================================================================
]]--

Config = {}

-- Framework: 'esx' o 'qb' (QBCore)
Config.Framework = 'esx'

Config.FuelSystem = 'ox_fuel' -- 'LegacyFuel', 'ox_fuel', 'esx_fuel', 'qb_fuel', 'native'
Config.Target = 'ox_target' -- 'ox_target', 'qb-target' o nil para markers
Config.Keys = 'esx_vehiclekeys' -- 'esx_vehiclekeys', 'qb-vehiclekeys', 'wasabi_carlock'

-- Idioma de la interfaz NUI
-- Opciones: 'es', 'en', 'pt', 'ru', 'fr', 'de', 'pl', 'it', 'tr'
Config.Locale = 'es'

Config.InteractionDistance = 3.0
Config.ImpoundPrice = 500
Config.TransferPrice = 500
Config.MaxStoreDistance = 50.0        -- Distancia máxima para poder guardar un vehículo (metros)

-- Sistema de vehículos abandonados
Config.AbandonedVehicles = {
    Enabled = true,                    -- Activar sistema de detección de vehículos abandonados
    MaxDistance = 150.0,               -- Distancia máxima del garaje para considerar que está "cerca" (metros)
    AbandonedDistance = 500.0,         -- Distancia a partir de la cual se considera abandonado (metros)
    CheckInterval = 60000,             -- Intervalo de verificación (60 segundos)
    InactiveTime = 300000,             -- Tiempo sin conductor para considerar inactivo (5 minutos)
    AutoReturnDestroyed = true,        -- Devolver automáticamente vehículos destruidos
    AutoReturnAbandoned = true,        -- Devolver automáticamente vehículos abandonados
}

-- Sistema de reparación
Config.RepairSystem = {
    Enabled = true,                    -- Activar sistema de reparación
    RepairPrice = 100,                 -- Precio base de reparación ($50-2000)
    PricePerDamage = 15,               -- Precio adicional por cada % de daño
    MaxRepairCost = 2000,              -- Precio máximo de reparación
    RecoverPrice = 500,                -- Precio para recuperar vehículo que está en el mundo (spawneado lejos)
}

-- Grupos permitidos para gestionar garajes privados (comando /misgarajes)
Config.AdminGroups = {
    'admin',
    'superadmin',
    'owner'
}

-- ============================================
-- GARAJES PÚBLICOS
-- ============================================
-- Usa el comando /gpublicoadmin para crear, editar y eliminar garajes públicos
-- 

Config.Garages = {}

-- ============================================
-- IMPOUNDS (Depósitos de vehículos)
-- ============================================

-- Trabajos que pueden confiscar vehículos (comando /confiscar)
Config.ImpoundJobs = {
    'police',
    'sheriff',
    'mechanic'  -- Si quieres que los mecánicos también puedan
}

-- Configuración del sistema de impound
Config.ImpoundSettings = {
    DefaultFee = 500,       -- Tarifa por defecto
    MinFee = 100,           -- Tarifa mínima
    MaxFee = 10000,         -- Tarifa máxima
    NotifyOwner = true      -- Notificar al dueño cuando su vehículo sea confiscado
}

-- Razones predefinidas para confiscar (aparecen en el menú)
Config.ImpoundReasons = {
    'Estacionamiento ilegal',
    'Vehículo abandonado',
    'Vehículo robado',
    'Infracción de tráfico',
    'Evidencia de crimen',
    'Vehículo sin seguro',
    'Conducción peligrosa',
    'Otro'
}

Config.Impounds = {
    {
        id = 'impound_a',
        name = 'Depósito Central',
        coords = vector3(410.8, -1626.26, 29.29),
        spawnPoints = {
            vector4(408.44, -1630.88, 29.29, 136.88),
        },
        -- Configuración del NPC
        ped = {
            model = 's_m_y_cop_01',           -- Modelo del policía
            coords = vector4(409.5, -1622.5, 29.29, 230.0), -- Posición y rotación del NPC
            scenario = 'WORLD_HUMAN_CLIPBOARD' -- Animación del NPC
        },
        -- Blip en el mapa
        blip = {
            sprite = 524,  -- Impound lot icon
            color = 40,    -- Amarillo
            scale = 0.8,
            display = 4,   -- Visible en mapa
            shortRange = true
        }
    },
    {
        id = 'impound_b',
        name = 'Depósito Sandy Shores',
        coords = vector3(1649.71, 3789.61, 34.79),
        spawnPoints = {
            vector4(1643.66, 3798.36, 34.49, 216.16),
        },
        -- Configuración del NPC
        ped = {
            model = 's_m_y_sheriff_01',       -- Sheriff para Sandy
            coords = vector4(1648.5, 3789.0, 34.79, 50.0),
            scenario = 'WORLD_HUMAN_CLIPBOARD'
        },
        -- Blip en el mapa
        blip = {
            sprite = 524,
            color = 40,
            scale = 0.8,
            display = 4,
            shortRange = true
        }
    }
}
