-- Bootstrap entrypoint for fresh Postgres initialization.
-- The official postgres image executes top-level *.sql files in this directory.

\i /docker-entrypoint-initdb.d/raw/energidataservice/001_create_tables.sql
\i /docker-entrypoint-initdb.d/raw/dmi_climate/001_create_tables.sql
\i /docker-entrypoint-initdb.d/raw/mqtt/001_create_tables.sql
\i /docker-entrypoint-initdb.d/enrich/dmi_climate/001_create_views.sql
\i /docker-entrypoint-initdb.d/enrich/energidataservice/001_create_views.sql
\i /docker-entrypoint-initdb.d/enrich/mqtt/001_create_views.sql
\i /docker-entrypoint-initdb.d/curated/dmi_climate_temperature/001_create_materialized_views.sql
\i /docker-entrypoint-initdb.d/curated/power_price/001_create_materialized_views.sql
\i /docker-entrypoint-initdb.d/serving/dmi_climate_temperature_overview/001_create_views.sql
\i /docker-entrypoint-initdb.d/serving/power_price_overview/001_create_views.sql
