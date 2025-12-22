-- server/vehicle_utils.lua
-- Funciones de utilidad para vehículos

-- ============================================
-- CLASIFICACIÓN DE VEHÍCULOS POR CLASE GTA V
-- ============================================

function GetVehicleTypeByClass(vehClass)
    if not vehClass then return nil end
    local class = tonumber(vehClass)
    
    -- Boats (14)
    if class == 14 then return 'boat' end
    
    -- Helicopters (15) y Planes (16)
    if class == 15 or class == 16 then return 'air' end
    
    -- Todo lo demás son cars (incluye motos clase 8 y bicicletas clase 13)
    return 'car'
end

-- Verifica si un tipo de vehículo es compatible con un tipo de garaje
function IsVehicleTypeCompatible(vehicleType, garageType)
    if not garageType or garageType == '' then return true end
    if not vehicleType then return true end
    return vehicleType == garageType
end

-- ============================================
-- CONVERSIÓN DE MODELOS
-- ============================================

-- Convertir hash de modelo a nombre (servidor)
function GetVehicleModelName(model)
    -- Si ya es un string, devolverlo limpio
    if type(model) == 'string' then
        local cleanName = model:gsub("^%l", string.upper):gsub("[^%w%s%-]", "")
        return cleanName
    end
    
    -- Si no es un número, retornar unknown
    if type(model) ~= 'number' then
        return 'Unknown Vehicle'
    end
    
    -- El servidor no puede resolver hashes, el cliente se encarga
    return 'Vehicle #' .. tostring(model)
end

-- Generar nombre legible desde spawn name
function GenerateVehicleLabel(name)
    if not name then return 'Unknown Vehicle' end
    
    -- Remover números al final (ej: banshee2 -> banshee)
    local cleanName = name:gsub('%d+$', '')
    
    -- Capitalizar primera letra de cada palabra, reemplazar _ por espacio
    local label = cleanName:gsub("^%l", string.upper):gsub("_(.)", function(c) 
        return " " .. string.upper(c) 
    end)
    
    return label
end

-- ============================================
-- GENERACIÓN DE PLACAS
-- ============================================

function GenerateRandomPlate()
    local chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'
    local plate = ''
    for i = 1, 8 do
        local randomIndex = math.random(1, #chars)
        plate = plate .. chars:sub(randomIndex, randomIndex)
    end
    return plate
end

function PlateExists(plate, cb)
    MySQL.scalar('SELECT COUNT(*) FROM owned_vehicles WHERE plate = ?', {plate}, function(count)
        cb(count and count > 0)
    end)
end

function GenerateUniquePlate(cb)
    local attempts = 0
    local maxAttempts = 10
    
    local function tryGenerate()
        attempts = attempts + 1
        local plate = GenerateRandomPlate()
        
        PlateExists(plate, function(exists)
            if not exists then
                cb(plate)
            elseif attempts < maxAttempts then
                tryGenerate()
            else
                cb(nil)
            end
        end)
    end
    
    tryGenerate()
end
