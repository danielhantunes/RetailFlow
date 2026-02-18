-- Daily revenue mart (dbt version; can extend Gold or replace)
{{
  config(
    materialized='incremental',
    unique_key='order_date',
    partition_by=['order_date']
  )
}}
with orders as (
    select * from {{ source('silver', 'orders') }}
),
daily as (
    select
        order_date,
        sum(total_amount) as revenue,
        count(*) as order_count
    from orders
    where status in ('COMPLETED', 'SHIPPED', 'DELIVERED')
    {% if is_incremental() %}
    and order_date > (select max(order_date) from {{ this }})
    {% endif %}
    group by order_date
)
select * from daily
