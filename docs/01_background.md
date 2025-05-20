### 📘 Project Background

This project was initiated at the request of **Arista**, aiming to improve visibility into materials consumed during product manufacturing. The key focus areas include:

- Material consumption quantity  
- Suppliers  
- Part Numbers  
- Manufacturer Part Numbers (MPNs)

---

### 🛠️ Current System & Challenges

#### 🔹 ConsumedQty (Consumption Data)

- Data resides in the **legacy MES system**, presented at the **CRD (Component Requirement Document)** level.
- Accessed via the **Purge data page** using **Serial Number (SN)**.
- Output includes: CRD, Material, Description, GRN, Vendor.

**Limitations:**

- Manual SN-based queries — not suitable for date-based reporting.
- Inconsistent join logic and lack of standardized foreign keys.

#### 🔹 FailedQty (Failure/Rework Data)

- Accessed through an **API** based on `analysisStartDate` and other parameters.
- Only includes **failures involving component replacement**.
- Does **not support filtering by rework date**.

---

### 🎯 Project Objectives

- Redesign query logic to support **start-date-driven inputs**.
- Enable **automated aggregation** of:
  - Consumed quantities  
  - Failed quantities  
- Ensure accurate mapping of:
  - Supplier  
  - Part Number  
  - Manufacturer Part Number (MPN)

---

### 📤 Deliverables

#### 1. Automated Weekly Email Report to Arista

Includes:
- Consumed Quantity  
- Supplier  
- Part Number  
- MPN  

> Purpose: For traceability, analysis, and long-term planning in Arista's internal systems.

#### 2. Internal Power BI Report

Includes:
- Start Date  
- Consumed Quantity  
- Failed Quantity  
- Supplier  
- Part Number  
- MPN
