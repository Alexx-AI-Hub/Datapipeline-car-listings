{{ config(materialized='view', schema='int') }}

-- Grain: one observed listing version per (listing_id, uploaded_at, source_file).
-- +6 new columns

SELECT -- noqa: ST06
    s.listing_id,
    s.listing_title,
    s.uploaded_at,
    s.listing_url,
    s.main_image_url,
    s.location,
    s.latitude,
    s.longitude,
    s.price,
    s.price_ex_vat,
    s.model_year,
    s.make,
    s.car_model_series,
    s.car_model,
    s.model_specification,
    s.mileage_mil,
    s.transmission,
    s.fuel_type,
    s.registration_class_name,
    s.regnbr_encrypted,
    s.vin_encrypted,
    s.seller_type,
    s.org_id,
    s.seller_organisation_name,
    s.dealer_group_id,
    s.association_memberships,
    s.listing_type_code,
    s.sales_form_code,
    s.listing_flags,
    s.listing_labels,
    s.service_documents,
    s.image_urls,
    s.warranty_duration,
    s.driving_range,
    s.volume,
    s.source_file,

    -- New! sale_type
    CASE s.sales_form_code
        WHEN 1 THEN 'Used'
        WHEN 2 THEN 'New'
        WHEN 5 THEN 'Lease'
        ELSE 'Unknown'
    END AS sale_type,

    -- New! previous_price
    lag(s.price) OVER (
        PARTITION BY s.listing_id
        ORDER BY s.uploaded_at,
        TRY_STRPTIME(
            REGEXP_EXTRACT(s.source_file, '([0-9]{4}_[0-9]{2}_[0-9]{2})[.]jsonl[.]gz$', 1),
            '%Y_%m_%d'
        ) ASC NULLS FIRST,
        s.source_file
    ) AS previous_price,

    -- New! price_change
    s.price - previous_price AS price_change,

    -- New! price_change_pct
    cast(
        round(
            100.0 * (s.price - previous_price)
            / nullif(previous_price, 0), 2
        ) AS DECIMAL(18, 2)
    ) AS price_change_pct,

    -- New! valid_price
    coalesce(s.price > 0, FALSE) AS valid_price,

    -- New! car_age
    CASE -- Calculate car age. Invalid years is set to NULL.
        WHEN
            s.model_year > 1800
            AND s.model_year <= year(current_date) + 1 -- Allow 2027
            THEN cast(
                greatest(year(s.uploaded_at) - s.model_year, 0)
                AS INTEGER
            )
    END AS car_age

FROM {{ ref('stg_blocket_car_listings') }} AS s
