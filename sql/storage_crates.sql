
CREATE TABLE IF NOT EXISTS `storage_crates` (
    `id` INT(11) NOT NULL AUTO_INCREMENT,
    `crate_id` VARCHAR(50) NOT NULL UNIQUE,
    `owner_sid` VARCHAR(50) NOT NULL,
    `tier` VARCHAR(50) NOT NULL,
    `model` VARCHAR(100) NOT NULL,
    `coords` TEXT NOT NULL,
    `heading` FLOAT NOT NULL,
    `has_password` BOOLEAN NOT NULL DEFAULT FALSE,
    `password_hash` VARCHAR(255) DEFAULT NULL,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `owner_sid` (`owner_sid`),
    KEY `crate_id` (`crate_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;






