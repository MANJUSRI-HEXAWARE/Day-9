USE RetailDalesDB;
GO

/* table to store follow-up records */
IF OBJECT_ID('dbo.OrderFollowUps', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.OrderFollowUps
    (
        FollowUpID INT IDENTITY(1,1) PRIMARY KEY,
        OrderID INT NOT NULL,
        FollowUpDate DATETIME NOT NULL
            CONSTRAINT DF_OrderFollowUps_FollowUpDate DEFAULT (GETDATE()),
        FollowUpNote VARCHAR(200) NOT NULL,
        CONSTRAINT FK_OrderFollowUps_Orders
            FOREIGN KEY (OrderID) REFERENCES dbo.Orders(OrderID)
    );
END;
GO

/* task 4a: cursor-based processing of pending orders older than 3 days */
CREATE OR ALTER PROCEDURE dbo.usp_CreatePendingOrderFollowUps_Cursor
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @OrderID INT;

    DECLARE order_cursor CURSOR LOCAL FAST_FORWARD FOR
        SELECT OrderID
        FROM dbo.Orders
        WHERE Status = 'Pending'
          AND OrderDate < DATEADD(DAY, -3, GETDATE());

    BEGIN TRY
        OPEN order_cursor;

        FETCH NEXT FROM order_cursor INTO @OrderID;

        WHILE @@FETCH_STATUS = 0
        BEGIN
            IF NOT EXISTS
            (
                SELECT 1
                FROM dbo.OrderFollowUps
                WHERE OrderID = @OrderID
            )
            BEGIN
                INSERT INTO dbo.OrderFollowUps (OrderID, FollowUpNote)
                VALUES (@OrderID, 'Order has been pending for more than three days.');
            END;

            FETCH NEXT FROM order_cursor INTO @OrderID;
        END;

        CLOSE order_cursor;
        DEALLOCATE order_cursor;
    END TRY
    BEGIN CATCH
        IF CURSOR_STATUS('local', 'order_cursor') >= 0
            CLOSE order_cursor;

        IF CURSOR_STATUS('local', 'order_cursor') > -3
            DEALLOCATE order_cursor;

        THROW;
    END CATCH
END;
GO

/* task 4b: set-based equivalent - processes all qualifying orders in one statement */
CREATE OR ALTER PROCEDURE dbo.usp_CreatePendingOrderFollowUps_SetBased
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO dbo.OrderFollowUps (OrderID, FollowUpNote)
    SELECT
        o.OrderID,
        'Order has been pending for more than three days.'
    FROM dbo.Orders AS o
    WHERE o.Status = 'Pending'
      AND o.OrderDate < DATEADD(DAY, -3, GETDATE())
      AND NOT EXISTS
      (
          SELECT 1
          FROM dbo.OrderFollowUps AS f
          WHERE f.OrderID = o.OrderID
      );
END;
GO

/* run either implementation; do not run both for the same demonstration
   unless you want to verify that duplicate follow-ups are prevented. */
-- EXEC dbo.usp_CreatePendingOrderFollowUps_Cursor;
-- EXEC dbo.usp_CreatePendingOrderFollowUps_SetBased;

SELECT *
FROM dbo.OrderFollowUps
ORDER BY FollowUpID;
GO
