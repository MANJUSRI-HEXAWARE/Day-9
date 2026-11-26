
/* Audit table for policy renewals */
IF OBJECT_ID('dbo.PolicyRenewalAudit', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.PolicyRenewalAudit
    (
        AuditID INT IDENTITY(1,1) PRIMARY KEY,
        PolicyID INT NOT NULL,
        OldPremium DECIMAL(12,2) NOT NULL,
        NewPremium DECIMAL(12,2) NOT NULL,
        RenewalDate DATETIME2 NOT NULL
            CONSTRAINT DF_PolicyRenewalAudit_RenewalDate DEFAULT (SYSDATETIME()),
        AuditAction VARCHAR(50) NOT NULL
    );
END;
GO

/* Task 3 */
CREATE OR ALTER FUNCTION dbo.fn_PremiumWithNoClaimDiscount
(
    @BasePremium DECIMAL(12,2),
    @NoClaimYears INT
)
RETURNS DECIMAL(12,2)
AS
BEGIN
    DECLARE @DiscountRate DECIMAL(5,4);

    SET @DiscountRate =
        CASE
            WHEN @NoClaimYears <= 0 THEN 0.00
            WHEN @NoClaimYears >= 5 THEN 0.25
            ELSE @NoClaimYears * 0.05
        END;

    RETURN CONVERT(DECIMAL(12,2),
        @BasePremium * (1 - @DiscountRate));
END;
GO

CREATE OR ALTER FUNCTION dbo.fn_AgentRenewalQuotes
(
    @AgentID INT
)
RETURNS TABLE
AS
RETURN
(
    SELECT
        p.PolicyID,
        p.CustomerID,
        c.CustomerName,
        p.PolicyType,
        p.DueDate,
        p.Premium AS CurrentPremium,
        dbo.fn_PremiumWithNoClaimDiscount(
            p.Premium, p.NoClaimYears
        ) AS RenewalQuote
    FROM dbo.Policies AS p
    INNER JOIN dbo.Customers AS c
        ON c.CustomerID = p.CustomerID
    WHERE p.AgentID = @AgentID
      AND p.Status = 'Active'
      AND p.DueDate >= CAST(GETDATE() AS DATE)
      AND p.DueDate < DATEADD(DAY, 31, CAST(GETDATE() AS DATE))
);
GO

/* Task 2*/
CREATE OR ALTER PROCEDURE dbo.usp_RenewPolicy
    @PolicyID INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE
        @OldPremium DECIMAL(12,2),
        @NewPremium DECIMAL(12,2),
        @NoClaimYears INT,
        @DueDate DATE,
        @Status VARCHAR(30);

    BEGIN TRY
        BEGIN TRANSACTION;

        /* Lock the policy row so another session cannot renew it
           simultaneously while this transaction is in progress. */
        SELECT
            @OldPremium = Premium,
            @NoClaimYears = NoClaimYears,
            @DueDate = DueDate,
            @Status = Status
        FROM dbo.Policies WITH (UPDLOCK, HOLDLOCK)
        WHERE PolicyID = @PolicyID;

        IF @OldPremium IS NULL
            THROW 51001, 'Policy not found.', 1;

        IF @Status <> 'Active'
            THROW 51002, 'Only active policies can be renewed.', 1;

        IF EXISTS
        (
            SELECT 1
            FROM dbo.Claims
            WHERE PolicyID = @PolicyID
              AND ClaimStatus = 'Pending'
        )
            THROW 51003, 'Policy cannot be renewed because a claim is pending.', 1;

        SET @NewPremium =
            dbo.fn_PremiumWithNoClaimDiscount(@OldPremium, @NoClaimYears);

        UPDATE dbo.Policies
        SET Premium = @NewPremium,
            DueDate = DATEADD(YEAR, 1, @DueDate),
            Status = 'Active'
        WHERE PolicyID = @PolicyID;

        INSERT INTO dbo.PolicyRenewalAudit
            (PolicyID, OldPremium, NewPremium, AuditAction)
        VALUES
            (@PolicyID, @OldPremium, @NewPremium, 'Policy Renewed');

        COMMIT TRANSACTION;

        SELECT
            @PolicyID AS PolicyID,
            @OldPremium AS OldPremium,
            @NewPremium AS NewPremium,
            DATEADD(YEAR, 1, @DueDate) AS NewDueDate;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0
            ROLLBACK TRANSACTION;

        THROW;
    END CATCH
END;
GO

/* Demonstrations - replace IDs with records from your database. */

-- Renew a policy:
-- EXEC dbo.usp_RenewPolicy @PolicyID = 1;

-- Calculate premium with no-claim discount:
-- SELECT dbo.fn_PremiumWithNoClaimDiscount(10000.00, 3) AS DiscountedPremium;

-- Get renewal quotes for an agent:
-- SELECT * FROM dbo.fn_AgentRenewalQuotes(1);

-- View renewal audit:
-- SELECT * FROM dbo.PolicyRenewalAudit;
GO
