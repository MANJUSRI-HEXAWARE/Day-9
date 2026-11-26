USE RetailDalesDB;
GO

/* required order status column */
IF COL_LENGTH('dbo.Orders', 'Status') IS NULL
    ALTER TABLE dbo.Orders ADD Status VARCHAR(20) NOT NULL
        CONSTRAINT DF_Orders_Status DEFAULT ('Pending');
GO

IF COL_LENGTH('dbo.Products', 'StockQuantity') IS NULL
    ALTER TABLE dbo.Products ADD StockQuantity INT NOT NULL
        CONSTRAINT DF_Products_StockQuantity DEFAULT (0);
GO

/* table-valued parameter for one or more products in an order */
IF TYPE_ID('dbo.OrderLineType') IS NULL
    EXEC('CREATE TYPE dbo.OrderLineType AS TABLE
    (
        ProductID INT NOT NULL,
        Quantity INT NOT NULL
    );');
GO

/* task 2: place an order and return its generated OrderID */
CREATE OR ALTER PROCEDURE dbo.usp_PlaceOrder
    @CustomerID INT,
    @OrderLines dbo.OrderLineType READONLY,
    @OrderNumber INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    SET @OrderNumber = NULL;

    BEGIN TRY
        IF NOT EXISTS (SELECT 1 FROM dbo.Customers WHERE CustomerID = @CustomerID)
            THROW 50001, 'Invalid customer ID.', 1;

        IF NOT EXISTS (SELECT 1 FROM @OrderLines)
            THROW 50002, 'At least one order line is required.', 1;

        IF EXISTS (SELECT 1 FROM @OrderLines WHERE Quantity <= 0)
            THROW 50003, 'Order quantity must be greater than zero.', 1;

        IF EXISTS
        (
            SELECT ProductID
            FROM @OrderLines
            GROUP BY ProductID
            HAVING COUNT(*) > 1
        )
            THROW 50004, 'Each product must appear only once in the order.', 1;

        BEGIN TRANSACTION;

        /* Lock product rows while validating stock to prevent concurrent
           orders from selling the same available units. */
        IF EXISTS
        (
            SELECT 1
            FROM @OrderLines AS ol
            LEFT JOIN dbo.Products AS p WITH (UPDLOCK, HOLDLOCK)
                ON p.ProductID = ol.ProductID
            WHERE p.ProductID IS NULL
               OR p.StockQuantity < ol.Quantity
        )
            THROW 50005, 'Invalid product or insufficient stock.', 1;

        INSERT INTO dbo.Orders (CustomerID, OrderDate, Status)
        VALUES (@CustomerID, GETDATE(), 'Pending');

        SET @OrderNumber = CONVERT(INT, SCOPE_IDENTITY());

        INSERT INTO dbo.Order_Items (OrderID, ProductID, Quantity, UnitPrice)
        SELECT
            @OrderNumber,
            p.ProductID,
            ol.Quantity,
            p.UnitPrice
        FROM @OrderLines AS ol
        INNER JOIN dbo.Products AS p
            ON p.ProductID = ol.ProductID;

        UPDATE p
        SET p.StockQuantity = p.StockQuantity - ol.Quantity
        FROM dbo.Products AS p
        INNER JOIN @OrderLines AS ol
            ON ol.ProductID = p.ProductID;

        COMMIT TRANSACTION;

        SELECT @OrderNumber AS OrderNumber;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0
            ROLLBACK TRANSACTION;

        SET @OrderNumber = NULL;
        THROW;
    END CATCH
END;
GO

/* task 3a: scalar function - calculates order total including 18% tax */
CREATE OR ALTER FUNCTION dbo.fn_OrderTotalWithTax
(
    @OrderID INT
)
RETURNS DECIMAL(18,2)
AS
BEGIN
    DECLARE @Subtotal DECIMAL(18,2);

    SELECT @Subtotal = SUM(Quantity * UnitPrice)
    FROM dbo.Order_Items
    WHERE OrderID = @OrderID;

    RETURN CONVERT(DECIMAL(18,2), COALESCE(@Subtotal, 0) * 1.18);
END;
GO

/* task 3b: inline table-valued function - returns a customer's orders */
CREATE OR ALTER FUNCTION dbo.fn_CustomerOrders
(
    @CustomerID INT
)
RETURNS TABLE
AS
RETURN
(
    SELECT
        o.OrderID,
        o.OrderDate,
        o.Status,
        COALESCE(SUM(oi.Quantity * oi.UnitPrice), 0) AS Subtotal,
        CONVERT(DECIMAL(18,2),
            COALESCE(SUM(oi.Quantity * oi.UnitPrice), 0) * 1.18) AS TotalWithTax
    FROM dbo.Orders AS o
    LEFT JOIN dbo.Order_Items AS oi
        ON oi.OrderID = o.OrderID
    WHERE o.CustomerID = @CustomerID
    GROUP BY o.OrderID, o.OrderDate, o.Status
);
GO

/* task 3c: demonstration of procedure and function together */
DECLARE @NewOrderNumber INT;
DECLARE @Lines dbo.OrderLineType;

-- Replace the sample IDs with existing CustomerID and ProductID values.
INSERT INTO @Lines (ProductID, Quantity)
VALUES (1, 2), (2, 1);

-- Execute only when the sample customer/products exist and have enough stock.
-- EXEC dbo.usp_PlaceOrder
--     @CustomerID = 1,
--     @OrderLines = @Lines,
--     @OrderNumber = @NewOrderNumber OUTPUT;
--
-- SELECT @NewOrderNumber AS CreatedOrderNumber,
--        dbo.fn_OrderTotalWithTax(@NewOrderNumber) AS TotalWithTax;
--
-- SELECT *
-- FROM dbo.fn_CustomerOrders(1);

GO
