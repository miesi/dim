-- Drop `status_id` from the ipblock uniqueness key.
--
-- Fails while any Container and Subnet share a CIDR. Find them with
--
--   SELECT address, prefix, layer3domain_id, version, COUNT(*) FROM ipblock
--    GROUP BY address, prefix, layer3domain_id, version HAVING COUNT(*) > 1;
--
-- and give each such Subnet a Container that is strictly larger before
-- rolling back.

ALTER TABLE `ipblock`
      DROP INDEX `address`,
      ADD UNIQUE KEY `address` (`address`,`prefix`,`layer3domain_id`,`version`),
      ALGORITHM=INPLACE, LOCK=NONE;

UPDATE schemainfo SET version=14;
COMMIT;
