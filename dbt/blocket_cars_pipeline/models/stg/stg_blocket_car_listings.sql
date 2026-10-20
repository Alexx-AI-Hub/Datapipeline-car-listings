-- Flattens nested objects and selects 36 columns.
-- Sets explicit data types and normalizes blank text to NULL.
-- Removes duplicate rows with the same (listing_id, uploaded_at, source_file).


{{ config(materialized='view', schema='stg') }}

-- Columns grouped by business area.
SELECT -- noqa: ST06
    -- Listing
    CAST(r.ad_id AS VARCHAR) AS listing_id,
    NULLIF(TRIM(CAST(r.heading AS VARCHAR)), '') AS listing_title,
    CAST(EPOCH_MS(CAST(r.timestamp AS BIGINT)) AS TIMESTAMP_S) AS uploaded_at,
    NULLIF(TRIM(CAST(r.canonical_url AS VARCHAR)), '') AS listing_url,
    NULLIF(TRIM(CAST(r.image['url'] AS VARCHAR)), '') AS main_image_url,

    -- Location
    NULLIF(TRIM(CAST(r.location AS VARCHAR)), '') AS location, -- noqa: RF04
    CAST(r.coordinates['lat'] AS DOUBLE) AS latitude,
    CAST(r.coordinates['lon'] AS DOUBLE) AS longitude,

    -- Price
    CAST(r.price['amount'] AS DECIMAL(18, 2)) AS price,
    CAST(r.price['amount_ex_vat'] AS DECIMAL(18, 2)) AS price_ex_vat,

    -- Vehicle
    CAST(r.year AS INTEGER) AS model_year,
    NULLIF(TRIM(CAST(r.make AS VARCHAR)), '') AS make,
    NULLIF(TRIM(CAST(r.series AS VARCHAR)), '') AS car_model_series,
    NULLIF(TRIM(CAST(r.model AS VARCHAR)), '') AS car_model,
    NULLIF(TRIM(CAST(r.model_specification AS VARCHAR)), '')
        AS model_specification,
    CAST(r.mileage AS BIGINT) AS mileage_mil,
    NULLIF(TRIM(CAST(r.transmission AS VARCHAR)), '') AS transmission,
    NULLIF(TRIM(CAST(r.fuel AS VARCHAR)), '') AS fuel_type,
    NULLIF(TRIM(CAST(r.registration_class['value'] AS VARCHAR)), '')
        AS registration_class_name,
    -- Expose encrypted identifiers only; originals stay in raw.
    NULLIF(TRIM(CAST(r.regnbr_encrypt AS VARCHAR)), '') AS regnbr_encrypted,
    NULLIF(TRIM(CAST(r.vin_encrypt AS VARCHAR)), '') AS vin_encrypted,

    -- Seller
    NULLIF(TRIM(CAST(r.dealer_segment AS VARCHAR)), '') AS seller_type,
    NULLIF(TRIM(CAST(r.org_id AS VARCHAR)), '') AS org_id,
    NULLIF(TRIM(CAST(r.organisation_name AS VARCHAR)), '')
        AS seller_organisation_name,
    NULLIF(TRIM(CAST(r.dealer_group_id AS VARCHAR)), '') AS dealer_group_id,
    CAST(r.association_memberships AS VARCHAR[]) AS association_memberships,

    -- Listing categories and details
    CAST(r.ad_type AS INTEGER) AS listing_type_code,
    CAST(r.sales_form AS INTEGER) AS sales_form_code,
    CAST(r.flags AS VARCHAR[]) AS listing_flags,
    CAST(r.labels AS JSON[]) AS listing_labels,
    CAST(r.service_documents AS VARCHAR[]) AS service_documents,
    CAST(r.image_urls AS VARCHAR[]) AS image_urls,
    CAST(r.warranty_duration AS INTEGER) AS warranty_duration,
    CAST(r.driving_range AS INTEGER) AS driving_range,
    CAST(r.volume AS INTEGER) AS volume,
    NULLIF(TRIM(CAST(r.source_file AS VARCHAR)), '') AS source_file

FROM {{ ref('raw_blocket_car_listings') }} AS r

-- De-duplicate within each source file; preserve observations from other batches.
QUALIFY ROW_NUMBER() OVER (
    PARTITION BY listing_id, uploaded_at, source_file
    ORDER BY
        TRY_STRPTIME(
            REGEXP_EXTRACT(
                r.source_file,
                '([0-9]{4}_[0-9]{2}_[0-9]{2})[.]jsonl[.]gz$',
                1
            ),
            '%Y_%m_%d'
        ) DESC NULLS LAST,
        r.source_file DESC
) = 1
