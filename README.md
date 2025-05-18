# Legacy-MES-DPPM-Calcualtion

This repository contains a **stored procedure** Source from **Legacy MES** used to calculate **Consumed Qty**, **Failed Qty**, **PartNumber**, **Supplier**,**MPN**,**StartDate** on a daily basis, typically for manufacturing or quality control use cases.

## 🛠️ Features

- Daily tracking of consumption and failure quantities
- DPPM calculation for quality KPI monitoring 
- Easy to integrate with BI dashboards (e.g. Power BI, Streamlit)

## 💡 DPPM Formula
DPPM = [FailedQty]/[ConsumedQty] * 10000000
