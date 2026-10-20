{{ config(
    materialized='incremental',
    schema='raw',
    alias='blocket_car_listings',
    incremental_strategy='delete+insert',
    unique_key='source_file',
    on_schema_change='append_new_columns',
    full_refresh=false
) }}

-- Load one daily file. Replaying a non-empty file replaces that batch only.
-- source_file is the batch replacement key, not a unique listing row key.
{% set batch_date = var('batch_date', none) %}
{% set raw_data_path = var('raw_data_path', '../../Data') | replace('\\', '/') %}

{% if execute and batch_date is none %}
    {{ exceptions.raise_compiler_error(
        'Set batch_date explicitly, for example --vars "batch_date: 2026-10-13".'
    ) }}
{% endif %}

{% if batch_date is not none %}
    {% set date_text = batch_date | string | replace('_', '-') %}
    {% if not modules.re.fullmatch('[0-9]{4}-[0-9]{2}-[0-9]{2}', date_text) %}
        {{ exceptions.raise_compiler_error('batch_date must be YYYY-MM-DD or YYYY_MM_DD.') }}
    {% endif %}
    {% set parsed_date = modules.datetime.datetime.strptime(date_text, '%Y-%m-%d') %}
    {% set batch_filename = 'blocket_cars_' ~ parsed_date.strftime('%Y_%m_%d') ~ '.jsonl.gz' %}
{% else %}
    {% set batch_filename = '__batch_date_required__.jsonl.gz' %}
{% endif %}

-- Fix the raw schema so missing JSON keys become NULL.
SELECT
    -- Listing
    r.type,
    r.id,
    r.ad_id,
    r.main_search_key,
    r.heading,
    r.facade_title,
    r.timestamp,
    r.canonical_url,
    r.ad_type,
    r.sales_form,

    -- Location
    r.location,
    r.coordinates,

    -- Price
    r.price,

    -- Vehicle
    r.make,
    r.series,
    r.model,
    r.model_specification,
    r.year,
    r.mileage,
    r.mileage_unit,
    r.transmission,
    r.fuel,
    r.registration_class,
    r.driving_range,
    r.volume,
    r.used_car_of_the_year,
    r.warranty_duration,

    -- Original and encrypted identifiers
    r.regno,
    r.chassis_number,
    r.regnbr_encrypt,
    r.vin_encrypt,

    -- Seller
    r.org_id,
    r.dealer_segment,
    r.organisation_name,
    r.dealer_group_id,
    r.association_memberships,

    -- Images and additional details
    r.image,
    r.image_urls,
    r.service_documents,
    r.flags,
    r.labels,
    r.extras,

    -- Ingestion metadata
    '{{ batch_filename }}' AS source_file

FROM read_json(
    '{{ (raw_data_path ~ '/' ~ batch_filename) | replace("'", "''") }}',
    format = 'newline_delimited',
    columns = {
        'type': 'VARCHAR',
        'id': 'VARCHAR',
        'ad_id': 'BIGINT',
        'main_search_key': 'VARCHAR',
        'heading': 'VARCHAR',
        'facade_title': 'VARCHAR',
        'timestamp': 'BIGINT',
        'canonical_url': 'VARCHAR',
        'ad_type': 'BIGINT',
        'sales_form': 'BIGINT',
        'location': 'VARCHAR',
        'coordinates': 'STRUCT(lat DOUBLE, lon DOUBLE, accuracy BIGINT)',
        'price': 'STRUCT(
                    amount BIGINT, 
                    currency_code VARCHAR, 
                    price_unit VARCHAR, 
                    amount_ex_vat BIGINT
                )',
        'make': 'VARCHAR',
        'series': 'VARCHAR',
        'model': 'VARCHAR',
        'model_specification': 'VARCHAR',
        'year': 'BIGINT',
        'mileage': 'BIGINT',
        'mileage_unit': 'VARCHAR',
        'transmission': 'VARCHAR',
        'fuel': 'VARCHAR',
        'registration_class': 'STRUCT(id BIGINT, "value" VARCHAR)',
        'driving_range': 'BIGINT',
        'volume': 'BIGINT',
        'used_car_of_the_year': 'JSON[]',
        'warranty_duration': 'BIGINT',
        'regno': 'VARCHAR',
        'chassis_number': 'VARCHAR',
        'regnbr_encrypt': 'VARCHAR',
        'vin_encrypt': 'VARCHAR',
        'org_id': 'VARCHAR',
        'dealer_segment': 'VARCHAR',
        'organisation_name': 'VARCHAR',
        'dealer_group_id': 'VARCHAR',
        'association_memberships': 'VARCHAR[]',
        'image': 'STRUCT(
                    url VARCHAR, 
                    path VARCHAR, 
                    height BIGINT, 
                    width BIGINT, 
                    aspect_ratio DOUBLE
                )',
        'image_urls': 'VARCHAR[]',
        'service_documents': 'VARCHAR[]',
        'flags': 'VARCHAR[]',
        'labels': 'STRUCT(id VARCHAR, "text" VARCHAR, "type" VARCHAR)[]',
        'extras': 'JSON[]'
    }
) AS r
