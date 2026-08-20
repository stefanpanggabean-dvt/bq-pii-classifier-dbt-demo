-- SQL model mapping pre-dbt raw table to transformed destination table
SELECT 
  user_id,
  user_email,
  phone_no
FROM `bq-dbt-tags-sandbox-01.test_dataset_be.raw_sensitive_data`
