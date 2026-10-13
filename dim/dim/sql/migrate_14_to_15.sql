-- Add `status_id` to the ipblock uniqueness key (ITOUDP-5900).
--
-- A Subnet may now have exactly the size of its enclosing Container, e.g. a
-- /24 Container holding a /24 Subnet. Both rows have the same address, prefix,
-- layer3domain and version, so the status has to be part of the key. The
-- application rejects every other same-size combination
-- (Ipblock._validate_same_size), the key still stops two blocks of the same
-- status at the same CIDR.
--
-- Appended for the same reason as `version` in migrate_13_to_14.sql: the
-- (address, prefix, layer3domain_id) index prefix stays usable and the index
-- keeps its name for USE INDEX (address).
--
-- Only relaxes the constraint: no existing row can violate it.

ALTER TABLE `ipblock`
      DROP INDEX `address`,
      ADD UNIQUE KEY `address` (`address`,`prefix`,`layer3domain_id`,`version`,`status_id`),
      ALGORITHM=INPLACE, LOCK=NONE;

UPDATE schemainfo SET version=15;
COMMIT;
