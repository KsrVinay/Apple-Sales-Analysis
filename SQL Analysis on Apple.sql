--top 10 selling products--

SELECT oi.product_id, p.product_name, COUNT(o.order_id) AS total_orders, TO_CHAR(SUM(oi.quantity*oi.price_per_unit), '$999,999,999.00') AS total_sales
FROM products p
JOIN 
order_items oi ON p.product_id = oi.product_id
JOIN
orders o ON o.order_id=oi.order_id
GROUP BY
1, 2
ORDER BY
SUM(oi.quantity*oi.price_per_unit) DESC
LIMIT 10;

ALTER TABLE order_items
ADD COLUMN total_sales FLOAT;

UPDATE order_items
SET total_sales = price_per_unit*quantity;

SELECT * FROM order_items;

--Revenue by each category--

SELECT 
	p. category_id,
	c.category_name,
	SUM(oi.total_sales) AS sales, 
	ROUND(CAST((SUM(oi.total_sales)/
					(SELECT SUM(total_sales) FROM order_items)
					*100) AS NUMERIC),2) AS revenue_contribution
FROM order_items oi
JOIN products p ON oi.product_id = p.product_id
LEFT JOIN category c ON p.category_id = c.category_id
GROUP BY 1,2
ORDER BY 3 DESC;

--AOV of each customer with more than 5 orders--

SELECT
	c.customer_id,
	CONCAT(c.first_name,' ',c.last_name) AS name,
	ROUND(CAST(SUM(oi.total_sales)/COUNT(o.order_id) AS NUMERIC),2) AS AOV,
	COUNT(o.order_id) AS total_orders
FROM customer c
JOIN orders o ON o.customer_id = c.customer_id
JOIN order_items oi ON oi.order_id = o.order_id
GROUP BY 1,2
HAVING COUNT(o.order_id)>5
ORDER BY AOV DESC;

--Monthly Sales Trend for Past Year, Current Month & Past Month--

SELECT 
	year,
	month,
	sales as current_month_sale,
	LAG(sales,1) OVER (
	ORDER BY 
	year,month) AS last_month_sale
	FROM
		(SELECT
		EXTRACT(MONTH FROM o.order_date) AS month,
		EXTRACT(YEAR FROM o.order_date) AS year,
		ROUND(SUM(oi.total_sales::numeric),2) AS sales
		FROM orders o
		JOIN order_items oi ON o.order_id=oi.order_id
		WHERE order_date >= CURRENT_DATE - INTERVAL '1 year'
		GROUP BY 1,2
		ORDER BY year,month) as t1;

--Customers with no purchases--

SELECT * FROM customer
WHERE customer_id NOT IN 
(SELECT DISTINCT 
customer_id
FROM orders);

--or--
SELECT * FROM customer c
LEFT JOIN orders o
ON o.customer_id=c.customer_id
WHERE o.customer_id IS NULL;

--Best selling product category by state--

WITH ranking_table AS(
SELECT 
	cu.state,
	c.category_name,
	ROUND(SUM(oi.total_sales::numeric),2) as total_sale,
	RANK() OVER (PARTITION BY cu.state ORDER BY SUM(oi.total_sales) DESC) AS rank
FROM customer cu
JOIN orders o
ON o.customer_id=cu.customer_id
JOIN
order_items oi ON
oi.order_id = o.order_id
JOIN
products p ON
oi.product_id = p.product_id
JOIN
category c ON
p.category_id = c.category_id
GROUP BY 1,2
ORDER BY 4 ASC
)
SELECT 
	state,
	category_name,
	total_sale
FROM 
ranking_table
WHERE rank =1;


-- Least selling category by state --

WITH ranking_table AS(
SELECT 
	cu.state,
	c.category_name,
	ROUND(SUM(oi.total_sales::numeric),2) as total_sale,
	RANK() OVER (PARTITION BY cu.state ORDER BY SUM(oi.total_sales) ASC) AS rank
FROM customer cu
JOIN orders o
ON o.customer_id=cu.customer_id
JOIN
order_items oi ON
oi.order_id = o.order_id
JOIN
products p ON
oi.product_id = p.product_id
JOIN
category c ON
p.category_id = c.category_id
GROUP BY 1,2
ORDER BY 4 ASC
)
SELECT 
	state,
	category_name,
	total_sale
FROM 
ranking_table
WHERE rank =1;

--Customer Leftime Value--
SELECT 
	CONCAT(c.first_name, ' ', last_name) AS name,
	SUM(oi.total_sales) AS total_sale,
	RANK() OVER (ORDER BY SUM(oi.total_sales) DESC) AS Rank
FROM
customer c
JOIN orders o ON c.customer_id = o.customer_id
JOIN order_items oi ON oi.order_id = o.order_id	
GROUP BY 1;


-- Inventory Stock Alerts -- 

SELECT 
	i.inventory_id,
	p.product_name,
	i.warehouse_id,
	i.last_stock_date,
	i.stock AS current_stock_left
FROM inventory i
JOIN products p
ON p.product_id = i.product_id
WHERE 
	stock < 10
ORDER BY
5;

-- Shipping Delays --
SELECT 
	o.order_id,
	c.customer_id,
	s.shipping_provder,
	s.shipping_date - o.order_date as days_took_to_ship
FROM shipping s
JOIN orders o
ON o.order_id = s.order_id
JOIN customer c
ON c.customer_id = o.customer_id
WHERE s.shipping_date - o.order_date > 4;

--Payment success rate across all orders--

SELECT
	p.payment_status,
	COUNT(o.order_id) AS no_of_orders,
	ROUND(COUNT(*)::numeric/ (SELECT COUNT(*) FROM payment)::numeric,2) AS percent_status
FROM orders o
JOIN payment p
ON p.order_id = o.order_id
GROUP BY 1
ORDER BY 3 DESC;

--Top 5 sellers--

WITH top_sellers AS

(SELECT
	s.seller_id,
	s.seller_name,
	SUM(oi.total_sales) AS total_sale
FROM seller s
JOIN orders o
ON s.seller_id = o.seller_id
JOIN order_items oi
ON oi.order_id = o.order_id
GROUP BY 1,2
ORDER BY 2 DESC
LIMIT 5),

seller_reporters AS

(SELECT 
	o.seller_id,
	ts.seller_name,
	o.order_status,
	COUNT(*) AS total_orders,
	SUM(ts.total_sale)
FROM orders o
JOIN
top_sellers ts
ON ts.seller_id= o.seller_id
WHERE o.order_status NOT IN ('Inprogress','Returned')
GROUP BY 1,2,3 )

SELECT
	seller_id,
	seller_name,
	SUM(CASE WHEN order_status = 'Completed' THEN total_orders ELSE 0 END) as Completed_orders,
	SUM(CASE WHEN order_status = 'Cancelled' THEN total_orders ELSE 0 END) as failed_orders,
	SUM(total_orders) AS total_orders,
	ROUND(SUM(CASE WHEN order_status = 'Completed' THEN total_orders ELSE 0 END)::numeric/SUM(total_orders)::numeric,2) AS successful_orders
FROM seller_reporters
GROUP BY 1,2;

--Profit Margin of Products--

SELECT
	p.product_id,
	p.product_name,
	ROUND(SUM(oi.total_sales-(p.cogs*oi.quantity))::numeric,2) AS profit,
	ROUND((SUM(oi.total_sales-(p.cogs*oi.quantity))/SUM(oi.total_sales))::numeric,2) AS profit_margin,
	DENSE_RANK() OVER (ORDER BY (ROUND((SUM(oi.total_sales-(p.cogs*oi.quantity))/SUM(oi.total_sales))::numeric,2)) DESC) AS Rank
FROM order_items oi
JOIN products p
ON p.product_id = oi.product_id
GROUP BY
1,2
ORDER BY 
4 DESC;

--Most Returned Products--

SELECT 
	p.product_name,
	COUNT(*) AS total_unit_sold,
	SUM(CASE WHEN o.order_status = 'Returned' THEN 1 ELSE 0 END) AS orders_returned,
	ROUND(SUM(CASE WHEN o.order_status = 'Returned' THEN 1 ELSE 0 END)::numeric/COUNT(o.order_id)::numeric,2)*100 AS return_percent
	--(SELECT COUNT(o.order_id) FROM shipping WHERE return_date IS NOT NULL) AS orders_returned		
FROM order_items oi
JOIN products p
ON p.product_id = oi.product_id
JOIN orders o
ON oi.order_id = o.order_id
--JOIN 
--ON p.product_id = oi.product_id
GROUP BY 1
ORDER BY 4 DESC;


--Inactive Sellers from last 6 months--

WITH inactive_sellers AS
(SELECT *
FROM seller 
WHERE seller_id NOT IN (
						SELECT seller_id from orders 
						WHERE order_date <= CURRENT_DATE - INTERVAL '6 month')
						)
						
SELECT 
	o.seller_id,
	MAX(o.order_date) AS last_order_date,
	MAX(oi.total_sales) AS total_sale
FROM orders o
JOIN inactive_sellers iss
ON iss.seller_id = o.seller_id
JOIN order_items oi
ON oi.order_id = o.order_id
GROUP BY 1

--Returning and new customers--
SELECT 
	full_name AS customer_name,
	no_of_orders,
	returns,
	(CASE WHEN returns>5 THEN 'New' ELSE 'Returning_Customer' END) AS customer_category
FROM(	
SELECT
	CONCAT(c.first_name,' ',c.last_name) AS full_name,
	COUNT(*) AS no_of_orders,
	SUM(CASE WHEN o.order_status = 'Returned' THEN 1 ELSE 0 END) AS returns
FROM orders o 
JOIN customer c
ON c.customer_id = o.customer_id
JOIN order_items oi 
ON oi.order_id = o.order_id
GROUP BY 1)


--Top 5 customers by Orders in Each State--
SELECT *
FROM(
SELECT 
	c.state,
	CONCAT(c.first_name,' ',c.last_name) AS full_name,
	COUNT(*) AS no_of_orders,
	SUM(oi.total_sales),
	RANK() OVER (PARTITION BY c.state ORDER BY (COUNT(*)) DESC) AS customer_ranking
FROM orders o 
JOIN customer c
ON c.customer_id = o.customer_id
JOIN order_items oi 
ON oi.order_id = o.order_id
GROUP BY 1,2)

WHERE customer_ranking < 6;


--Revenue by Shipping Provider--

SELECT
	s.shipping_provder,
	ROUND(AVG(s.shipping_date-o.order_date)::numeric,2) AS avg_delievery_time_in_days,
	COUNT(o.order_id) AS orders_handled,
	ROUND(SUM(oi.total_sales)::numeric,2) AS total_sale
FROM orders o
JOIN order_items oi
ON o.order_id = oi.order_id
JOIN shipping s
ON s.order_id=o.order_id
GROUP BY
1;


--Top 10 product with descreasing ratio --

WITH py_sales AS
(
SELECT
	p.product_id,
	p.product_name,
	o.order_date,
	EXTRACT (YEAR FROM o.order_date) AS year,
	SUM(oi.total_sales) AS PY_sale
FROM products p
JOIN order_items oi
ON oi.product_id = p.product_id
JOIN orders o
ON o.order_id = oi.order_id
WHERE o.order_date >= CURRENT_DATE - INTERVAL '2 year'
GROUP BY 1,2,3
ORDER BY 2),

cy_sales AS
(
SELECT
	p.product_id,
	p.product_name,
	o.order_date,
	EXTRACT (YEAR FROM o.order_date) AS year,
	SUM(oi.total_sales) AS CY_sale
FROM products p
JOIN order_items oi
ON oi.product_id = p.product_id
JOIN orders o
ON o.order_id = oi.order_id
WHERE o.order_date >= CURRENT_DATE - INTERVAL '1 year'
GROUP BY 1,2,3
ORDER BY 2)

SELECT 
	t2.product_name,
	t2.CY_sale AS Current_year_revenue,
	t1.PY_sale AS Previous_year_revenue,
	t2.CY_sale-t1.PY_sale AS rev_diff,
	ROUND((t2.CY_sale-t1.PY_sale)::numeric/t1.PY_sale::numeric,2)*100 AS revenue_ratio
FROM
 py_sales t1
JOIN cy_sales t2 
ON t1.product_id=t2.product_id
WHERE
(t1.py_sale -1)>t2.cy_sale
GROUP BY 1,2,3
ORDER BY 5 ASC
LIMIT 10;

--Creat Store Procedure--

CREATE OR REPLACE PROCEDURE add_sales
(
p_order_id INT,
p_order_date INT,
p_customer_id INT,
p_seller_id INT,
p_order_item_id INT,
p_product_id INT,
p_quantity INT,

)
LANGUAGE plpgsql
AS $$

DECLARE
--ALL VARIABLE
v_count INT;
v_price FLOAT;
v_product VARCHAR(50):

BEGIN 
-- fetching product name and price based p id entered
	SELECT price, 
		 product_name
		INTO 
		v_price, v_product
		FROM products
	WHERE product_id = p_product_id;

-- checking stock and product availaibility in inventory
SELECT 
	COUNT(*)
	INTO 
	v_count
FROM inventory
WHERE 
	product_id = p_product_id
	AND
	stock>= p_quantity;
	
IF v_count >0 THEN
	INSERT INTO orders(order_id,order_date,customer_id,seller_id)
	VALUES
	(p_order_id, CURRENT_DATE, p_customer_id, p_seller_id);

	-- adding into order list
	INSERT INTO order_items(order_item_id,order_id,product_id,quantity,price_per_unit,total_sale)
	VALUES
	(p_order_item_id,p_order_id,p_product_id,p_quantity,v_price,v_price*p_quantity);

	--updating inventory
	UPDATE inventory
	SET stock = stock - p_quantity
	WHERE product_id = p_product_id;

	RAISE NOTICE ': % Product sale has been added also inventory stock updates'
	
ELSE 

 RAISE NOTICE 'Thank you for your info the product: % is not available'

END IF;


END;
$$

