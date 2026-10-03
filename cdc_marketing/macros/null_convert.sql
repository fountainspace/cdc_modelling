{% macro check_null(column) %}

    case
        when {{ column }} is null then '2'
    end

{% endmacro %}

