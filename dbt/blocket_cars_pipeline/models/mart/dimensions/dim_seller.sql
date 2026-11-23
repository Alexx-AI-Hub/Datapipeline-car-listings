-- Grain: one observed combination of seller attributes.
-- Anonymous sellers with the same attributes share a descriptive row.
-- A changed profile gets another key; older facts keep their own profile.

{{ config(materialized='table', schema='mart') }}

WITH profiles AS (
    SELECT DISTINCT
        i.org_id,
        i.seller_organisation_name,
        i.seller_type,
        i.dealer_group_id,
        i.association_memberships
    FROM {{ ref('int_blocket_car_listing_geography') }} AS i
)

SELECT
    p.*,
    ROW_NUMBER() OVER (
        ORDER BY
            p.org_id, p.seller_organisation_name, p.seller_type,
            p.dealer_group_id, p.association_memberships
    ) AS seller_key
FROM profiles AS p
