
/* Task 1 */
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
