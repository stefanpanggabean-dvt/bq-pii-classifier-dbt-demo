{{ config(materialized='table') }}

-- SQL model mapping pre-dbt raw table to transformed destination table
SELECT 
  user_id,
  payment_ref
FROM `bq-dbt-tags-sandbox-01.test_dataset_be.raw_unconfigured_data`
