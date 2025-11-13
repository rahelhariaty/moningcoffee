--Monday Coffee Data Analysis

SELECT * FROM morningcoffee.city;
SELECT * FROM morningcoffee.sales;
SELECT * FROM morningcoffee.products;
SELECT * FROM morningcoffee.customer;


--Reports and Data Analysis

--Q.1 Coffee Consumer Count
--How many people in each city are estimated to consume coffee, given that 25% population does?
SELECT 
city_name, 
round(population * 0.25) as customer_count,
city_rank
FROM morningcoffee.city
order by 2 desc;


--Q.2 Total Revenue from coffee sales
-- What is the total revenue generated from coffee sales across all cities last quater 2023
SELECT 
ci.city_name,
sum(total) as revenue,
FROM morningcoffee.sales s
JOIN morningcoffee.customer cu
ON cu.customer_id = s.customer_id
JOIN morningcoffee.city ci
ON cu.city_id = ci.city_id
WHERE EXTRACT(YEAR FROM sale_date) = 2023
AND EXTRACT(QUARTER from sale_date) = 4
GROUP BY ci.city_name
ORDER BY 2 DESC;


--Q.3 Sales count for each product
--How many units if each coffee product have been sold?
SELECT 
p.product_name,
COUNT(s.sale_id) as revenue,
FROM morningcoffee.products p
LEFT JOIN morningcoffee.sales s 
ON s.product_id = p.product_id
GROUP BY p.product_name
ORDER BY 2 DESC;

--Q.4 Average Sales Amount per City
--What is the average sales amount per customer in each city
SELECT 
ci.city_name,
SUM(s.total) revenue,
COUNT(DISTINCT s.customer_id) num_cust,
ROUND(SUM(s.total)/ COUNT(DISTINCT s.customer_id), 2) avg_spend
FROM morningcoffee.sales s
JOIN morningcoffee.customer cu
ON cu.customer_id = s.customer_id
JOIN morningcoffee.city ci
ON cu.city_id = ci.city_id
GROUP BY ci.city_name
ORDER BY 2 DESC;

--Q.5 City Population and Coffee Consumers
--Provide a list of cities along with their population and estimated coffee consumers (25%)

WITH city_table AS
(
    SELECT  
        ci.city_name,
    ROUND((ci.population * 0.25)/1000000,2) est_cust_in_millions,
    FROM morningcoffee.city ci
),

customer_table
AS
(
    SELECT 
        ci.city_name,
        COUNT(DISTINCT cu.customer_id) as num_cust,
    FROM morningcoffee.sales s 
    JOIN morningcoffee.customer cu
    ON s.customer_id = cu.customer_id
    JOIN morningcoffee.city ci
    ON cu.city_id = ci.city_id
    GROUP BY 1)

SELECT 
    city_table.city_name,
    city_table.est_cust_in_millions,
    customer_table.num_cust
FROM city_table 
JOIN customer_table 
ON city_table.city_name = customer_table.city_name
ORDER BY 3 DESC;


--another way
SELECT 
    ci.city_name,
    ci.population,
    ROUND((ci.population * 0.25) / 100000 ,2)AS coffee_consumers_lakhs,
    COUNT(DISTINCT c.customer_id) AS Unique_CX
    
FROM 
    morningcoffee.city as ci
    LEFT JOIN morningcoffee.customer as c ON
    c.city_id = ci.city_id
    
    
    GROUP BY ci.city_id,city_name, population
    ORDER BY 3 DESC;

--Q.6 Top Selling Products by City
-- What are the top 3 selling products in each city?
SELECT *
FROM
(SELECT 
ci.city_name,
p.product_name,
COUNT(s.sale_id) total_sls,
DENSE_RANK() OVER(PARTITION BY ci.city_name ORDER  BY COUNT(s.sale_id) DESC) as rank
FROM morningcoffee.sales s 
JOIN morningcoffee.products p
ON p.product_id = s.product_id
JOIN morningcoffee.customer cu
ON cu.customer_id = s.customer_id
JOIN morningcoffee.city ci
ON ci.city_id = cu.city_id
GROUP BY 1,2
ORDER BY 1,3 DESC) temp
WHERE rank <=3;


--Q.7 Customer Segmentation by City
-- How many unique customers are there in each city who have purchases coffee products?
-- coffee products has product_id 1-14

SELECT 
ci.city_name,
COUNT(DISTINCT cu.customer_id) as num_cust
FROM morningcoffee.city ci
LEFT JOIN morningcoffee.customer cu
ON ci.city_id = cu.city_id
JOIN morningcoffee.sales s 
ON s.customer_id = cu.customer_id
WHERE s.product_id IN (1,2,3,4,5,6,7,8,9,10,11,12,13,14)
GROUP BY 1
ORDER BY 2 DESC;

--Q.8 Average Sale Vs Rent
-- Find each city and their average sale per customer and avg rent per customer
WITH city_table
AS
(
SELECT 
ci.city_name,
SUM(s.total) revenue,
COUNT(DISTINCT s.customer_id) num_cust,
ROUND(SUM(s.total)/ COUNT(DISTINCT s.customer_id), 2) avg_spend
FROM morningcoffee.sales s
JOIN morningcoffee.customer cu
ON cu.customer_id = s.customer_id
JOIN morningcoffee.city ci
ON cu.city_id = ci.city_id
GROUP BY ci.city_name
ORDER BY 2 DESC
),
city_rent
AS
(
SELECT 
ci.city_name,
ci.estimated_rent
FROM morningcoffee.city ci
)
SELECT
city_rent.city_name,
city_rent.estimated_rent,
city_table.num_cust,
city_table.avg_spend,
ROUND((city_rent.estimated_rent/city_table.num_cust),2) avg_rent
FROM city_rent
JOIN city_table
ON city_rent.city_name = city_table.city_name
ORDER BY 5 DESC;


--Q.9 Monthly Sales Growth
-- Sales growth rate: Calculate the percentage growth (or decline) in sales over different time periods(monthly)
WITH
monthly_sls AS
(
SELECT 
    ci.city_name,
    EXTRACT(MONTH FROM s.sale_date) month,
    EXTRACT(YEAR FROM s.sale_date) year,
    SUM(s.total) total_sls
FROM morningcoffee.sales s 
JOIN morningcoffee.customer cu 
ON s.customer_id = cu.customer_id
JOIN morningcoffee.city ci
ON ci.city_id = cu.city_id
GROUP BY 1,2,3
ORDER BY 1,3,2
),
growth_ration AS
(
SELECT 
    city_name,
    month,
    year, 
    total_sls as curr_month_sls,
    LAG(total_sls, 1) OVER(PARTITION BY city_name ORDER BY year, month) as last_month_sls
FROM monthly_sls
)

SELECT 
city_name, 
month,
year,
curr_month_sls,
last_month_sls,
ROUND(((curr_month_sls-last_month_sls)/last_month_sls) * 100,2) growth_ratio
FROM growth_ration
WHERE last_month_sls IS NOT NULL
ORDER BY 1,3,2;


--Q.10 Market Potential Analysis
--Identify top 3 city based on highest sales, return city name, total sale, total rent, total customer, estimated coffee customer

WITH city_table
AS
(
SELECT 
ci.city_name,
SUM(s.total) revenue,
COUNT(DISTINCT s.customer_id) num_cust,
ROUND(SUM(s.total)/ COUNT(DISTINCT s.customer_id), 2) avg_spend
FROM morningcoffee.sales s
JOIN morningcoffee.customer cu
ON cu.customer_id = s.customer_id
JOIN morningcoffee.city ci
ON cu.city_id = ci.city_id
GROUP BY ci.city_name
ORDER BY 2 DESC
),
city_rent
AS
(
SELECT 
ci.city_name,
ci.estimated_rent,
ROUND((ci.population * 0.25)/1000000, 3) as estimated_consumer_in_million
FROM morningcoffee.city ci
)
SELECT
city_rent.city_name,
city_table.revenue,
city_rent.estimated_rent,
city_table.num_cust,
city_rent.estimated_consumer_in_million,
city_table.avg_spend,
ROUND((city_rent.estimated_rent/city_table.num_cust),2) avg_rent
FROM city_rent
JOIN city_table
ON city_rent.city_name = city_table.city_name
ORDER BY 7 DESC;


--Recomendation

--City 1. Pune 
-- * Highest Revenue among other city
-- * Average Rent per customer is one of the lowest
-- * Average Sales per customer also high


--City 2. Jaipur
-- * Highest number of current customer and pretty high on potential customer(1 million)
-- * Lowest on average rent per customer
-- * Top 4 on total revenue and average spending

--City 3. Delhi
-- * Highest on number of potential customer (7.75 millions), and second on current customer number 68
-- * Average rent per customer is pretty low
-- * Average sales per customer in top 5 among other city with highest rent


