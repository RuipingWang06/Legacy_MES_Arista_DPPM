### 📘 Project Background

This project was initiated at the request of **Arista** to enhance visibility into material consumption during product manufacturing. The key focus areas are:

- Material Consumed Qty
- Failed Qty
- Suppliers  
- Part Numbers  
- Manufacturer Part Numbers (MPNs)

---

### 🛠️ Current System Challenges

#### 🔹 ConsumedQty 

- Data is stored in the **legacy MES system** at the **CRD (Component Requirement Document)** level.
- Accessed through the **Purge Data** page using a **Serial Number (SN)**.
- The output includes: CRD, Material, Description, GRN, Vendor, etc.
- QE currently needs to manually summarize consumed quantities by **Supplier**, **Part Number**, and **MPN**.

**Limitations:**

- **Manual SN-based queries** — not suitable for date-based reporting.

#### 🔹 FailedQty (Failure/Rework Data)

- Accessed through an **API** based on `analysisStartDate` and other parameters.

**Limitations:**

- Does **not support filtering by rework date**
- not able return failures including **component replacement**.
  
---

### 🎯 Project Objectives

- Enable **start-date-driven inputs**.
- Enable **automated aggregation** of:
  - Consumed quantities  
  - Failed quantities  
- Ensure accurate mapping of:
  - Supplier  
  - Part Number  
  - Manufacturer Part Number (MPN)

---

### 📤 Deliverables

#### 1. Automated Weekly Email excel to Arista

Includes:
- Consumed Quantity  
- Supplier  
- Part Number  
- MPN  

> Purpose: To import the data into Arista’s internal systems for further analysis and traceability.

#### 2. Internal Power BI Report

Includes:
- Start Date  
- Consumed Quantity  
- Failed Quantity
- DPPM
- Supplier  
- Part Number  
- MPN

> To enable our internal team to monitor DPPM (Defective Parts Per Million) on a daily basis.
