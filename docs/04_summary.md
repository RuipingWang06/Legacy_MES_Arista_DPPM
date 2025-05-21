### 🔍 Data Testing Summary

- **Challenge with data volume:**  
  One day's CRD-level data is too large to open in Excel, making testing difficult.

- **Daily data validation needs:**  
  Since users test data on a daily basis, we decided to:
  - Export the detailed records in CSV format.
  - Build a Power BI report so users can explore the data flexibly.

- **Initial approach (no cursor):**  
  - We started by modifying the logic to process **one Serial Number (SN)** at a time by joining it with a temporary SN table.
  - However, we didn’t validate enough SNs during testing.
  - We overlooked that the **unusual join condition** could cause inconsistent results:
    - Some SNs correctly mapped to their suppliers.
    - Others failed to match due to timing overlap issues.
      
- **Improved approach (with cursor):**
  - We switched to using a cursor to loop through each SN.
  - For each SN, we retrieved and inserted the result into a temporary table.
  - After the loop completed, we had the full result set for all SNs on that day.
