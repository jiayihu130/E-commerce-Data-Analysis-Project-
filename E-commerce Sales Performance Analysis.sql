--The following is the description of each column.

--TransactionNo (categorical): a six-digit unique number that defines each transaction. The letter “C” in the code indicates a cancellation.
--Date (numeric): the date when each transaction was generated.
--ProductNo (categorical): a five or six-digit unique character used to identify a specific product.
--Product (categorical): product/item name.
--Price (numeric): the price of each product per unit in pound sterling (£).
--Quantity (numeric): the quantity of each product per transaction. Negative values related to cancelled transactions.
--CustomerNo (categorical): a five-digit unique number that defines each customer.
--Country (categorical): name of the country where the customer resides.
--data cleaning
---check data 
SELECT *
FROM [Salesdata explore]..Salesdata;


EXEC sp_columns 'Salesdata';


ALTER TABLE Salesdata
ALTER COLUMN Date DATE;

ALTER TABLE Salesdata
ALTER COLUMN CustomerNo INT;

ALTER TABLE Salesdata
ALTER COLUMN TransactionNo INT;

BEGIN TRANSACTION;
UPDATE salesdata
SET Date = FORMAT(Date, 'dd-MM-yyyy') 
COMMIT TRANSACTION;

ALTER TABLE salesdata
ADD DateOnly DATE;
UPDATE salesdata
SET DateOnly = CAST(Date AS DATE);




SELECT *
FROM Salesdata
WHERE TransactionNo is null;

SELECT *
FROM Salesdata
WHERE CustomerNo is null;

SELECT *
FROM Salesdata
WHERE ProductNo is null;

SELECT *
FROM [Salesdata explore]..salesdata
WHERE Date is null;
--there is no nulls in these columns 


--check duplicate rows ，if "Customer No" and "Transaction No" are the same, it indicates that a customer has ordered multiple items in a single transaction.

WITH CTE AS (
    SELECT *,
           ROW_NUMBER() OVER (PARTITION BY TransactionNo, DateOnly,ProductNo,ProductName,Price,CustomerNo,Country ORDER BY (SELECT NULL)) AS RowNum
    FROM salesdata
)

SELECT *
FROM CTE
WHERE RowNum > 1
ORDER BY RowNum DESC
--
SELECT *
FROM [Salesdata explore]..Salesdata;

------------------analyse data

--calculate GMV by month

CREATE VIEW MonthlySale AS 
SELECT
    FORMAT(CAST(Date AS DATE), 'yyyy-MM') AS SalesMonth,
    CAST(ROUND(SUM(Price * Quantity ),0) AS int )AS GMV

FROM SalesData
WHERE Quantity>0
GROUP BY
    FORMAT(CAST(Date AS DATE), 'yyyy-MM')
--ORDER BY
--    SalesMonth;

--canceled transaction,we can tell all  transaction cancelled because out of stock 
DROP VIEW canceled_transaction
CREATE VIEW CanceledTransaction AS 
SELECT  SUM (Quantity*Price)AS TotalCancelledValue ,
		SUM(Quantity) As CancelledProducts ,
		FORMAT(CAST(Date AS DATE), 'yyyy-MM') AS SalesMonth
FROM salesdata
WHERE  UPPER(TransactionNo) LIKE 'C%'
GROUP BY FORMAT(CAST(Date AS DATE), 'yyyy-MM');

-- 8585 CANCELLED TRANSACTION 

--top customer 
CREATE VIEW TopCustomer AS 
SELECT CustomerNo, SUM(Price * Quantity) as TotalSpend
FROM salesdata
WHERE Quantity>0
GROUP BY CustomerNo
--ORDER BY TotalSpend DESC;

--total sold products
DROP VIEW ProductPerformance
CREATE VIEW  ProductPerformance AS 
SELECT 
    ProductName, 
    Price,
    SUM(Quantity) AS TotalQuantity,
    SUM(Price * Quantity) AS ProductRevenue,
	FORMAT(CAST(Date AS DATE), 'yyyy-MM') AS SalesMonth
FROM 
    salesdata
WHERE 
    Quantity > 0
GROUP BY 
    FORMAT(CAST(Date AS DATE), 'yyyy-MM'),ProductName, Price
--ORDER BY 
--    TotalQuantity DESC;

Select *from   ProductPerformance 


--reorder quantity '
--Top consumed countries 
DROP VIEW TopConsumedCountries
CREATE VIEW TopConsumedCountries AS 
SELECT Country ,
	   SUM(Price * Quantity) as TotalSpend,
	   COUNT(CustomerNo)as TotalCustomer,
	   FORMAT(CAST(Date AS DATE), 'yyyy-MM') as SalesMonth
FROM salesdata
WHERE Quantity>0
GROUP BY Country,FORMAT(CAST(Date AS DATE), 'yyyy-MM')
--ORDER BY TotalSpend DESC;


select*
from [Salesdata explore]..salesdata
where date is null

SELECT *
FROM [Salesdata explore]..salesdata
WHERE ProductName = 'Mini Jigsaw Spaceboy';

--RFM analysis on customer 
CREATE VIEW RFM_View AS
WITH temp1 AS (
    SELECT 
        CustomerNo,
        MAX(Date) AS RecentDate,
        DATEDIFF(DAY, MAX(Date), '2019-12-09') AS R, -- Calculate the number of days between each customer's purchase date and the last day
        COUNT(DISTINCT TransactionNo) AS F,
        SUM(Quantity) AS M
    FROM 
        salesdata
    GROUP BY 
        CustomerNo
),
temp2 AS ( -- Calculate averages
    SELECT 
        AVG(R) AS avg_R,
        AVG(F) AS avg_F,
        AVG(M) AS avg_M
    FROM 
        temp1
),
--sign the score 
temp3 AS (
    SELECT 
        CustomerNo,
        RecentDate,
        R,
        F,
        M,
        (CASE WHEN R <= (SELECT avg_R FROM temp2) THEN 1 ELSE 0 END) AS R_SCORE,
        (CASE WHEN F >= (SELECT avg_F FROM temp2) THEN 1 ELSE 0 END) AS F_SCORE,
        (CASE WHEN M >= (SELECT avg_M FROM temp2) THEN 1 ELSE 0 END) AS M_SCORE
    FROM 
        temp1
),
temp4 AS (
    SELECT 
        CustomerNo,
        R_SCORE,
        F_SCORE,
        M_SCORE,
        R,
        F,
        M,
        RecentDate,
        (CASE 
            WHEN R_SCORE=1 AND F_SCORE=1 AND M_SCORE=1 THEN 'Important Value Customers'
            WHEN R_SCORE=1 AND F_SCORE=1 AND M_SCORE=0 THEN 'General Value Customers'
            WHEN R_SCORE=1 AND F_SCORE=0 AND M_SCORE=1 THEN 'Important Development Customers'
            WHEN R_SCORE=1 AND F_SCORE=0 AND M_SCORE=0 THEN 'New Customers'
            WHEN R_SCORE=0 AND F_SCORE=0 AND M_SCORE=1 THEN 'Important Retention Customers'
            WHEN R_SCORE=0 AND F_SCORE=1 AND M_SCORE=1 THEN 'Important Maintenance Customers'
            WHEN R_SCORE=0 AND F_SCORE=1 AND M_SCORE=0 THEN 'General Maintenance Customers'
            WHEN R_SCORE=0 AND F_SCORE=0 AND M_SCORE=0 THEN 'Lost Customers'
        END) AS TYPE
    FROM 
        temp3
)
SELECT * FROM temp4;
