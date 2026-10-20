-- Calculate the region based on swedish Geo reference.


{{ config(materialized='table', schema='int') }}

WITH listing_versions AS (
    SELECT -- noqa: ST06
        i.listing_id,
        i.listing_title,
        i.uploaded_at,
        i.listing_url,
        i.main_image_url,
        i.location,
        i.latitude,
        i.longitude,
        i.price,
        i.price_ex_vat,
        i.model_year,
        i.make,
        i.car_model_series,
        i.car_model,
        i.model_specification,
        i.mileage_mil,
        i.transmission,
        i.fuel_type,
        i.registration_class_name,
        i.regnbr_encrypted,
        i.vin_encrypted,
        i.seller_type,
        i.org_id,
        i.seller_organisation_name,
        i.dealer_group_id,
        i.association_memberships,
        i.listing_type_code,
        i.sales_form_code,
        i.listing_flags,
        i.listing_labels,
        i.service_documents,
        i.image_urls,
        i.warranty_duration,
        i.driving_range,
        i.volume,
        i.source_file,
        i.sale_type,
        i.previous_price,
        i.price_change,
        i.price_change_pct,
        i.valid_price,
        i.car_age
    FROM {{ ref('int_blocket_car_listing_versions') }} AS i
),

region_names (county_code, region) AS (
    VALUES
    ('01', 'stockholm'),
    ('03', 'uppsala'),
    ('04', 'södermanland'),
    ('05', 'östergötland'),
    ('06', 'jönköping'),
    ('07', 'kronoberg'),
    ('08', 'kalmar'),
    ('09', 'gotland'),
    ('10', 'blekinge'),
    ('12', 'skåne'),
    ('13', 'halland'),
    ('14', 'västra götaland'),
    ('17', 'värmland'),
    ('18', 'örebro'),
    ('19', 'västmanland'),
    ('20', 'dalarna'),
    ('21', 'gävleborg'),
    ('22', 'västernorrland'),
    ('23', 'jämtland'),
    ('24', 'västerbotten'),
    ('25', 'norrbotten')
),

region_boundaries AS (
    SELECT
        rn.county_code,
        rn.region,
        geo_ref.geom
    FROM {{ source('geography', 'region_geo_boundaries') }} AS geo_ref
    INNER JOIN region_names AS rn
        ON geo_ref.county_code = rn.county_code
),

coordinates AS (
    SELECT DISTINCT
        latitude,
        longitude
    FROM listing_versions
    WHERE
        latitude BETWEEN -90 AND 90
        AND longitude BETWEEN -180 AND 180
),

coordinate_regions AS (
    SELECT
        c.latitude,
        c.longitude,
        CASE
            WHEN count(rb.county_code) = 1 THEN max(rb.region)
        END AS region
    FROM coordinates AS c
    LEFT JOIN region_boundaries AS rb
        ON st_covers(
            rb.geom,
            st_point(c.longitude, c.latitude)
        )
    GROUP BY
        c.latitude,
        c.longitude
)

SELECT -- Include all columns from listing_versions + region.
    lv.*,
    cr.region
FROM listing_versions AS lv
LEFT JOIN coordinate_regions AS cr
    ON
        lv.latitude = cr.latitude
        AND lv.longitude = cr.longitude
