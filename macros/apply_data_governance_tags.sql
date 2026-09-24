-- macros/apply_data_governance_tags.sql
--
-- BigQuery V2 Data Governance Tags dbt Post-Hook Macro
-- Automatically binds Resource Manager Data Governance tags to physical table columns in BigQuery.
--
-- Prerequisites:
-- 1. dbt Runner Service Account must have:
--    - roles/resourcemanager.tagUser on the Tag Key or Value (e.g. in sbx-devo-pj-gov)
--    - roles/bigquery.dataOwner (or bigquery.tables.updateTag) on target dataset
--    - roles/bigquerydatapolicy.maskedReader (or reader) if downstream models query tagged tables
-- 2. BigQuery Enterprise or Enterprise Plus edition.
--
-- Usage in dbt_project.yml:
--   models:
--     +post-hook: "{{ apply_data_governance_tags() }}"
--

{% macro apply_data_governance_tags() %}
  {# Only execute during actual query execution (not compile/parse) and only for physical tables #}
  {% if execute and model.columns and model.config.materialized in ['table', 'incremental'] %}
    {% set alter_statements = [] %}

    {% for col_name, col_meta in model.columns.items() %}
      {% if col_meta.meta %}
        {% set tag_key = none %}
        {% set tag_value = none %}

        {# Support both singular meta.data_governance_tag and plural meta.data_governance_tags #}
        {% if col_meta.meta.data_governance_tag is mapping %}
          {% set tag_key = col_meta.meta.data_governance_tag.key %}
          {% set tag_value = col_meta.meta.data_governance_tag.value %}
        {% elif col_meta.meta.data_governance_tags is sequence and col_meta.meta.data_governance_tags | length > 0 %}
          {% set tag_key = col_meta.meta.data_governance_tags[0].key %}
          {% set tag_value = col_meta.meta.data_governance_tags[0].value %}
        {% endif %}

        {% if tag_key and tag_value %}
          {% set stmt %}
ALTER TABLE {{ this }} 
ALTER COLUMN `{{ col_name }}` 
SET OPTIONS (data_governance_tags=[('{{ tag_key }}', '{{ tag_value }}')]);
          {% endset %}
          {% do alter_statements.append(stmt.strip()) %}
        {% endif %}
      {% endif %}
    {% endfor %}

    {# Consolidate all column updates into a single multi-statement execution to prevent N+1 query latency and BQ rate limits #}
    {% if alter_statements | length > 0 %}
      {{ log("Applying " ~ alter_statements | length ~ " Data Governance Tag(s) to " ~ this, info=True) }}
      {% set batch_ddl = alter_statements | join('\n') %}
      {% do run_query(batch_ddl) %}
    {% endif %}
  {% endif %}
{% endmacro %}
