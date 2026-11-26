# Set 2 – Insurance Premium Processing: Notes

## Cursor versus set-based approach

| Cursor | Set-based |
|---|---|
| Processes lapsed policies one at a time. | Updates all qualifying policies in one operation. |
| Uses `FETCH` and `WHILE`. | Uses one `UPDATE` statement. |
| More procedural code and overhead. | Usually faster and simpler for multiple rows. |
| Useful when each row needs separate processing. | Preferred when the same update applies to many rows. |

**Conclusion:** The set-based approach is preferred for updating lapsed policies. Both implementations write an audit row for each policy successfully changed to `Lapsed`.

## Assumptions

- A policy is eligible for renewal when its status is `Active` and it has no claim with status `Pending`.
- The no-claim discount is 5% per claim-free year, capped at 25%.
- Renewal extends the due date by one year.
- A policy is considered lapsed when its due date is before today and its status is `Active`.
- SQL scripts assume the tables `Customers`, `Policies` and `Claims` with the columns referenced in the scripts.
- MongoDB uses the `customer_communications` collection with `communicationType` and `status` fields.
