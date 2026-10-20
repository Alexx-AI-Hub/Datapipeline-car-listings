-- Run once against datawarehouse/dwh.duckdb from the project root.
INSTALL spatial;
LOAD spatial;

CREATE SCHEMA IF NOT EXISTS reference;

CREATE TABLE IF NOT EXISTS reference.region_geo_boundaries AS
SELECT LANSKOD AS county_code, geom
FROM ST_Read('reference/counties_2026.geojson');
