-- Warns if more than 5% of raw rows are removed from RAW --> STG.


{{ config(severity='warn', store_failures=true) }}


-- No batch date means all rows.
{% set batch_date = var('batch_date', none) %}
{% if batch_date is not none %}
    {% set batch = raw_batch_test_context() %}
{% endif %}

WITH batch_counts AS (
    SELECT
        (
            SELECT COUNT(*)
            FROM {{ ref('raw_blocket_car_listings') }}
            {% if batch_date is not none %}
                WHERE source_file = '{{ batch.filename }}'
            {% endif %}
        ) AS raw_rows,

        (
            SELECT COUNT(*)
            FROM {{ ref('stg_blocket_car_listings') }}
            {% if batch_date is not none %}
                WHERE source_file = '{{ batch.filename }}'
            {% endif %}
        ) AS stg_rows
)

SELECT
    raw_rows,
    stg_rows,
    (raw_rows - stg_rows) AS removed_rows,
    100.0 * (raw_rows - stg_rows) / NULLIF(raw_rows, 0) AS removed_pct
FROM batch_counts
WHERE
    raw_rows > 0
    AND 100.0 * (raw_rows - stg_rows)
    / NULLIF(raw_rows, 0) > 5
