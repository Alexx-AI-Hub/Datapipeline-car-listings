{{ config(materialized='table', schema='mart') }}

-- Grain: one calendar day, including days without a listing version.
-- Use the date from uploaded_at directly, without timezone conversion.
WITH date_bounds AS (
    SELECT
        MIN(CAST(i.uploaded_at AS DATE)) AS first_date,
        MAX(CAST(i.uploaded_at AS DATE)) AS last_date
    FROM {{ ref('int_blocket_car_listing_geography') }} AS i
)

SELECT
    CAST(STRFTIME(d.calendar_date, '%Y%m%d') AS INTEGER) AS date_key,
    CAST(d.calendar_date AS DATE) AS calendar_date,
    YEAR(d.calendar_date) AS calendar_year,
    QUARTER(d.calendar_date) AS calendar_quarter,
    MONTH(d.calendar_date) AS month_number,
    STRFTIME(d.calendar_date, '%B') AS month_name,
    DAY(d.calendar_date) AS day_of_month,
    ISOYEAR(d.calendar_date) AS iso_year,
    WEEK(d.calendar_date) AS iso_week,
    ISODOW(d.calendar_date) AS iso_day_of_week,
    STRFTIME(d.calendar_date, '%A') AS weekday_name,
    ISODOW(d.calendar_date) >= 6 AS is_weekend
FROM date_bounds AS b
CROSS JOIN LATERAL GENERATE_SERIES(
    b.first_date, b.last_date, INTERVAL 1 DAY
) AS d (calendar_date)
