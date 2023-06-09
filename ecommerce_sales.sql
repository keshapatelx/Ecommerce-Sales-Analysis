-- Create a new database named ecommerce_sales
CREATE DATABASE ecommerce_sales;

-- Switch to the newly created database
USE ecommerce_sales;

-- 1. STATISTICS REGARDING DATASET --
-- Total number of orders
SELECT COUNT('Order ID') AS Total_Orders
FROM order_details;

-- Total number of products sold
SELECT SUM(Quantity) AS Products_Sold
FROM order_details;

-- Total profit from all orders
SELECT SUM(Profit) AS Total_Profit
FROM order_details;

-- Total number of customers
SELECT COUNT(Distinct CustomerName) AS Customers
FROM list_of_orders;

-- Average price of products sold
SELECT AVG(Amount) AS Avg_price
FROM order_details;

-- Least and most expensive products
SELECT 'Least Expensive Product' AS Product, MIN(Amount) AS Price
FROM order_details
UNION ALL
SELECT 'Most Expensive Product' AS Product, MAX(Amount) AS Price
FROM order_details;

-- 2. ANALYTICAL QUESTIONS --
-- Order status (Profit, Loss, None)
SELECT *,
CASE WHEN Profit > 0 THEN 'Profit'
     WHEN Profit < 0 THEN 'Loss'
     ELSE 'None'
     END AS Order_Status
FROM order_details;

-- Count the number of orders by order status
WITH cte_status AS 
(SELECT *,
CASE WHEN Profit > 0 THEN 'Profit'
     WHEN Profit < 0 THEN 'Loss'
     ELSE 'None'
     END AS Order_Status
FROM order_details)
SELECT Order_Status, COUNT('Order ID') AS Count
FROM cte_status
GROUP BY Order_Status
ORDER BY Count DESC;

-- Total cost price for each order
WITH cte_CP AS
(SELECT `Order ID` AS order_id, (Amount * Quantity) AS CostPrice
FROM order_details)
SELECT order_id, SUM(CostPrice) AS Total_CostPrice
FROM cte_CP
GROUP BY order_id;

-- Count the number of orders by category
SELECT  Category, COUNT('Order ID') AS Orders
FROM order_details
GROUP BY Category
ORDER BY Orders DESC;

-- Count the number of orders by sub-category within each category
SELECT Category, `Sub-Category`, COUNT('Order ID') AS Orders
FROM order_details
GROUP BY Category, `Sub-Category`
ORDER BY Category, Orders DESC;

-- Target sales by category
SELECT Category, SUM(Target) AS target_sales
FROM sales_target
GROUP BY category
ORDER BY category;

-- Profit by category
SELECT category, SUM(profit) AS profit
FROM order_details
GROUP BY category
ORDER BY profit DESC;

-- Top 3 subcategories with the highest profit for each category
SELECT 
    Category, 
    `Sub-Category`, 
    Total_Profit
FROM (
    SELECT 
        Category, 
        `Sub-Category`, 
        SUM(Profit) AS Total_Profit, 
        ROW_NUMBER() OVER (PARTITION BY Category ORDER BY SUM(Profit) DESC) AS rn
    FROM order_details 
    GROUP BY Category, `Sub-Category`
) t
WHERE rn <= 3
ORDER BY Category, Total_Profit DESC;

-- Top 5 cities with highest profit 
SELECT l.city, SUM(o.profit) AS profit
FROM list_of_orders l
JOIN order_details o
ON l.`Order ID` = o.`Order ID`
GROUP BY l.city
ORDER BY profit DESC
LIMIT 5;

-- Total quantity of orders by state 
SELECT l.state, SUM(o.quantity) qty
FROM list_of_orders l
JOIN order_details o
ON l.`Order ID` = o.`Order ID`
GROUP BY l.state
ORDER BY qty DESC;

-- Count the number of Customers per State
SELECT COUNT(`Order ID`) AS customer_counts, state
FROM list_of_orders
GROUP BY state
ORDER BY customer_counts DESC;

-- Total revenue earned 
SELECT SUM((amount*quantity)+profit) AS revenue
FROM order_details;

-- Revenue generated by each category
SELECT category, SUM((amount*quantity)+profit) AS revenue
FROM order_details
GROUP BY category
ORDER BY revenue DESC;

-- Count the number of orders by customer age group
WITH cte_AgeGroup AS ( 
SELECT * , 
CASE WHEN Age BETWEEN 15 AND 20 THEN 'Age Group 15-20' 
WHEN Age BETWEEN 21 AND 30 THEN 'Age Group 21-30'
WHEN Age BETWEEN 31 AND 40 THEN 'Age Group 31-40'
ELSE 'Age Group 41-50' END AS AgeBucket
FROM list_of_orders) 

SELECT c.AgeBucket, COUNT(o.`Order ID`) AS Count_Orders
FROM cte_AgeGroup c
JOIN order_details o
ON c.`Order ID` = o.`Order ID`
GROUP BY AgeBucket 
ORDER BY AgeBucket;

-- Count the number of orders for each month
SELECT DATE_FORMAT(`Order Date`, '%M-%Y') AS OrderDate, count(1) AS orders
FROM list_of_orders
GROUP BY OrderDate;

-- 3. RFM ANALYSIS --
-- Creating and Populating a New RFM Table with Basic Customer Data 
CREATE TABLE RFM (
  `Order ID` VARCHAR(10),
  min_recency INT,
  sum_quantity INT,
  total_amount INT,
  PRIMARY KEY (`Order ID`)
);

INSERT INTO RFM (`Order ID`, min_recency, sum_quantity, total_amount)
SELECT r.`Order ID`, r.min_recency, f.sum_quantity, m.total_amount
FROM (
  SELECT `Order ID`, MIN(DATEDIFF('2019-03-31', `Order Date`)) AS min_recency
  FROM list_of_orders
  WHERE `Order Date` BETWEEN '2018-04-01' AND '2019-03-31'
  GROUP BY `Order ID`
) r
JOIN (
  SELECT `Order ID`, SUM(quantity) AS sum_quantity
  FROM order_details
  GROUP BY `Order ID`
) f ON r.`Order ID` = f.`Order ID`
JOIN (
  SELECT `Order ID`, SUM(amount) AS total_amount
  FROM order_details
  GROUP BY `Order ID`
) m ON r.`Order ID` = m.`Order ID`;

-- Calculating R-score for each customer
ALTER TABLE RFM ADD COLUMN R_SCORE INT;

UPDATE RFM
SET R_SCORE = 
    CASE 
        WHEN min_recency = 364 OR min_recency > 253 THEN 1 
        WHEN min_recency >= 253 OR min_recency > 145 THEN 2 
        WHEN min_recency >= 145 OR min_recency > 65 THEN 3
        ELSE 4 
    END;
    
-- Calculating F-score for each customer
ALTER TABLE RFM ADD COLUMN F_SCORE INT;

UPDATE RFM
SET F_SCORE = 
    CASE 
		WHEN sum_quantity = 57 OR sum_quantity > 35 THEN 4 
		WHEN sum_quantity >= 35 OR sum_quantity > 15 THEN 3
		WHEN sum_quantity >= 15 OR sum_quantity > 5 THEN 2
		ELSE 1 	
	END;

-- Calculating M-score for each customer
ALTER TABLE RFM ADD COLUMN M_SCORE INT;

UPDATE RFM
SET M_SCORE = 
    CASE 
		WHEN total_amount >= 8502 OR total_amount > 6000 THEN 4 
		WHEN total_amount >= 6000 OR total_amount > 3000 THEN 3
		WHEN total_amount >= 3000 OR total_amount > 1000 THEN 2
		ELSE 1 
	END;

-- Calculating RFM-score for each customer
ALTER TABLE RFM ADD COLUMN RFM_SCORE INT;

UPDATE RFM
SET RFM_SCORE = R_SCORE*100 + F_SCORE*10 + M_SCORE;

-- Customer segmentation
ALTER TABLE RFM ADD COLUMN `Customer segment` VARCHAR(20);

UPDATE RFM
SET `Customer segment` =
    CASE 
        WHEN RFM_SCORE >= 421 THEN 'Platinum Customer'
        WHEN RFM_SCORE >= 277 THEN 'Gold Customer'
        WHEN RFM_SCORE >= 194 THEN 'Silver Customer'
        ELSE 'Bronze Customer' 
    END;
    
-- Customer Count by Segment
SELECT `Customer segment`, COUNT(1) AS Customers 
FROM RFM
GROUP BY `Customer segment`;

-- Count of Customers by R Score
SELECT R_Score, COUNT(1) AS Customers 
FROM RFM
GROUP BY R_Score
ORDER BY R_Score DESC;

-- Count of Customers by F Score
SELECT F_Score, COUNT(1) AS Customers 
FROM RFM
GROUP BY F_Score
ORDER BY F_Score DESC;

-- Count of Customers by M Score
SELECT M_Score, COUNT(1) AS Customers 
FROM RFM
GROUP BY M_Score
ORDER BY M_Score DESC;