
/* Task 2 */
CREATE OR ALTER PROCEDURE dbo.usp_Recharge
    @SubscriberID INT,
    @PlanID INT,
    @Amount DECIMAL(12,2),
    @NewBalance DECIMAL(12,2) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    SET @NewBalance = NULL;

    DECLARE
        @OldBalance DECIMAL(12,2),
        @MinAmount DECIMAL(12,2),
        @MaxAmount DECIMAL(12,2),
        @ValidityDays INT,
        @ServiceType VARCHAR(20);

    BEGIN TRY
        IF @Amount IS NULL OR @Amount <= 0
            THROW 52001, 'Recharge amount must be greater than zero.', 1;

        BEGIN TRANSACTION;

        /* Lock subscriber and plan records during validation/update. */
        SELECT
            @OldBalance = s.Balance,
            @ServiceType = s.ServiceType
        FROM dbo.Subscribers AS s WITH (UPDLOCK, HOLDLOCK)
        WHERE s.SubscriberID = @SubscriberID;

        IF @OldBalance IS NULL
            THROW 52002, 'Subscriber not found.', 1;

        IF @ServiceType <> 'Prepaid'
            THROW 52003, 'Recharge is allowed only for prepaid subscribers.', 1;

        SELECT
            @MinAmount = p.MinRechargeAmount,
            @MaxAmount = p.MaxRechargeAmount,
            @ValidityDays = p.ValidityDays
        FROM dbo.Plans AS p WITH (HOLDLOCK)
        WHERE p.PlanID = @PlanID
          AND p.IsActive = 1;

        IF @MinAmount IS NULL
            THROW 52004, 'Invalid or inactive recharge plan.', 1;

        IF @Amount < @MinAmount OR @Amount > @MaxAmount
            THROW 52005, 'Recharge amount is outside the selected plan limits.', 1;

        UPDATE dbo.Subscribers
        SET Balance = Balance + @Amount,
            PlanID = @PlanID,
            ValidityEndDate =
                CASE
                    WHEN ValidityEndDate IS NULL
                      OR ValidityEndDate < CAST(GETDATE() AS DATE)
                    THEN DATEADD(DAY, @ValidityDays, CAST(GETDATE() AS DATE))
                    ELSE DATEADD(DAY, @ValidityDays, ValidityEndDate)
                END
        WHERE SubscriberID = @SubscriberID;

        INSERT INTO dbo.RechargeHistory
            (SubscriberID, PlanID, Amount, RechargeDate)
        VALUES
            (@SubscriberID, @PlanID, @Amount, GETDATE());

        SELECT @NewBalance = Balance
        FROM dbo.Subscribers
        WHERE SubscriberID = @SubscriberID;

        COMMIT TRANSACTION;

        SELECT @NewBalance AS NewBalance;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0
            ROLLBACK TRANSACTION;

        SET @NewBalance = NULL;
        THROW;
    END CATCH
END;
GO

/* Task 3 */
CREATE OR ALTER FUNCTION dbo.fn_ValidityDaysLeft
(
    @SubscriberID INT
)
RETURNS INT
AS
BEGIN
    DECLARE @EndDate DATE;

    SELECT @EndDate = ValidityEndDate
    FROM dbo.Subscribers
    WHERE SubscriberID = @SubscriberID;

    IF @EndDate IS NULL
        RETURN NULL;

    RETURN
        CASE
            WHEN @EndDate < CAST(GETDATE() AS DATE) THEN 0
            ELSE DATEDIFF(DAY, CAST(GETDATE() AS DATE), @EndDate)
        END;
END;
GO

/* Task 3*/
CREATE OR ALTER FUNCTION dbo.fn_LastFiveRecharges
(
    @SubscriberID INT
)
RETURNS TABLE
AS
RETURN
(
    SELECT TOP (5)
        r.RechargeID,
        r.SubscriberID,
        r.PlanID,
        r.Amount,
        r.RechargeDate
    FROM dbo.RechargeHistory AS r
    WHERE r.SubscriberID = @SubscriberID
    ORDER BY r.RechargeDate DESC, r.RechargeID DESC
);
GO

/* Demonstrations - replace sample IDs with IDs in your database. */
-- DECLARE @Balance DECIMAL(12,2);
-- EXEC dbo.usp_Recharge
--     @SubscriberID = 1,
--     @PlanID = 1,
--     @Amount = 100.00,
--     @NewBalance = @Balance OUTPUT;
-- SELECT @Balance AS ReturnedNewBalance;

-- SELECT dbo.fn_ValidityDaysLeft(1) AS ValidityDaysLeft;
-- SELECT * FROM dbo.fn_LastFiveRecharges(1);
GO
