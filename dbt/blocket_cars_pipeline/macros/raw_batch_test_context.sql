{% macro raw_batch_test_context() %}
    {% set batch_date = var('batch_date', none) %}
    {% if batch_date is none %}
        {% if execute %}
            {{ exceptions.raise_compiler_error('Set batch_date explicitly for raw batch tests.') }}
        {% endif %}
        {{ return({'date': '1900-01-01', 'filename': '__batch_date_required__.jsonl.gz'}) }}
    {% endif %}
    {% set date_text = batch_date | string | replace('_', '-') %}
    {% if not modules.re.fullmatch('[0-9]{4}-[0-9]{2}-[0-9]{2}', date_text) %}
        {{ exceptions.raise_compiler_error('batch_date must be YYYY-MM-DD or YYYY_MM_DD.') }}
    {% endif %}
    {% set parsed_date = modules.datetime.datetime.strptime(date_text, '%Y-%m-%d') %}
    {{ return({
        'date': parsed_date.strftime('%Y-%m-%d'),
        'filename': 'blocket_cars_' ~ parsed_date.strftime('%Y_%m_%d') ~ '.jsonl.gz'
    }) }}
{% endmacro %}
