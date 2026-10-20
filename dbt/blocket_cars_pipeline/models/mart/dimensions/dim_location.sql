{{ config(materialized='table', schema='mart') }}

-- Grain: one (region, location) combination.
WITH locations AS (
    SELECT DISTINCT
        i.location,
        i.region
    FROM {{ ref('int_blocket_car_listing_geography') }} AS i
)

SELECT
    ROW_NUMBER() OVER (ORDER BY region, location) AS location_key,
    l.location,
    l.region
FROM locations AS l
