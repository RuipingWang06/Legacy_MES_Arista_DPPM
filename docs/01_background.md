### 📘 Project Background

This project is initiated based on a request from **Arista**, who seeks enhanced visibility into the materials consumed during the manufacturing of their products. Specifically, they require a detailed breakdown of:

- Material consumption quantity  
- Associated suppliers  
- Part Numbers  
- Manufacturer Part Numbers (MPNs)

#### 📌 Current System & Limitations

The required information exists in our **legacy MES system**, but it is displayed at the **CRD (Component Requirement Document)** level. Users currently rely on the **Purge data page**, which allows them to input a **Serial Number (SN)** to view related data such as:

- CRD  
- Material  
- Description  
- GRN (Goods Receipt Number)  
- Vendor  

However, the existing query logic is tightly coupled to manual SN-level inspection and is not designed for automation or date-based aggregation. Furthermore, **inconsistent join conditions** and the **absence of standardized foreign keys** make it difficult to reuse the queries directly for reporting purposes.

#### 🔍 Project Objective

The goal is to **rebuild the logic** behind these queries to support:

- **Start-date-driven inputs**  
- **Automated aggregation** of consumed material quantities  
- **Accurate supplier and part number mapping**

#### 📤 Expected Deliverable

The final output will be an **automated weekly email report** sent to Arista, containing:

- Consumed Quantity  
- Supplier  
- Part Number  
- MPN  

This report allows the customer to **store and manage the data in their internal systems** for **traceability, analysis, and long-term planning**.
