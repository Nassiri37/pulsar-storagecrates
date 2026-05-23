-- Migration: decouple storage crates from static routing buckets
-- Run once on your database (resource startup also applies these via InitDatabase)

ALTER TABLE `storage_crates` ADD COLUMN IF NOT EXISTS `apartment_id` VARCHAR(100) NULL DEFAULT NULL;
ALTER TABLE `storage_crates` ADD COLUMN IF NOT EXISTS `property_id` VARCHAR(100) NULL DEFAULT NULL;
ALTER TABLE `storage_crates` ADD COLUMN IF NOT EXISTS `last_bucket` INT(11) NULL DEFAULT NULL;

-- Backfill last_bucket from legacy coords.route JSON for existing rows
UPDATE `storage_crates`
SET `last_bucket` = CAST(JSON_UNQUOTE(JSON_EXTRACT(`coords`, '$.route')) AS UNSIGNED)
WHERE `last_bucket` IS NULL
  AND JSON_EXTRACT(`coords`, '$.route') IS NOT NULL;

-- Optional indexes (skip if they already exist)
-- ALTER TABLE `storage_crates` ADD INDEX `apartment_owner` (`owner_sid`, `apartment_id`);
-- ALTER TABLE `storage_crates` ADD INDEX `property_owner` (`owner_sid`, `property_id`);
