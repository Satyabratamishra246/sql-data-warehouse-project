/*
================================================================================================
Product Report
================================================================================================
Purpose:
	- This report consolidates key product metrics and behaviours

Highlights:
	1. Gathers essential fields such as product name, category, subcategory and cost
	2. segments products by revenue to identify High-Performance, Mid-Range, or Low-Performers
	3. Aggregate product level metrics
		- total orders
		- total sales
		- total quantity sold
		- total unique customer
		- lifespan in months
	4. Calculate valuable KPIs:
		- recency (months since last sale)
		- average order revenue (AOR)
		- average monthly revenue
===================================================================================================
*/
CREATE VIEW gold.report_products AS
WITH base_query AS (
/*
-----------------------------------------------------------------------------------
1) Base Query: Retrieves core columns from tables
-----------------------------------------------------------------------------------*/
	SELECT
		f.order_number,
		f.product_key,
		f.order_date,
		f.sales_amount,
		f.quantity,
		f.customer_key,
		p.product_name,
		p.category,
		p.subcategory,
		p.cost
	FROM gold.fact_sales f
	LEFT JOIN gold.dim_products p
	ON f.product_key = p.product_key
	WHERE f.order_date IS NOT NULL
), product_aggregation AS (
	SELECT
		product_key,
		product_name,
		category,
		subcategory,
		cost,
		COUNT(DISTINCT order_number) AS total_orders,
		SUM(sales_amount) AS total_sales,
		SUM(quantity) AS total_quantity,
		COUNT(DISTINCT customer_key) as total_customers,
		MAX(order_date) as last_sale_date,
		DATEDIFF(MONTH, MIN(order_date), MAX(order_date)) AS life_span,
		ROUND(AVG(CAST(sales_amount AS FLOAT) / NULLIF(quantity,0)), 1) AS avg_selling_price
	FROM base_query
	GROUP BY
		product_key,
		product_name,
		category,
		subcategory,
		cost
	)
SELECT
	product_key,
	product_name,
	category,
	subcategory,
	cost,
	last_sale_date,
	DATEDIFF(MONTH, last_sale_date, GETDATE()) as recency_in_months,
	CASE WHEN total_sales > 50000 THEN 'High-Performer'
		WHEN total_sales >= 1000 THEN 'Mid-Range'
		ELSE 'Low-Performer'
	END AS product_segment,
	life_span,
	total_orders,
	total_sales,
	total_quantity,
	total_customers,
	avg_selling_price,
	CASE 
		WHEN total_orders = 0 THEN 0
		ELSE total_sales / total_orders
	END as avg_order_revenue,
	CASE 
		WHEN life_span = 0 THEN total_sales
		ELSE total_sales / life_span
	END as avg_monthly_revenue
FROM product_aggregation;
