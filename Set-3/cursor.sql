
IF OBJECT_ID('dbo.NotificationLog', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.NotificationLog
    (
        NotificationID INT IDENTITY(1,1) PRIMARY KEY,
        SubscriberID INT NOT NULL,
        NotificationMessage VARCHAR(200) NOT NULL,
        CreatedAt DATETIME2 NOT NULL
            CONSTRAINT DF_NotificationLog_CreatedAt DEFAULT (SYSDATETIME()),
        IsRead BIT NOT NULL
            CONSTRAINT DF_NotificationLog_IsRead DEFAULT (0),
        CONSTRAINT FK_NotificationLog_Subscribers
            FOREIGN KEY (SubscriberID)
            REFERENCES dbo.Subscribers(SubscriberID)
    );
END;
GO

/* Task 4 */
CREATE OR ALTER PROCEDURE dbo.usp_CreateLowBalanceNotifications_Cursor
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @SubscriberID INT;
    DECLARE @Balance DECIMAL(12,2);

    DECLARE subscriber_cursor CURSOR LOCAL FAST_FORWARD FOR
        SELECT SubscriberID, Balance
        FROM dbo.Subscribers
        WHERE ServiceType = 'Prepaid'
          AND Balance < 50;

    BEGIN TRY
        OPEN subscriber_cursor;

        FETCH NEXT FROM subscriber_cursor
            INTO @SubscriberID, @Balance;

        WHILE @@FETCH_STATUS = 0
        BEGIN
            INSERT INTO dbo.NotificationLog
                (SubscriberID, NotificationMessage)
            VALUES
                (@SubscriberID,
                 CONCAT('Low balance alert. Current balance: ',
                        CONVERT(VARCHAR(30), @Balance),
                        '. Please recharge.'));

            FETCH NEXT FROM subscriber_cursor
                INTO @SubscriberID, @Balance;
        END;

        CLOSE subscriber_cursor;
        DEALLOCATE subscriber_cursor;
    END TRY
    BEGIN CATCH
        IF CURSOR_STATUS('local', 'subscriber_cursor') >= 0
            CLOSE subscriber_cursor;

        IF CURSOR_STATUS('local', 'subscriber_cursor') > -3
            DEALLOCATE subscriber_cursor;

        THROW;
    END CATCH
END;
GO

 
CREATE OR ALTER PROCEDURE dbo.usp_CreateLowBalanceNotifications_SetBased
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO dbo.NotificationLog
        (SubscriberID, NotificationMessage)
    SELECT
        SubscriberID,
        CONCAT('Low balance alert. Current balance: ',
               CONVERT(VARCHAR(30), Balance),
               '. Please recharge.')
    FROM dbo.Subscribers
    WHERE ServiceType = 'Prepaid'
      AND Balance < 50;
END;
GO

/* Task 4 */

DECLARE @StartTime DATETIME2(7);
DECLARE @CursorTimeMicroseconds BIGINT;
DECLARE @SetBasedTimeMicroseconds BIGINT;

SET @StartTime = SYSDATETIME();
EXEC dbo.usp_CreateLowBalanceNotifications_Cursor;
SET @CursorTimeMicroseconds =
    DATEDIFF_BIG(MICROSECOND, @StartTime, SYSDATETIME());

SET @StartTime = SYSDATETIME();
EXEC dbo.usp_CreateLowBalanceNotifications_SetBased;
SET @SetBasedTimeMicroseconds =
    DATEDIFF_BIG(MICROSECOND, @StartTime, SYSDATETIME());

SELECT
    @CursorTimeMicroseconds AS CursorExecutionTimeMicroseconds,
    @SetBasedTimeMicroseconds AS SetBasedExecutionTimeMicroseconds,
    CASE
        WHEN @CursorTimeMicroseconds < @SetBasedTimeMicroseconds
            THEN 'Cursor was faster in this run'
        WHEN @CursorTimeMicroseconds > @SetBasedTimeMicroseconds
            THEN 'Set-based method was faster in this run'
        ELSE 'Both methods took the same measured time'
    END AS ComparisonResult;
GO

-- Verify notifications:
-- SELECT * FROM dbo.NotificationLog ORDER BY NotificationID DESC;
