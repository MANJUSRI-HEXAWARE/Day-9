/* SET 3 - TELECOM LOW-BALANCE FOLLOW-UP
   Assumed tables and columns:
   Subscribers(SubscriberID, SubscriberName, PhoneNumber, ServiceType,
               Balance, PlanID, ValidityEndDate)
   Plans(PlanID, PlanName, IsActive, ...)
   RechargeHistory(RechargeID, SubscriberID, PlanID, Amount, RechargeDate)

   Row-level hiding of postpaid users is implemented by filtering
   ServiceType = 'Prepaid' in vw_prepaid_subscribers.
*/

-- Change the database name to your actual telecom database.
-- USE TelecomDB;
-- GO

/* Task 1a: prepaid subscribers only.
   Postpaid rows are excluded from this view. */
CREATE OR ALTER VIEW dbo.vw_prepaid_subscribers
AS
    SELECT
        s.SubscriberID,
        s.SubscriberName,
        s.PhoneNumber,
        s.Balance,
        s.PlanID,
        s.ValidityEndDate
    FROM dbo.Subscribers AS s
    WHERE s.ServiceType = 'Prepaid';
GO

/* Task 1b: recharge summary per subscriber */
CREATE OR ALTER VIEW dbo.vw_recharge_summary
AS
    SELECT
        s.SubscriberID,
        s.SubscriberName,
        COUNT(r.RechargeID) AS TotalRecharges,
        COALESCE(SUM(r.Amount), 0) AS TotalRechargeAmount,
        MAX(r.RechargeDate) AS LastRechargeDate
    FROM dbo.Subscribers AS s
    LEFT JOIN dbo.RechargeHistory AS r
        ON r.SubscriberID = s.SubscriberID
    GROUP BY
        s.SubscriberID,
        s.SubscriberName;
GO

-- Demonstration
SELECT * FROM dbo.vw_prepaid_subscribers;
SELECT * FROM dbo.vw_recharge_summary;
GO
