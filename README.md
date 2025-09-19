# Legacy-MES-DPPM-Calcualtion

This repository contains a stored procedure (Complex SQL) sourced from a legacy MES system that calculates Consumed Qty, Failed Qty, Part Number, Supplier, MPN, and Start Date on a daily basis. A paginated report is then generated and automatically delivered via excel attachment to clients weekly, typically for manufacturing or quality control use cases..

## 🛠️ Features

- Daily tracking of consumption and failure quantities
- DPPM calculation for quality KPI monitoring 
- Easy to integrate with BI dashboards (e.g. Power BI, Streamlit)

## 💡 DPPM Formula
DPPM = [FailedQty]/[ConsumedQty] * 10000000
