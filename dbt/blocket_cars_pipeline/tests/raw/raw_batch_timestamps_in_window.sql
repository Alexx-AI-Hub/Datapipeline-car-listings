{{ config(severity='error', store_failures=true) }}
{% set batch = raw_batch_test_context() %}
{% set window_end = var('batch_window_end', none) %}
{% if window_end is not none %}
    {% set parsed_end = modules.datetime.datetime.fromisoformat(window_end | string | replace('Z', '+00:00')) %}
    {% if parsed_end.utcoffset() is none %}
        {{ exceptions.raise_compiler_error('batch_window_end must be an ISO timestamp with a timezone offset.') }}
    {% endif %}
{% endif %}

-- Match ingestion: include the start, exclude the end, use 24 elapsed hours.
WITH window_bounds AS (
    SELECT
        {% if window_end is not none %}
            EPOCH_MS(TIMESTAMPTZ '{{ parsed_end.isoformat() }}')
        {% else %}
            EPOCH_MS(
                (DATE '{{ batch.date }}' + INTERVAL 15 HOUR)
                AT TIME ZONE 'Europe/Stockholm'
            )
        {% endif %} AS end_ms
),

batch_quality AS (
    SELECT
        COUNT(*) FILTER (WHERE r.timestamp IS NULL) AS missing_timestamps,
        COUNT(*) FILTER (
            WHERE r.timestamp < w.end_ms - 86400000 OR r.timestamp >= w.end_ms
        ) AS outside_window
    FROM {{ ref('raw_blocket_car_listings') }} AS r
    CROSS JOIN window_bounds AS w
    WHERE r.source_file = '{{ batch.filename }}'
)
SELECT
    '{{ batch.filename }}' AS source_file,
    'missing_timestamp' AS failure_reason,
    missing_timestamps AS affected_rows
FROM batch_quality
WHERE missing_timestamps > 0
UNION ALL
SELECT '{{ batch.filename }}', 'timestamp_outside_window', outside_window
FROM batch_quality
WHERE outside_window > 0
