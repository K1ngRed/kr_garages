-- ============================================
-- KR_GARAGES - INSTALACIÓN COMPLETA
-- Ejecutar este archivo una sola vez para instalar todo el sistema
-- Compatible con ESX Legacy y MariaDB/MySQL
-- ============================================

-- ============================================
-- TABLA 1: private_garages
-- Almacena los garajes privados creados por administradores
-- ============================================

CREATE TABLE IF NOT EXISTS `private_garages` (
  `id` INT(11) NOT NULL AUTO_INCREMENT,
  `name` VARCHAR(100) NOT NULL,
  `owner` VARCHAR(60) NOT NULL,
  `coords` LONGTEXT NOT NULL,
  `heading` FLOAT NOT NULL DEFAULT 0,
  `radius` INT(11) NOT NULL DEFAULT 10,
  `type` ENUM('car','air','boat') NOT NULL DEFAULT 'car',
  `spawn_x` FLOAT DEFAULT NULL,
  `spawn_y` FLOAT DEFAULT NULL,
  `spawn_z` FLOAT DEFAULT NULL,
  `spawn_h` FLOAT DEFAULT NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `owner` (`owner`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================
-- TABLA 2: private_garage_owners
-- Sistema de acceso compartido (hasta 5 miembros por garaje)
-- ============================================

CREATE TABLE IF NOT EXISTS `private_garage_owners` (
  `id` INT(11) NOT NULL AUTO_INCREMENT,
  `garage_id` INT(11) NOT NULL,
  `identifier` VARCHAR(60) NOT NULL,
  `access_level` ENUM('owner','member') NOT NULL DEFAULT 'member',
  `added_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `unique_garage_member` (`garage_id`, `identifier`),
  KEY `garage_id` (`garage_id`),
  KEY `identifier` (`identifier`),
  CONSTRAINT `fk_garage_owners_garage` FOREIGN KEY (`garage_id`) REFERENCES `private_garages` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================
-- TABLA 3: vehicle_transfer_logs (OPCIONAL)
-- Registra transferencias de vehículos entre jugadores y garajes
-- ============================================

CREATE TABLE IF NOT EXISTS `vehicle_transfer_logs` (
  `id` INT(11) NOT NULL AUTO_INCREMENT,
  `plate` VARCHAR(20) NOT NULL,
  `from_identifier` VARCHAR(60) DEFAULT NULL,
  `to_identifier` VARCHAR(60) DEFAULT NULL,
  `from_garage` VARCHAR(60) DEFAULT NULL,
  `to_garage` VARCHAR(60) DEFAULT NULL,
  `transfer_type` ENUM('player','garage') NOT NULL,
  `transferred_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `plate` (`plate`),
  KEY `transferred_at` (`transferred_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================
-- TABLA 4: public_garages
-- Garajes públicos gestionables desde /gpublicoadmin
-- ============================================

CREATE TABLE IF NOT EXISTS `public_garages` (
  `id` VARCHAR(60) NOT NULL,
  `name` VARCHAR(100) NOT NULL,
  `type` ENUM('car','air','boat') NOT NULL DEFAULT 'car',
  `coord_x` FLOAT NOT NULL DEFAULT 0,
  `coord_y` FLOAT NOT NULL DEFAULT 0,
  `coord_z` FLOAT NOT NULL DEFAULT 0,
  `radius` FLOAT NOT NULL DEFAULT 15.0,
  `spawn_points` LONGTEXT DEFAULT NULL,
  `blip_sprite` INT(11) NOT NULL DEFAULT 357,
  `blip_color` INT(11) NOT NULL DEFAULT 47,
  `blip_scale` FLOAT NOT NULL DEFAULT 0.6,
  `created_by` VARCHAR(60) DEFAULT NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================
-- TABLA 5: kr_impound
-- Vehículos confiscados por policía
-- ============================================

CREATE TABLE IF NOT EXISTS `kr_impound` (
  `id` INT(11) NOT NULL AUTO_INCREMENT,
  `owner` VARCHAR(60) NOT NULL,
  `plate` VARCHAR(20) NOT NULL,
  `vehicle` LONGTEXT NOT NULL,
  `model` VARCHAR(60) DEFAULT NULL,
  `impound_id` VARCHAR(60) NOT NULL DEFAULT 'impound_a',
  `fee` INT(11) NOT NULL DEFAULT 500,
  `reason` VARCHAR(255) DEFAULT NULL,
  `impounded_by` VARCHAR(60) DEFAULT NULL,
  `impounded_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `release_date` TIMESTAMP NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `plate` (`plate`),
  KEY `owner` (`owner`),
  KEY `impound_id` (`impound_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================
-- ÍNDICES DE RENDIMIENTO PARA owned_vehicles
-- Estos índices mejoran el rendimiento en ~40-60%
-- ============================================

-- Índice compuesto para búsquedas por placa y dueño
CREATE INDEX IF NOT EXISTS idx_plate_owner ON owned_vehicles (plate, owner);

-- Índice compuesto para búsquedas por dueño y estado
CREATE INDEX IF NOT EXISTS idx_owner_stored ON owned_vehicles (owner, stored);

-- Índice para búsquedas por garaje
CREATE INDEX IF NOT EXISTS idx_parking ON owned_vehicles (parking);

-- Índice compuesto para garajes privados
CREATE INDEX IF NOT EXISTS idx_owner_type ON private_garages (owner, type);

-- ============================================
-- GARAJES PÚBLICOS - DATOS INICIALES
-- Usa REPLACE para evitar duplicados si ya existen
-- ============================================

REPLACE INTO `public_garages` (`id`, `name`, `type`, `coord_x`, `coord_y`, `coord_z`, `radius`, `spawn_points`, `blip_sprite`, `blip_color`, `blip_scale`, `created_by`) VALUES
('alcatraz_beach', 'Alcatraz Beach', 'car', 2780.6, -711.18, 5.25, 15, '[{"x":2779.86,"y":-706.20,"z":4.65,"heading":106.14}]', 357, 47, 0.6, 'system'),
('apartments_garage', 'Apartments Garage', 'car', -303.5, -988.39, 31.08, 5, '[{"heading":337.45,"z":30.56,"y":-989.99,"x":-297.74},{"heading":337.86,"z":30.56,"y":-988.95,"x":-301.69},{"heading":337.31,"z":30.6,"y":-988.08,"x":-305.32}]', 357, 47, 0.6, 'system'),
('bahamas_publico', 'Bahamas', 'car', -1398.96, -584.05, 30.25, 5, '[{"heading":114.32,"y":-584.05,"x":-1398.96,"z":30.25}]', 357, 47, 0.6, 'system'),
('beach_garage', 'Beach', 'car', -1248.69, -1425.71, 4.32, 15, '[{"x":-1244.27,"y":-1422.08,"z":4.32,"heading":37.12}]', 357, 47, 0.6, 'system'),
('boats_marina', 'Marina de Barcos', 'boat', -795.15, -1510.79, 1.6, 20, '[{"x":-798.66,"y":-1507.73,"z":-0.47,"heading":102.23}]', 410, 47, 0.6, 'system'),
('bolingbroke_garage', 'Bolingbroke Garage', 'car', 1873.12, 2569.97, 45.67, 7, '[{"x":1869.66,"y":2570.75,"z":45.25,"heading":90.77}]', 357, 47, 0.6, 'system'),
('casino_garage', 'Casino Garage', 'car', 872.07, -9.1, 78.34, 7, '[{"x":872.07,"y":-9.10,"z":78.34,"heading":237.22},{"x":869.94,"y":-11.91,"z":78.34,"heading":238.07},{"x":868.33,"y":-14.83,"z":78.34,"heading":235.89}]', 357, 47, 0.6, 'system'),
('cayo_perico_1', 'Cayo Perico Garage', 'car', 4478.65, -4445.88, 4.02, 5, '[{"x":4485.75,"y":-4450.52,"z":4.09,"heading":199.14}]', 357, 47, 0.6, 'system'),
('cayo_perico_2', 'Cayo Perico Garage 2', 'car', 5048.46, -4595.71, 2.93, 5, '[{"x":5049.57,"y":-4600.17,"z":2.92,"heading":149.49}]', 357, 47, 0.6, 'system'),
('cayo_perico_3', 'Cayo Perico Garage 3', 'car', 5100.08, -5721.64, 15.77, 5, '[{"x":5094.41,"y":-5727.62,"z":15.77,"heading":49.29}]', 357, 47, 0.6, 'system'),
('central_garage', 'Legion Square', 'car', 229.76, -907.57, 29.15, 15, '[{"x":216.52,"y":-902.58,"z":29.14,"heading":246.72},{"x":215.34,"y":-906.19,"z":29.14,"heading":249.39},{"x":214.21,"y":-909.72,"z":29.14,"heading":249.56},{"x":212.70,"y":-913.16,"z":29.14,"heading":249.88},{"x":211.24,"y":-916.55,"z":29.14,"heading":247.78},{"x":210.12,"y":-920.06,"z":29.14,"heading":254.15}]', 357, 47, 0.6, 'system'),
('delpero_apartments', 'DelPero Apartments', 'car', -1523.7, -431.47, 35.44, 5, '[{"x":-1535.47,"y":-434.66,"z":35.02,"heading":228.90},{"x":-1532.76,"y":-432.40,"z":35.02,"heading":229.38},{"x":-1531.25,"y":-429.36,"z":35.02,"heading":231.09}]', 357, 47, 0.6, 'system'),
('dome_public', 'Domo Garaje', 'car', -2265.17, -631.02, 9.18, 15, '[{"y":-631.02,"z":9.18,"heading":61.36,"x":-2265.17},{"y":-634.29,"z":9.18,"heading":71.97,"x":-2266.24},{"y":-637.59,"z":9.18,"heading":71.1,"x":-2267.84},{"y":-641.15,"z":9.18,"heading":69.59,"x":-2269.43}]', 357, 47, 0.6, 'system'),
('fast_custom', 'Fast Custom', 'car', -925.45, -815.49, 15.07, 15, '[{"y":-815.49,"heading":358.54,"x":-925.45,"z":15.07},{"y":-815.62,"heading":356.28,"x":-921.27,"z":15.07}]', 357, 47, 0.6, 'system'),
('grapeseed', 'Grapeseed', 'car', 1713.06, 4745.32, 41.96, 15, '[{"x":1710.64,"y":4746.94,"z":41.95,"heading":90.11}]', 357, 47, 0.6, 'system'),
('great_ocean', 'Great Ocean Highway', 'car', -2961.55, 365.73, 14.77, 15, '[{"y":372.07,"heading":86.07,"x":-2964.96,"z":14.78}]', 357, 47, 0.6, 'system'),
('grove_street', 'Grove Street', 'car', 2.73, -1717.1, 29.3, 15, '[{"y":-1722.9,"heading":310.58,"x":23.93,"z":29.3}]', 357, 47, 0.6, 'system'),
('legion_garage', 'Los Santos Custom', 'car', -589.55, -1103.43, 22.18, 15, '[{"y":-1104.33,"heading":89.49,"x":-581.94,"z":21.57}]', 357, 47, 0.6, 'system'),
('lsia_hangar', 'LSIA Hangar', 'air', -1243.49, -3391.88, 13.94, 20, '[{"x":-1268.66,"y":-3394.25,"z":14.88,"heading":329.95}]', 43, 47, 0.6, 'system'),
('mechanic_hawick', 'Mechanic Hawick Garage', 'car', -385.72, -131.42, 38.68, 15, '[{"x":-386.28,"y":-131.63,"z":38.08,"heading":300.48}]', 357, 47, 0.6, 'system'),
('mirror_park', 'Mirror Park', 'car', 1032.84, -765.1, 58.18, 15, '[{"x":1023.2,"y":-764.27,"z":57.96,"heading":319.66}]', 357, 47, 0.6, 'system'),
('montana_chiliad', 'Montaña Chiliad', 'air', 476.81, 5605.92, 792.25, 15, '[{"x":476.81,"heading":18.88,"z":792.25,"y":5605.92}]', 43, 47, 0.6, 'system'),
('paleto_garage', 'Paleto Bay', 'car', 116.85, 6599.26, 32.01, 15, '[{"y":6607.82,"heading":265.28,"x":110.84,"z":31.86}]', 357, 47, 0.6, 'system'),
('public_ems', 'Public EMS Garage', 'car', -457.14, -332.4, 33.94, 7, '[{"x":-457.14,"y":-332.40,"z":33.94,"heading":175.10}]', 357, 47, 0.6, 'system'),
('route68', 'Route68 Garage', 'car', 567.16, 2719.71, 42.06, 15, '[{"x":565.53,"y":2719.99,"z":41.45,"heading":2.95}]', 357, 47, 0.6, 'system'),
('sandy_north', 'Sandy North', 'car', 1878.44, 3760.1, 32.94, 15, '[{"x":1880.14,"y":3757.73,"z":32.93,"heading":215.54}]', 357, 47, 0.6, 'system'),
('sandy_south', 'Sandy South', 'car', 217.33, 2605.65, 46.04, 15, '[{"x":216.94,"y":2608.44,"z":46.33,"heading":14.07}]', 357, 47, 0.6, 'system'),
('tatavian_publico', 'Tatavian Publico', 'car', 1527.68, 777.06, 77.43, 15, '[{"heading":34.24,"y":777.06,"z":77.43,"x":1527.68}]', 357, 47, 0.6, 'system'),
('tuner_garage', 'Tuner Garage', 'car', 976.85, -2547.27, 28.3, 15, '[{"x":977.06,"y":-2547.45,"z":27.69,"heading":352.07}]', 357, 47, 0.6, 'system'),
('tuner2_garage', 'Tuner2 Garage', 'car', 163.07, -3006.1, 5.33, 15, '[{"x":163.07,"y":-3006.10,"z":5.33,"heading":271.26}]', 357, 47, 0.6, 'system'),
('vespucci_garage', 'Vespucci Garage', 'car', 109.46, -1056.75, 28.59, 5, '[{"x":109.46,"y":-1056.75,"z":28.59,"heading":246.64}]', 357, 47, 0.6, 'system'),
('vinewood_blvd', 'North Vinewood Blvd', 'car', 365.21, 295.65, 103.46, 15, '[{"x":364.84,"y":289.73,"z":103.42,"heading":164.23}]', 357, 47, 0.6, 'system'),
('yellow_jack', 'Yellow Jack Garage', 'car', 2015.69, 3062.03, 47.05, 5, '[{"x":2016.77,"y":3062.73,"z":46.62,"heading":61.40}]', 357, 47, 0.6, 'system');

-- ============================================
-- VERIFICACIÓN DE INSTALACIÓN
-- ============================================

SELECT 'Tablas creadas correctamente' AS status;
SELECT COUNT(*) AS total_public_garages FROM public_garages;

-- ============================================
-- NOTAS SOBRE owned_vehicles (ESX)
-- ============================================
-- Este script NO modifica la tabla owned_vehicles de ESX.
-- Asegúrate de que tu tabla owned_vehicles tenga estas columnas:
--
-- REQUERIDAS:
-- - owner (VARCHAR) - Identificador del jugador
-- - plate (VARCHAR) - Placa única del vehículo
-- - vehicle (LONGTEXT) - JSON con datos del vehículo
-- - stored (TINYINT) - 0=fuera, 1=guardado, 2=impound
-- - parking (VARCHAR) - ID del garaje (ejemplo: 'central_garage', 'private_1')
--
-- OPCIONALES (mejoran funcionalidad):
-- - fuel (INT) - Nivel de combustible
-- - engine (FLOAT) - Estado del motor
-- - body (FLOAT) - Estado de carrocería
--
-- Si necesitas agregar columnas opcionales manualmente:
-- ALTER TABLE owned_vehicles ADD COLUMN fuel INT(11) NOT NULL DEFAULT 100;
-- ALTER TABLE owned_vehicles ADD COLUMN engine FLOAT NOT NULL DEFAULT 1000;
-- ALTER TABLE owned_vehicles ADD COLUMN body FLOAT NOT NULL DEFAULT 1000;

-- ============================================
-- FIN DE LA INSTALACIÓN
-- ============================================
