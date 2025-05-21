### Lesson learn
- **Query Development**
  - When reviewing documents, if only columns and tables are mentioned, follow up to confirm which **system screen** the data comes from.
  - Every page for a system—whether it uses APIs or procedures—should have **underlying SQL logic**.
  - Always identify and request the **correct reference logic** from the system owner.
  - **Do not build SQL logic on your own** without confirmed source references.

- **Challenge with data volume:**  
  One day's CRD-level data is too large to open in Excel, making testing difficult.

- **Daily data validation needs:**  
  Since users test data on a daily basis, we decided to:
  - Export the detailed records in CSV format.
  - Build a Power BI report so users can explore the data flexibly.
  - Validate Purger data match with details (count and attributes )and details match with daily summary.

- **Initial approach (no cursor):**  
  - We started by modifying the logic to process **one Serial Number (SN)** at a time by joining it with a temporary SN table.
  - However, we didn’t validate enough SNs during testing , need to take more than 30 SN for testing.
  - We overlooked that the **unusual join condition** could cause inconsistent results:
    - Some SNs correctly mapped to their suppliers.
    - Others failed to match due to timing overlap issues.
- **Join condition that caused issues:**
  ```sql
  (z.StartTime BETWEEN d.LoadTime AND d.RemovalTime)
  OR (z.StartTime >= d.LoadTime AND d.RemovalTime IS NULL)
  OR (z.EndTime BETWEEN d.LoadTime AND d.RemovalTime)
  OR (z.EndTime >= d.LoadTime AND d.RemovalTime IS NULL)
      
- **Improved approach (with cursor):**
  - We switched to using a cursor to loop through each SN.
  - For each SN, we retrieved and inserted the result into a temporary table.
  - After the loop completed, we had the full result set for all SNs on that day.
 
- **Limitation of Paginated Report**
  - Paginated reports can be sent via email with an attached Excel file using the subscription feature.
  - However, the **filename cannot include dynamic parameters** (e.g., date).
  - If the user requires a **dynamic filename with date**, consider sending the report directly from **SQL Server** instead.
  - SQL Server can send emails with attachments using a **stored procedure**.

