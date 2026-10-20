{{ config(materialized='table', schema='mart') }}

-- Grain: one observed listing version per (listing_id, uploaded_at, source_file).
-- Prices describe ads, not completed sales; do not sum across versions.
SELECT -- noqa: ST06
    ROW_NUMBER() OVER (
        ORDER BY i.listing_id, i.uploaded_at, i.source_file
    ) AS listing_version_key,
    i.listing_id,
    i.uploaded_at,
    d.date_key,
    c.car_key,
    se.seller_key,
    l.location_key,
    i.latitude,
    i.longitude,
    i.listing_title,
    i.listing_url,
    i.main_image_url,
    i.image_urls,
    i.service_documents,
    i.regnbr_encrypted,
    i.vin_encrypted,
    i.listing_type_code,
    i.sales_form_code,
    i.sale_type,
    i.listing_flags,
    i.listing_labels,
    i.price,
    i.price_ex_vat,
    i.previous_price,
    i.price_change,
    i.price_change_pct,
    i.valid_price,
    i.mileage_mil,
    i.car_age,
    i.warranty_duration,
    i.driving_range,
    i.volume,
    i.source_file
FROM {{ ref('int_blocket_car_listing_geography') }} AS i
LEFT JOIN {{ ref('dim_car') }} AS c
    ON i.make IS NOT DISTINCT FROM c.make
    AND i.car_model_series IS NOT DISTINCT FROM c.car_model_series
    AND i.car_model IS NOT DISTINCT FROM c.car_model
    AND i.model_specification IS NOT DISTINCT FROM c.model_specification
    AND i.model_year IS NOT DISTINCT FROM c.model_year
    AND i.transmission IS NOT DISTINCT FROM c.transmission
    AND i.fuel_type IS NOT DISTINCT FROM c.fuel_type
    AND i.registration_class_name IS NOT DISTINCT FROM c.registration_class_name
LEFT JOIN {{ ref('dim_seller') }} AS se
    ON i.org_id IS NOT DISTINCT FROM se.org_id
    AND i.seller_organisation_name IS NOT DISTINCT FROM se.seller_organisation_name
    AND i.seller_type IS NOT DISTINCT FROM se.seller_type
    AND i.dealer_group_id IS NOT DISTINCT FROM se.dealer_group_id
    AND i.association_memberships IS NOT DISTINCT FROM se.association_memberships
LEFT JOIN {{ ref('dim_location') }} AS l
    ON i.region IS NOT DISTINCT FROM l.region
    AND i.location IS NOT DISTINCT FROM l.location
LEFT JOIN {{ ref('dim_date') }} AS d
    ON CAST(i.uploaded_at AS DATE) = d.calendar_date
