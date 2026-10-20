{{ config(materialized='table', schema='mart') }}

SELECT *
FROM {{ ref('fact_listing_versions') }}
QUALIFY ROW_NUMBER() OVER (
    PARTITION BY listing_id
    ORDER BY uploaded_at DESC,
        TRY_STRPTIME(
            REGEXP_EXTRACT(source_file, '([0-9]{4}_[0-9]{2}_[0-9]{2})[.]jsonl[.]gz$', 1),
            '%Y_%m_%d'
        ) DESC NULLS LAST,
        source_file DESC
) = 1
