{% macro drop_schemas(dry_run=true, schema_startswith="PR_") %}
    {{ log("DROP SCHEMAS {target: " ~ target.name ~ ", schema: " ~ target.schema ~ ", dry_run: " ~ dry_run ~ "}", info=true) }}

    {% if target.name == 'prod' %}
        {{ exceptions.raise_compiler_error("Cannot drop schema when targeting prod") }}
    {% endif %}

    {% if not target.schema|trim %}
        {{ exceptions.raise_compiler_error("Target schema must not be empty") }}
    {% endif %}

    {% if not (target.schema|trim).startswith(schema_startswith) %}
        {{ exceptions.raise_compiler_error("Target schema must start with " ~ schema_startswith ~ " to be deletable") }}
    {% endif %}

    {{adapter.dispatch('drop_schemas')(dry_run) }}

{% endmacro %}

{% macro databricks__drop_schemas(dry_run=true) %}

    {%- set use_catalog -%}
        USE CATALOG {{ target.database }};
    {%- endset -%}

    {{ run_query(use_catalog) }}

    {% set lower_schema = target.schema|lower %}

    {% set get_schemas_sql %}
        SELECT
            SCHEMA_NAME
        FROM
            INFORMATION_SCHEMA.SCHEMATA
        WHERE
            SCHEMA_NAME = '{{ lower_schema }}'

    {% endset %}

    {{ log(get_schemas_sql, info=true) }}

    {%- set results = run_query(get_schemas_sql) -%}

    {%- for schema in results -%}

        {%- set drop_schema_sql -%}
            DROP SCHEMA IF EXISTS {{ schema['SCHEMA_NAME'] }} CASCADE;
        {%- endset -%}

        {%- if dry_run -%}
            {{ log("Dry run: " ~ drop_schema_sql, info=true) }}
        {%- else -%}
            {{ log(drop_schema_sql, info=true) }}
            {{ run_query(drop_schema_sql) }}
        {%- endif -%}

    {%- endfor -%}

{% endmacro %}