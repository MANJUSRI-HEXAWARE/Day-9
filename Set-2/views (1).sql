/* SET 2 - INSURANCE PREMIUM PROCESSING
   Assumed existing tables:
   Customers(CustomerID, CustomerName, Email, Phone, ...)
   Policies(PolicyID, CustomerID, AgentID, PolicyType, Premium,
            DueDate, Status, NoClaimYears, ...)

   Sensitive customer columns (for example DOB, national ID, bank details)
   are deliberately not selected in the view.
*/

-- Change the database name to your actual insurance database.
-- USE InsuranceDB;
-- GO

CREATE OR ALTER VIEW dbo.vw_policy_due
AS
    SELECT
        p.PolicyID,
        p.PolicyType,
        p.Premium,
        p.DueDate,
        p.Status,
        c.CustomerID,
        c.CustomerName,
        c.Email,
        c.Phone
    FROM dbo.Policies AS p
    INNER JOIN dbo.Customers AS c
        ON c.CustomerID = p.CustomerID
    WHERE p.DueDate >= CAST(GETDATE() AS DATE)
      AND p.DueDate < DATEADD(DAY, 31, CAST(GETDATE() AS DATE));
GO

-- Display policies due within the next 30 days.
SELECT *
FROM dbo.vw_policy_due;
GO
