### 📘 Project Background

This project is initiated based on a request from **Arista**, who seeks enhanced visibility into the materials consumed during the manufacturing of their products. Specifically, they require a detailed breakdown of:

- Material consumption quantity  
- Associated suppliers  
- Part Numbers  
- Manufacturer Part Numbers (MPNs)

#### 📌 Current System & Limitations

#### **ConsumedQty**

The required information resides in the **legacy MES system**, presented at the **CRD (Component Requirement Document)** level. Users currently rely on the **Purge data page**, where a **Serial Number (SN)** is used to retrieve the following information:

- CRD  
- Material  
- Description  
- GRN (Goods Receipt Number)  
- Vendor  

However, the existing query logic is tightly coupled to manual SN-level access and is not suitable for automation or date-based aggregation. Additionally, **inconsistent join conditions** and the **absence of standardized foreign keys** hinder the transformation of these queries into a reusable reporting solution.

#### **FailedQty**

Failure-related data is also stored in the **legacy MES system**, but accessed through an **API** that retrieves repair records based on `analysisStartDate` and various other parameters. This logic does **not align with the requirement** to extract data by **rework date**, and it only returns failed records that involve component replacement.

Consequently, the logic must be **redesigned** to apply the correct filters and ensure accurate extraction of both failure and rework-related quantities.


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
