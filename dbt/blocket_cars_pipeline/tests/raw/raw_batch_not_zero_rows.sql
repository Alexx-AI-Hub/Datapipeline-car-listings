{{ config(severity='error', store_failures=true) }}


{% set batch = raw_batch_test_context() %}
{% set raw_data_path = var('raw_data_path', '../../Data') | replace('\\', '/') %}


SELECT
    '{{ batch.filename }}' AS source_file,
    count(*) AS row_count
FROM
    read_json(
        '{{ (raw_data_path ~ '/' ~ batch.filename) | replace("'", "''") }}',
        format = 'newline_delimited',
        columns = { 'ad_id': 'BIGINT' }
    )
HAVING count(*) = 0
