# Set 3 – Cursor versus Set-Based Timing Comparison

## What is compared?

Both methods insert one low-balance notification for each prepaid subscriber whose balance is below 50 currency units.

- **Cursor:** Reads matching subscribers one at a time and inserts a notification inside a loop.
- **Set-based:** Inserts notifications for all matching subscribers using one `INSERT ... SELECT` statement.

## Execution time

Run the timing block at the end of `cursor.sql`. It measures each procedure in microseconds and displays both execution times and which method was faster in that run.

| Method | Processing |
|---|---|
| Cursor | Row by row using `FETCH` and `WHILE` |
| Set-based | Multiple rows inserted by one statement |

## Conclusion

The set-based approach is generally faster and uses less procedural overhead because SQL Server can process the qualifying rows together. Actual execution times depend on the number of subscribers, indexes, server load and database environment. Use the measured output from your own SQL Server run when reporting the result.
