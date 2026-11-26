/* SET 2 - INSURANCE PREMIUM PROCESSING
   Assumed table:
   Policies(PolicyID, DueDate, Status)

   A policy is treated as having a lapsed premium when its due date
   is earlier than today and its current status is Active.
*/

/* Audit table for lapsed policy status updates */
IF OBJECT_ID('dbo.PolicyLapseAudit', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.PolicyLapseAudit
    (
        AuditID INT IDENTITY(1,1) PRIMARY KEY,
        PolicyID INT NOT NULL,
        OldStatus VARCHAR(30) NOT NULL,
        NewStatus VARCHAR(30) NOT NULL,
        UpdatedAt DATETIME2 NOT NULL
            CONSTRAINT DF_PolicyLapseAudit_UpdatedAt DEFAULT (SYSDATETIME()),
        AuditNote VARCHAR(200) NOT NULL
    );
END;
GO

/* Task 4a: cursor implementation */
CREATE OR ALTER PROCEDURE dbo.usp_LapsePolicies_Cursor
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @PolicyID INT;
    DECLARE @OldStatus VARCHAR(30);

    DECLARE policy_cursor CURSOR LOCAL FAST_FORWARD FOR
        SELECT PolicyID, Status
        FROM dbo.Policies
        WHERE Status = 'Active'
          AND DueDate < CAST(GETDATE() AS DATE);

    BEGIN TRY
        OPEN policy_cursor;

        FETCH NEXT FROM policy_cursor INTO @PolicyID, @OldStatus;

        WHILE @@FETCH_STATUS = 0
        BEGIN
            BEGIN TRANSACTION;

            UPDATE dbo.Policies
            SET Status = 'Lapsed'
            WHERE PolicyID = @PolicyID
              AND Status = 'Active'
              AND DueDate < CAST(GETDATE() AS DATE);

            IF @@ROWCOUNT = 1
            BEGIN
                INSERT INTO dbo.PolicyLapseAudit
                    (PolicyID, OldStatus, NewStatus, AuditNote)
                VALUES
                    (@PolicyID, @OldStatus, 'Lapsed',
                     'Premium due date passed; policy marked as lapsed.');
            END;

            COMMIT TRANSACTION;

            FETCH NEXT FROM policy_cursor INTO @PolicyID, @OldStatus;
        END;

        CLOSE policy_cursor;
        DEALLOCATE policy_cursor;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0
            ROLLBACK TRANSACTION;

        IF CURSOR_STATUS('local', 'policy_cursor') >= 0
            CLOSE policy_cursor;

        IF CURSOR_STATUS('local', 'policy_cursor') > -3
            DEALLOCATE policy_cursor;

        THROW;
    END CATCH
END;
GO

/* Task 4b: set-based equivalent */
CREATE OR ALTER PROCEDURE dbo.usp_LapsePolicies_SetBased
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @ChangedPolicies TABLE
    (
        PolicyID INT,
        OldStatus VARCHAR(30),
        NewStatus VARCHAR(30)
    );

    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        UPDATE dbo.Policies
        SET Status = 'Lapsed'
        OUTPUT
            inserted.PolicyID,
            deleted.Status,
            inserted.Status
        INTO @ChangedPolicies (PolicyID, OldStatus, NewStatus)
        WHERE Status = 'Active'
          AND DueDate < CAST(GETDATE() AS DATE);

        INSERT INTO dbo.PolicyLapseAudit
            (PolicyID, OldStatus, NewStatus, AuditNote)
        SELECT
            PolicyID,
            OldStatus,
            NewStatus,
            'Premium due date passed; policy marked as lapsed.'
        FROM @ChangedPolicies;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0
            ROLLBACK TRANSACTION;

        THROW;
    END CATCH
END;
GO

/* Run one method at a time for demonstration. */
-- EXEC dbo.usp_LapsePolicies_Cursor;
-- EXEC dbo.usp_LapsePolicies_SetBased;

-- Verify status updates and audit records:
-- SELECT PolicyID, Status FROM dbo.Policies WHERE Status = 'Lapsed';
-- SELECT * FROM dbo.PolicyLapseAudit ORDER BY AuditID;
GO
