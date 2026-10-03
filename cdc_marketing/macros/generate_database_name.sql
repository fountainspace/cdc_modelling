-- Keep here over utils as dbt ignores this macro from installed packages: https://docs.getdbt.com/docs/build/custom-databases

{% macro generate_database_name(custom_database_name=none, node=none) -%}
    {# only create custom catalog in production #}

    {%- set default_database = target.database -%}
    {%- if custom_database_name is none or target.name not in ['production', 'staging'] -%}

        {{ default_database }}

    {%- else -%}

        {{ custom_database_name | trim }}

    {%- endif -%}

{%- endmacro %}
