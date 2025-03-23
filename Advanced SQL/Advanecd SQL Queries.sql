--Advanced SQL Questions Based on Microsoft's Wide World Importers Sample Database--
--Ido Porat--

--Question 1--
/* Write a SQL query that calculates the annual sales amount and the linear annual revenue for each year.
In addition, calculate the growth rate of the linear annual revenue compared to the previous year */

WITH CTE1
AS
(
SELECT DISTINCT YEAR (o.OrderDate) AS 'Year', Month (o.OrderDate) AS 'Month',
       SUM(ol.UnitPrice*ol.PickedQuantity) OVER(PARTITION BY YEAR (o.OrderDate)) AS 'IncomePerYear'
  FROM Sales.OrderLines ol JOIN Sales.Orders o
  ON ol.OrderID=o.OrderID
),
CTE2
AS
(
SELECT Year, IncomePerYear, COUNT(Month) AS 'NumberOfDistinctMonths'
  FROM CTE1
  GROUP BY Year, IncomePerYear
),
CTE3
AS
(
SELECT Year, IncomePerYear, NumberOfDistinctMonths,
       CAST ((IncomePerYear/NumberOfDistinctMonths)*12 AS DECIMAL (18,2)) AS 'YearlyLinearIncome',
	   LAG(CAST ((IncomePerYear/NumberOfDistinctMonths)*12 AS DECIMAL (18,2)), 1) OVER(ORDER BY Year) AS 'Lag'
  FROM CTE2
)

SELECT Year, IncomePerYear, NumberOfDistinctMonths, YearlyLinearIncome,
       CAST (((YearlyLinearIncome/Lag)-1)*100 AS DECIMAL (18,2)) AS 'Growth Rate'
  FROM CTE3;

--Question 2--
/* Write a SQL query that shows the top 5 customers in each quarter of the year based on net income. */

WITH CTE1
AS
(
SELECT DISTINCT YEAR (o.OrderDate) AS 'Year', DATEPART (qq, o.OrderDate) AS 'Quarter',
                c.CustomerName,
                SUM(ol.UnitPrice*ol.PickedQuantity) OVER(PARTITION BY YEAR (o.OrderDate), DATEPART (qq, o.OrderDate), c.CustomerName) AS 'IncomePerYear'
  FROM Sales.OrderLines ol JOIN Sales.Orders o
    ON ol.OrderID=o.OrderID
  JOIN Sales.Customers c
    ON o.CustomerID=c.CustomerID
),
CTE2
AS
(
SELECT Year, Quarter, CustomerName, IncomePerYear,
       DENSE_RANK() OVER(PARTITION BY Year, Quarter ORDER BY IncomePerYear DESC) AS 'DNR'
  FROM CTE1
)

SELECT Year, Quarter, CustomerName, IncomePerYear, DNR
  FROM CTE2
  WHERE DNR <=5;

--Question 3--
/* Write a SQL query that finds the top 10 products that generated the highest total profit based on sold lines.
You should rank the products by total profit and return the item ID, item name, and their total profit.
Total profit calculation: Difference between ExtendedPrice and TaxAmount */

WITH CTE1
AS
(
SELECT DISTINCT il.StockItemID, si.StockItemName,
                SUM(il.ExtendedPrice-il.TaxAmount) OVER(PARTITION BY il.StockItemID) AS 'TotalProfit'
  FROM Sales.InvoiceLines il JOIN Warehouse.StockItems si 
    ON il.StockItemID=si.StockItemID
),
CTE2
AS
(
SELECT StockItemID, StockItemName, TotalProfit,
       DENSE_RANK() OVER(ORDER BY TotalProfit DESC) AS 'DNR'
  FROM CTE1
)

SELECT StockItemID, StockItemName, TotalProfit
  FROM CTE2
  WHERE DNR<=10;

--Question 4--
/* Write a SQL query to find all stock items that are still valid,
calculate their nominal profit (difference between the recommended retail price and the unit price),
and rank the items in descending order of nominal profit.
Also include the serial number of each item in this order */

WITH CTE1
AS
(
SELECT StockItemID, StockItemName, UnitPrice, RecommendedRetailPrice,
       (RecommendedRetailPrice-UnitPrice) AS 'NominalProductProfit'
  FROM Warehouse.StockItems
 WHERE ValidTo > '2016-05-31'
)

SELECT ROW_NUMBER() OVER(ORDER BY NominalProductProfit DESC) AS 'RN',
       StockItemID, StockItemName, UnitPrice, RecommendedRetailPrice, NominalProductProfit,
       DENSE_RANK() OVER(ORDER BY NominalProductProfit DESC) AS 'DNR'
  FROM CTE1;

--Question 5--
/* Write a SQL query that displays for each supplier ID and name a list of stock items provided by that supplier,
with the list separated by ‘ / ’.
Include the item ID and name from the stock items. */

SELECT CONCAT (ps.SupplierID, ' - ', ps.SupplierName) AS 'SupplierDetails',
       STRING_AGG (CONCAT (ws.StockItemID, ' ', ws.StockItemName),' /, ') AS 'ProductDetails'
FROM Purchasing.Suppliers ps JOIN Warehouse.StockItems ws
  ON ps.SupplierID=ws.SupplierID
GROUP BY ps.SupplierID ,ps.SupplierName;

--Question 6--
/* Write a SQL query that displays the top 5 customers by the total amount spent (ExtendedPrice),
including their geographic location details. */

WITH CTE1
AS
(
SELECT DISTINCT sc.CustomerID, act.CityName,
       acr.CountryName, acr.Continent, acr.Region,
	   SUM(sil.ExtendedPrice) OVER(PARTITION BY sc.CustomerID) AS 'ExtendedPrice'
  FROM Sales.InvoiceLines sil JOIN Sales.Invoices si
    ON sil.InvoiceID=si.InvoiceID
  JOIN Sales.Customers sc
    ON si.CustomerID=sc.CustomerID
  JOIN Application.Cities act
    ON sc.DeliveryCityID=act.CityID
  JOIN Application.StateProvinces asp
    ON act.StateProvinceID=asp.StateProvinceID
  JOIN Application.Countries acr
    ON asp.CountryID=acr.CountryID
)

SELECT TOP (5) CustomerID, CityName, CountryName,
               Continent, Region,
			   FORMAT (ExtendedPrice, '#,##.##') AS 'TotalExtendedPrice'
  FROM CTE1
  ORDER BY ExtendedPrice DESC;

--Question 7--
/* Write a SQL query that shows the total quantity of items ordered for each month in a year,
and also shows the cumulative total for each year.
Include a summary row that aggregates the data for the entire year. */

WITH CTE1
AS
(
SELECT YEAR (so.OrderDate) AS 'OrderYear',
       MONTH (so.OrderDate) AS 'OrderMonth',
	   SUM(sol.PickedQuantity*sol.UnitPrice) AS 'MonthlyTotal'
  FROM Sales.OrderLines sol JOIN Sales.Orders so
    ON sol.OrderID=so.OrderID
	GROUP BY GROUPING SETS ((YEAR (so.OrderDate)), (YEAR (so.OrderDate), MONTH (so.OrderDate)))
),
CTE2
AS
(
SELECT OrderYear, ISNULL (CAST (OrderMonth AS VARCHAR), 'Grand Total') AS 'OrderMonth', MonthlyTotal,
       SUM (MonthlyTotal) OVER(PARTITION BY OrderYear ORDER BY OrderYear ROWS BETWEEN 11 PRECEDING AND CURRENT ROW) AS 'ComulativeTotal'
  FROM CTE1
)

SELECT OrderYear, OrderMonth, FORMAT (MonthlyTotal, '#,##.##') AS 'MonthlyTotal',
       CASE
	        WHEN OrderMonth='Grand Total' THEN FORMAT (MonthlyTotal, '#,##.##')
			ELSE FORMAT (ComulativeTotal, '#,##.##')
	   END AS 'ComulativeTotal' 
  FROM CTE2;

--Question 8--
/* Present a matrix showing the number of orders made each month in a year. */

SELECT OrderMonth, [2013], [2014], [2015], [2016]
  FROM (SELECT OrderID, YEAR (OrderDate) AS 'OrderYear', MONTH (OrderDate) AS 'OrderMonth'
          FROM Sales.Orders) p
 PIVOT (COUNT(OrderID) FOR OrderYear IN ([2013], [2014], [2015], [2016])) AS pvt
 ORDER BY OrderMonth

--Question 9--
/* Identify potential customer churn based on their ordering patterns.
A customer is considered a "potential churn" if the time since their last order is more than double their average time between orders.
For each customer, show:
-Customer ID
-Customer Name
-Date of Last Order
-Number of Days Since Last Order
-Average Time Between Orders (in days)
-Status: "Potential Churn" or "Active" */

WITH CTE1
AS
(
SELECT o.CustomerID, c.CustomerName, o.OrderDate,
       LAG (o.OrderDate, 1) OVER (PARTITION BY o.CustomerID ORDER BY o.OrderDate) AS 'PreviousOrderDate',
	   MAX (o.OrderDate) OVER (PARTITION BY o.CustomerID) AS 'LastOrder'
  FROM Sales.Orders o JOIN Sales.Customers c
    ON o.CustomerID=c.CustomerID
),
CTE2
AS
(
SELECT CustomerID, CustomerName, OrderDate, PreviousOrderDate,
       DATEDIFF (dd, LastOrder, '2016-05-31') As 'DaysSinceLastOrder',
	   AVG (DATEDIFF (dd, PreviousOrderDate, OrderDate)) OVER (PARTITION BY CustomerID) AS 'AvgDaysBetweenOrders'
  FROM CTE1
)

SELECT CustomerID, CustomerName, OrderDate, PreviousOrderDate,
       DaysSinceLastOrder, AvgDaysBetweenOrders,
	   CASE
	        WHEN DaysSinceLastOrder>(AvgDaysBetweenOrders*2) THEN 'Potential Churn'
			ELSE 'Active'
	   END AS 'CustomerStatus'
  FROM CTE2;

--Question 10--
/* Write a query that examines the company’s business risk by customer categories.
Identify the categories with the highest number of unique customers,
focusing on customers with general names starting with "Tailspin" or "Wingtip".
Calculate the relative distribution of customers in each category out of the total,
and assess where the highest risk exists based on customer concentration in each category. */

WITH CTE1
AS
(
SELECT DISTINCT CASE
            WHEN c.CustomerName LIKE '%Tailspin%' THEN 'Tailspin'
			WHEN c.CustomerName LIKE '%Wingtip%' THEN 'Wingtip'
			ELSE c.CustomerName
	   END AS 'CustName',
       cc.CustomerCategoryName
  FROM Sales.Customers c JOIN Sales.CustomerCategories cc
    ON c.CustomerCategoryID=cc.CustomerCategoryID
),
CTE2
AS
(
SELECT DISTINCT CustomerCategoryName,
       COUNT (CustName) OVER (PARTITION BY CustomerCategoryName ORDER BY CustomerCategoryName) AS 'CustomerCOUNT',
	   COUNT (CustName) OVER () AS 'TotalCustCOUNT'
  FROM CTE1
)

SELECT CustomerCategoryName, CustomerCOUNT, TotalCustCOUNT, 
       FORMAT ((CAST (CustomerCOUNT AS DECIMAL (5,2))) / (CAST (TotalCustCOUNT AS DECIMAL (5,2)))*100, '#.##') + '%' AS 'DistributionFactor'
  FROM CTE2;