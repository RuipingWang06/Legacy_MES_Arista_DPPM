### ⚙️ ETL Procedure Overview for ARISTA_DPPM_REPORT

#### 📦 Consumed Quantity Extraction

- Retrieve all Serial Numbers (SNs) from the previous day into an temp table.
- Use a cursor to iterate through each SN.
- For each SN, execute the **Purge data** query to fetch related data:  
  `sql/reference/up_CT_ListCRDsBySerialNumberByCustomer.sql`
- Insert the query results into a temporary table within the loop.
- After all data is collected, aggregate the **Consumed Quantity** by:
  - Supplier  
  - MPN (Manufacturer Part Number)  
  - Material

#### ❌ Failed Quantity Extraction

- Review the user's query conditions used when calling the API.
- Analyze the API's internal SQL to understand the default filter conditions.
- Identify the gap between the default logic and the user's requirement.
- Refine the logic to only return **FailedQty** records where **replacement occurred**.
- Aggregate **FailedQty** by:
  - Supplier  
  - MPN  
  - Material

#### 🧾 Final Data Preparation

- Join the aggregated **FailedQty** data with the **ConsumedQty** dataset on matching dimensions.
- Insert the final joined result into the `ARISTA_DPPM_REPORT` table.
- Schedule a **SQL Server Agent Job** to run this procedure **daily at 1:00 AM**.
