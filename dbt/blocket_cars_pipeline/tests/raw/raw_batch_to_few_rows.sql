{{ config(severity='error', store_failures=true) }}
{% set batch = raw_batch_test_context() %}

-- Fail when the selected batch contains fewer than 2,000 raw rows.
SELECT
    '{{ batch.filename }}' AS source_file,
    'too_few_rows' AS failure_reason,
    COUNT(*) AS row_count
FROM {{ ref('raw_blocket_car_listings') }}
WHERE source_file = '{{ batch.filename }}'
HAVING COUNT(*) < 2000
