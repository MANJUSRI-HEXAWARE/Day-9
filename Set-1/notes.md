# Set 1 – Retail Order Fulfilment: Notes

## 1. Cursor versus set-based approach

| Cursor-based approach | Set-based approach |
|---|---|
| Processes one order at a time. | Processes all qualifying orders in one statement. |
| Uses `DECLARE CURSOR`, `OPEN`, `FETCH`, `WHILE`, `CLOSE` and `DEALLOCATE`. | Uses one `INSERT INTO ... SELECT` statement. |
| Easier to follow when each row needs separate procedural work. | Usually faster and more efficient for bulk operations. |
| Has more code and cursor-management overhead. | Has less code and avoids row-by-row processing. |
| Suitable when each record needs different sequential handling. | Preferred when the same operation can be applied to many rows. |

**Conclusion:** The set-based statement is preferred for creating follow-up records because all pending orders older than three days can be processed together. The cursor version is included to demonstrate row-by-row processing.

Both procedures check `OrderFollowUps` before inserting, preventing an existing order from receiving another follow-up when the procedure is run again.

## 2. SQL Server view versus MongoDB view

- A SQL Server view is a virtual table based on a `SELECT` query. It can combine relational tables using joins, filters and grouping.
- A MongoDB view is a read-only view based on an aggregation pipeline over a collection or another view.
- SQL Server views can be updatable in supported cases. The `vw_product_stock_update` view is a simple single-table view, and `WITH CHECK OPTION` prevents changes that would make a row fail its view condition.
- MongoDB views are read-only. Documents cannot be inserted, updated or deleted through the view.
- The MongoDB view in this assignment groups documents in the `orders` collection by `status` and returns the count for each status.

## 3. Scalar function, inline table-valued function and stored procedure

| Feature | Scalar function | Inline table-valued function | Stored procedure |
|---|---|---|---|
| Example | `fn_OrderTotalWithTax` | `fn_CustomerOrders` | `usp_PlaceOrder` |
| Returns | One scalar value | A table (rows and columns) | Can return result sets and output parameters |
| Main purpose | Calculates one order's total including 18% tax. | Lists a customer's orders and totals. | Places an order and changes stock. |
| Data modification | Not used for modifying database data. | Not used for modifying database data. | Can insert and update data. |
| Invocation | `SELECT dbo.fn_OrderTotalWithTax(1)` | `SELECT * FROM dbo.fn_CustomerOrders(1)` | `EXEC dbo.usp_PlaceOrder ...` |

**Conclusion:** Functions are used to calculate or return data. The stored procedure performs the order placement because it must validate stock and make multiple database changes in one transaction.

## 4. Transaction handling in `usp_PlaceOrder`

1. Checks whether the customer exists.
2. Checks that order lines are supplied and quantities are positive.
3. Checks that each product occurs only once in the input.
4. Starts a transaction and locks the relevant product rows while validating stock.
5. Inserts the order header and order lines.
6. Decreases the product stock.
7. Commits the transaction if all operations succeed.
8. Rolls back and raises the error if any operation fails.

The generated `OrderID` is returned through the `@OrderNumber OUTPUT` parameter.

## 5. Assumptions and execution notes

- The SQL scripts use the existing `RetailDalesDB` database and the tables `Customers`, `Products`, `Orders` and `Order_Items`.
- Existing columns used are:
  - `Customers`: `CustomerID`, `CustomerName`
  - `Products`: `ProductID`, `ProductName`, `Category`, `UnitPrice`
  - `Orders`: `OrderID`, `CustomerID`, `OrderDate`
  - `Order_Items`: `OrderItemID`, `OrderID`, `ProductID`, `Quantity`, `UnitPrice`
- The scripts add `Products.CostPrice`, `Products.SupplierID`, `Products.StockQuantity` and `Orders.Status` if they do not already exist.
- The low-stock threshold is assumed to be 10 units.
- The tax rate is assumed to be 18%.
- New orders are created with status `Pending`.
- The MongoDB example expects an `orders` collection containing a `status` field. The SQL Server database and MongoDB database are separate; the MongoDB view operates on MongoDB documents, not SQL Server tables.
- Run `views.sql`, `procedures.sql` and `cursor.sql` in SQL Server Management Studio. Run `mongo_view.js` in `mongosh` after selecting the MongoDB database containing `orders`.
- Replace the sample customer and product IDs in the commented procedure demonstration with IDs that exist in your database. Ensure those products have sufficient stock before executing the order procedure.
