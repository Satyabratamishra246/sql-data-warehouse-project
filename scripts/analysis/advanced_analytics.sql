-- Change Over Time Analysis

-- Year wise
SELECT
	YEAR(order_date) AS order_year,
	SUM(sales_amount) AS total_sales,
	COUNT(DISTINCT customer_key) AS total_customers,
	SUM(quantity) AS total_quantity
FROM gold.fact_sales
WHERE order_date IS NOT NULL
GROUP BY YEAR(order_date)
ORDER BY YEAR(order_date);

-- Month wise irrespective of year

SELECT
	MONTH(order_date) AS order_month,
	SUM(sales_amount) AS total_sales,
	COUNT(DISTINCT customer_key) AS total_customers,
	SUM(quantity) AS total_quantity
FROM gold.fact_sales
WHERE order_date IS NOT NULL
GROUP BY MONTH(order_date)
ORDER BY MONTH(order_date);

-- Month wise in each year

SELECT
	YEAR(order_date) AS order_year, 
	MONTH(order_date) AS order_month,
	SUM(sales_amount) AS total_sales,
	COUNT(DISTINCT customer_key) AS total_customers,
	SUM(quantity) AS total_quantity
FROM gold.fact_sales
WHERE order_date IS NOT NULL
GROUP BY YEAR(order_date), MONTH(order_date)
ORDER BY YEAR(order_date), MONTH(order_date);

-- OR

SELECT
	DATETRUNC(MONTH, order_date) AS order_date, 
	SUM(sales_amount) AS total_sales,
	COUNT(DISTINCT customer_key) AS total_customers,
	SUM(quantity) AS total_quantity
FROM gold.fact_sales
WHERE order_date IS NOT NULL
GROUP BY DATETRUNC(MONTH, order_date)
ORDER BY DATETRUNC(MONTH, order_date);

-- OR

SELECT
	FORMAT(order_date, 'yyyy-MMM') AS order_date, 
	SUM(sales_amount) AS total_sales,
	COUNT(DISTINCT customer_key) AS total_customers,
	SUM(quantity) AS total_quantity
FROM gold.fact_sales
WHERE order_date IS NOT NULL
GROUP BY FORMAT(order_date, 'yyyy-MMM'), DATETRUNC(MONTH,order_date)
ORDER BY DATETRUNC(MONTH,order_date);

-- Cumulative Analysis
-- calculate the total sales per month
-- and the running total of sales over time 
-- add moving avg price

SELECT
	order_date,
	total_sales,
	SUM(total_sales) OVER(ORDER BY order_date) as running_total_sales,
	SUM(total_sales) OVER(PARTITION BY YEAR(order_date) ORDER BY order_date) as running_year_total_sales,
	AVG(avg_price) OVER(ORDER BY order_date) as moving_avg_price
FROM 
	(SELECT
		DATETRUNC(MONTH, order_date) AS order_date, 
		SUM(sales_amount) AS total_sales,
		AVG(price) as avg_price
	FROM gold.fact_sales
	WHERE order_date IS NOT NULL
	GROUP BY DATETRUNC(MONTH, order_date)
	) t 

-- Performance Analysis

-- Analyze the yearly performance of products by comparing each product's 
-- sale to both its average sales performance and the previous years sales

WITH yearly_products_sales AS (
	SELECT
		YEAR(s.order_date) AS order_year,
		p.product_name,
		SUM(s.sales_amount) AS current_sales
	FROM gold.fact_sales s
	LEFT JOIN gold.dim_products p
	ON p.product_key = s.product_key
	WHERE s.order_date IS NOT NULL
	GROUP BY
		YEAR(s.order_date),
		p.product_name
)
SELECT
	order_year,
	product_name,
	current_sales,
	AVG(current_sales) OVER(PARTITION BY product_name) as avg_sales,
	current_sales - AVG(current_sales) OVER(PARTITION BY product_name) as diff_avg,
	CASE WHEN current_sales - AVG(current_sales) OVER(PARTITION BY product_name) > 0 THEN 'Above Avg'
		WHEN current_sales - AVG(current_sales) OVER(PARTITION BY product_name) < 0 THEN 'Below Avg'
		ELSE 'Avg'
	END AS avg_change,
	LAG(current_sales) OVER(PARTITION BY product_name ORDER BY order_year) AS prev_year_sales,
	current_sales - LAG(current_sales) OVER(PARTITION BY product_name ORDER BY order_year) AS diff_prev_year_sales,
	CASE WHEN current_sales - LAG(current_sales) OVER(PARTITION BY product_name ORDER BY order_year) > 0 THEN 'Increasing'
		WHEN current_sales - LAG(current_sales) OVER(PARTITION BY product_name ORDER BY order_year) < 0 THEN 'Decreasing'
		ELSE 'No Change'
	END AS prev_year_change
FROM yearly_products_sales
ORDER BY product_name, order_year


-- Part-to-Whole Analysis
-- Which categories contribute the most to the overall sales?

WITH category_sales AS (
	SELECT
		p.category,
		SUM(f.sales_amount) as total_sales
	FROM gold.fact_sales f
	LEFT JOIN gold.dim_products p
	ON f.product_key = p.product_key
	GROUP BY p.category
)
SELECT
	category,
	total_sales,
	SUM(total_sales) OVER() AS overall_sales,
	CONCAT(ROUND(CAST(total_sales AS fLOAT)  / SUM(total_sales) OVER() * 100.0, 2), '%') AS percentage_of_total
FROM category_sales
ORDER BY total_sales DESC;


-- Data Segmentation

-- Segment products into cost ranges
-- and count how many products fall into each segement
WITH product_segments AS (
	SELECT
		product_key,
		product_name,
		cost,
		CASE WHEN cost < 100 THEN 'Below 100'
			WHEN cost BETWEEN 100 AND 500 THEN '100-500'
			WHEN cost BETWEEN 500 AND 1000 THEN '500-1000'
			ELSE 'Above 1000'
		END cost_range
	FROM gold.dim_products
	)
SELECT
	cost_range,
	COUNT(product_key) AS total_products
FROM product_segments
GROUP BY cost_range
ORDER BY total_products DESC;

/*
Segment customers into three segments based on their spending behaviour
VIP: at least 12months of histoty and spending more than 5000
Regular: at least 12months of history but spending 5000 or less
New: lifespan less than 12months
and find the total number of customers in each group
*/

WITH customer_spendings AS (
	SELECT
		c.customer_key,
		SUM(f.sales_amount) AS total_spendings,
		MIN(f.order_date) AS first_order_date,
		MAX(f.order_date) AS last_order_date,
		DATEDIFF(MONTH, MIN(f.order_date), MAX(f.order_date)) AS life_span
	FROM gold.fact_sales f
	LEFT JOIN gold.dim_customers c
	ON f.customer_key = c.customer_key
	WHERE order_date IS NOT NULL
	GROUP BY
		c.customer_key
	), 
	customer_segments AS (
	SELECT
		customer_key,
		total_spendings,
		life_span,
		CASE WHEN life_span >= 12 AND total_spendings > 5000 THEN 'VIP'
			WHEN life_span >=12 AND total_spendings <= 5000 THEN 'Regular'
			ELSE 'New'
		END AS customer_segment
	FROM customer_spendings
	)
SELECT
	customer_segment,
	COUNT(customer_key) AS total_customers
FROM customer_segments
GROUP BY customer_segment
ORDER BY total_customers DESC;
