USE RetailDalesDB;
GO

/* required columns for this assignment */
IF COL_LENGTH('dbo.Products', 'CostPrice') IS NULL
    ALTER TABLE dbo.Products ADD CostPrice DECIMAL(10,2) NOT NULL
        CONSTRAINT DF_Products_CostPrice DEFAULT (0);
GO

IF COL_LENGTH('dbo.Products', 'SupplierID') IS NULL
    ALTER TABLE dbo.Products ADD SupplierID INT NULL;
GO

IF COL_LENGTH('dbo.Products', 'StockQuantity') IS NULL
    ALTER TABLE dbo.Products ADD StockQuantity INT NOT NULL
        CONSTRAINT DF_Products_StockQuantity DEFAULT (0);
GO

IF COL_LENGTH('dbo.Orders', 'Status') IS NULL
    ALTER TABLE dbo.Orders ADD Status VARCHAR(20) NOT NULL
        CONSTRAINT DF_Orders_Status DEFAULT ('Pending');
GO

/* task 1a: order summary - does not expose cost price or supplier */
CREATE OR ALTER VIEW dbo.vw_order_summary
AS
    SELECT
        o.OrderID,
        o.OrderDate,
        o.Status,
        c.CustomerID,
        c.CustomerName,
        COUNT(oi.OrderItemID) AS TotalItems,
        SUM(oi.Quantity) AS TotalQuantity,
        SUM(oi.Quantity * oi.UnitPrice) AS OrderAmount
    FROM dbo.Orders AS o
    INNER JOIN dbo.Customers AS c
        ON c.CustomerID = o.CustomerID
    LEFT JOIN dbo.Order_Items AS oi
        ON oi.OrderID = o.OrderID
    GROUP BY
        o.OrderID,
        o.OrderDate,
        o.Status,
        c.CustomerID,
        c.CustomerName;
GO

/* task 1b: products whose available stock is at or below 10 */
CREATE OR ALTER VIEW dbo.vw_low_stock
AS
    SELECT
        ProductID,
        ProductName,
        Category,
        StockQuantity
    FROM dbo.Products
    WHERE StockQuantity <= 10;
GO

/* task 1c: simple single-table view that supports updates.
   WITH CHECK OPTION prevents updates that make StockQuantity negative. */
CREATE OR ALTER VIEW dbo.vw_product_stock_update
AS
    SELECT
        ProductID,
        ProductName,
        StockQuantity
    FROM dbo.Products
    WHERE StockQuantity >= 0
WITH CHECK OPTION;
GO

/* demonstration: view update */
-- UPDATE dbo.vw_product_stock_update
-- SET StockQuantity = 25
-- WHERE ProductID = 1;

-- This update is rejected by WITH CHECK OPTION:
-- UPDATE dbo.vw_product_stock_update
-- SET StockQuantity = -5
-- WHERE ProductID = 1;

-- view output
SELECT * FROM dbo.vw_order_summary;
SELECT * FROM dbo.vw_low_stock;
SELECT * FROM dbo.vw_product_stock_update;
GO
