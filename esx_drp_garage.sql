USE `es_extended`;

ALTER TABLE `owned_vehicles` ADD `inpounded` BOOLEAN NOT NULL AFTER `stored`;
