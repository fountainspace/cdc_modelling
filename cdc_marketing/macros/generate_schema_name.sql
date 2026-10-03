-- Keep here over utils as dbt ignores this macro from installed packages: https://docs.getdbt.com/docs/build/custom-schemas#changing-the-way-dbt-generates-a-schema-name

{% macro generate_schema_name(custom_schema_name, node) -%}
    {# only create custom schemas in production #}

    {%- set default_schema = target.schema -%} 
    {%- if custom_schema_name is none or target.name not in ['production', 'staging'] -%}

        {{ default_schema }}

    {%- else -%}

        {{ custom_schema_name | trim }}

    {%- endif -%}

{%- endmacro %}