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
    ROW_NUMBER() OVER (
        ORDER BY org_id, seller_organisation_name, seller_type,
            dealer_group_id, association_memberships
    ) AS seller_key,
    p.*
FROM profiles AS p
