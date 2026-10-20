{{ config(severity='warn', store_failures=true) }}
{% set batch = raw_batch_test_context() %}

-- Compare distinct ads, not raw row counts; raw duplicates are allowed.
-- Missing calendar days are excluded, and future batches never enter the baseline.
WITH daily_counts AS (
    SELECT
        source_file,
        TRY_STRPTIME(
            REGEXP_EXTRACT(source_file, '([0-9]{4}_[0-9]{2}_[0-9]{2})[.]jsonl[.]gz$', 1),
            '%Y_%m_%d'
        )::DATE AS batch_date,
        COUNT(DISTINCT ad_id) AS ad_count
    FROM {{ ref('raw_blocket_car_listings') }}
    WHERE REGEXP_FULL_MATCH(source_file, 'blocket_cars_[0-9]{4}_[0-9]{2}_[0-9]{2}[.]jsonl[.]gz')
    GROUP BY source_file
),
baseline AS (
    SELECT
        COUNT(*) AS comparison_days,
        MEDIAN(ad_count) AS median_ad_count
    FROM daily_counts
    WHERE batch_date >= DATE '{{ batch.date }}' - INTERVAL 7 DAY
        AND batch_date < DATE '{{ batch.date }}'
),
current_batch AS (
    SELECT COUNT(DISTINCT ad_id) AS ad_count
    FROM {{ ref('raw_blocket_car_listings') }}
    WHERE source_file = '{{ batch.filename }}'
)
SELECT
    '{{ batch.filename }}' AS source_file,
    c.ad_count AS current_ad_count,
    b.comparison_days,
    b.median_ad_count,
    b.median_ad_count * 0.4 AS warning_threshold,
    ROUND(
        100.0 * (b.median_ad_count - c.ad_count) / NULLIF(b.median_ad_count, 0), 2
    ) AS drop_pct
FROM current_batch AS c
CROSS JOIN baseline AS b
WHERE b.comparison_days >= 3
    AND b.median_ad_count > 0
    AND c.ad_count < b.median_ad_count * 0.4
