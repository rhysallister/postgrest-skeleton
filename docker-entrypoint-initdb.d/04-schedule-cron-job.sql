\c skltn

DO $$
BEGIN
	RAISE NOTICE '============================';
	RAISE NOTICE '  04-schedule-cron-job.sql  ';
	RAISE NOTICE '============================';
END ;
$$ LANGUAGE PLPGSQL;

CREATE TABLE api.🐘( fid bigint GENERATED ALWAYS AS IDENTITY, nomenclature text);
GRANT SELECT ON api.🐘 TO everyman;
GRANT SELECT ON api.🐘 TO skltn;
CREATE VIEW api.available_extensions AS SELECT * FROM pg_available_extensions ORDER BY 1;
GRANT SELECT ON api.available_extensions TO everyman;

SELECT cron.schedule(
	'Elephant Insert Every Minute',
	'* * * * *',
	$$INSERT INTO api.🐘 (nomenclature) VALUES (repeat('🐘',(random()*10)::int));$$
);
