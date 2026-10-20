{{ config(materialized='table', schema='mart') }}

-- Grain: one observed combination of descriptive car attributes.
-- This key describes a car configuration, not a unique physical vehicle.
WITH configurations AS (
    SELECT DISTINCT
        i.make,
        i.car_model_series,
        i.car_model,
        i.model_specification,
        i.model_year,
        i.transmission,
        i.fuel_type,
        i.registration_class_name
    FROM {{ ref('int_blocket_car_listing_geography') }} AS i
)

SELECT
    ROW_NUMBER() OVER (
        ORDER BY make, car_model_series, car_model, model_specification,
            model_year, transmission, fuel_type, registration_class_name
    ) AS car_key,
    c.*
FROM configurations AS c
