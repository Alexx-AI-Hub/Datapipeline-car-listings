{{ config(materialized='table', schema='mart') }}

-- Grain: one (region, location) combination.
WITH locations AS (
    SELECT DISTINCT
        i.location,
        i.region
    FROM {{ ref('int_blocket_car_listing_geography') }} AS i
)

SELECT
    l.location,
    l.region,
    ROW_NUMBER() OVER (
        ORDER BY l.region, l.location
    ) AS location_key
FROM locations AS l
