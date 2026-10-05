# Healthcare SQL Data Analysis & Database Engine

A production-ready MySQL analytics database engine managing complex healthcare operations across 16 relational tables. Features optimized stored procedures, automated audit triggers, and 77 advanced business intelligence queries built to solve real-world clinical, insurance billing, and pharmaceutical supply chain challenges.


A production-ready **MySQL analytics database engine** designed to model, manage, and extract high-impact business intelligence from a complex healthcare ecosystem. This project features a highly normalized schema spanning **16 interrelated tables**, optimized stored procedures, automated audit tracking triggers, and a comprehensive suite of **77 real-time analytical queries** designed to solve critical operational, financial, and supply chain challenges.

---

## 🏗️ Relational Schema Architecture
The database is structured across five core operational pillars to ensure complete data integrity and eliminate redundancies:

*   **Clinical & Patient Management:** `Patients`, `Doctors`, `Appointments`, and `Lab_Results`.
*   **Medical & Encounter Records:** `Medical_Records`, `Prescriptions`, and `Lab_Tests`.
*   **Financial & Billing Systems:** `Hospital_Bills` (aggregating granular consultation, medicine, lab, and treatment fees against insurance contributions).
*   **Supply Chain & Procurement:** `Suppliers`, `Purchase_Orders`, `Purchase_Order_Items`, and `Deliveries`.
*   **Inventory Control & Auditing:** `Medicines`, `Inventory_Audit`, and `Stock_Movement_Audit`.

---

## ⚡ Automation & Advanced Database Programming

### 🔄 Stored Procedures
*   **`GetPatientSummary(p_patient_id)`**: Generates a unified 360-degree patient dossier, dynamically calculating total appointments, medical record counts, gross billings, insurance coverage splits, and net out-of-pocket patient payable amounts.
*   **`GetMedicineInventoryStatus(p_medicine_id)`**: A real-time inventory lookup engine that checks physical stock quantities against defined reorder safety margins, dynamically returning operational flags (`REORDER`, `WATCH`, or `SUFFICIENT`).

### ⚙️ Event-Driven Triggers
*   **`After_Prescription_Insert`**: An automated compliance and data-integrity trigger that instantly logs a record into the `Stock_Movement_Audit` ledger the microsecond a new medication is dispensed, establishing an immutable audit trail for pharmaceutical movement.

---

## 📊 Business Intelligence & Analytics Framework
The repository implements **77 production-grade SQL business queries** to solve real-world healthcare administrative issues:

*   **Financial Performance Analytics:** Tracks month-over-month cash flows, monitors monthly running total revenue streams, evaluates granular payment collection aging statuses (`Pending` vs. `Paid`), and identifies top consumer revenue cohorts.
*   **Advanced Inventory Optimization:** Implements a full **ABC Inventory Categorisation Model** based on cumulative consumption value, and calculates standard deviations alongside coefficients of variation to model demand stability.
*   **Clinical Capacity & Workload Auditing:** Ranks clinicians by treatment revenue using window functions (`RANK() OVER`), assesses doctor appointment densities per department, and identifies operational bottleneck indicators.
*   **Supply Chain & Vendor Accountability:** Conducts rigorous vendor scorecards by calculating contractual **On-Time Delivery Percentages** based on expected delivery deadlines vs. actual arrival timestamps.
*   **Risk & Expiry Management:** Projects pharmaceutical risk windows by isolating medications approaching their expiration dates within critical 180-day operational buffers.
