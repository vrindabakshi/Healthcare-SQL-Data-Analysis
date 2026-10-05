-- ============================================================
-- HEALTHCARE ANALYTICS - REAL-TIME BUSINESS QUERIES
-- ============================================================

-- 1. Business Problem: Which patients have total hospital bills above the average patient spending?
SELECT p.patient_id, p.patient_name, SUM(b.final_amount) AS total_spending
FROM Patients p
JOIN Hospital_Bills b ON p.patient_id = b.patient_id
GROUP BY p.patient_id, p.patient_name
HAVING SUM(b.final_amount) > (
    SELECT AVG(patient_total)
    FROM (
        SELECT SUM(final_amount) AS patient_total
        FROM Hospital_Bills
        GROUP BY patient_id
    ) x
)
ORDER BY total_spending DESC;

-- 2. Business Problem: Which medicines are priced higher than the average medicine price?
SELECT medicine_id, medicine_name, category, unit_price
FROM Medicines
WHERE unit_price > (SELECT AVG(unit_price) FROM Medicines)
ORDER BY unit_price DESC;

-- 3. Business Problem: Which doctors handle more appointments than the average doctor?
SELECT d.doctor_id, d.doctor_name, COUNT(a.appointment_id) AS appointment_count
FROM Doctors d
JOIN Appointments a ON d.doctor_id = a.doctor_id
GROUP BY d.doctor_id, d.doctor_name
HAVING COUNT(a.appointment_id) > (
    SELECT AVG(appointment_count)
    FROM (
        SELECT COUNT(*) AS appointment_count
        FROM Appointments
        GROUP BY doctor_id
    ) x
)
ORDER BY appointment_count DESC;

-- 4. Business Problem: How much revenue was generated in each month?
SELECT DATE_FORMAT(bill_date,'%Y-%m') AS revenue_month,
       SUM(final_amount) AS total_revenue
FROM Hospital_Bills
GROUP BY DATE_FORMAT(bill_date,'%Y-%m')
ORDER BY revenue_month;

-- 5. Business Problem: Which patients have generated more than 20,000 in total bills?
SELECT p.patient_name, SUM(b.final_amount) AS total_spending
FROM Patients p
JOIN Hospital_Bills b ON p.patient_id = b.patient_id
GROUP BY p.patient_id, p.patient_name
HAVING SUM(b.final_amount) > 20000
ORDER BY total_spending DESC;

-- 6. Business Problem: Which medicines currently have physical stock at or below their reorder level?
SELECT m.medicine_id, m.medicine_name, m.reorder_level,
       ia.physical_stock
FROM Medicines m
JOIN Inventory_Audit ia ON m.medicine_id = ia.medicine_id
WHERE ia.physical_stock <= m.reorder_level
ORDER BY ia.physical_stock;

-- 7. Business Problem: How are doctors ranked by treatment revenue within each department?
WITH Doctor_Revenue AS (
    SELECT d.doctor_id, d.doctor_name, d.department_id,
           SUM(mr.treatment_cost) AS revenue
    FROM Doctors d
    LEFT JOIN Medical_Records mr ON d.doctor_id = mr.doctor_id
    GROUP BY d.doctor_id, d.doctor_name, d.department_id
)
SELECT doctor_name, department_id, revenue,
       RANK() OVER (PARTITION BY department_id ORDER BY revenue DESC) AS department_rank
FROM Doctor_Revenue;

-- 8. Business Problem: Which medicines are consumed the most?
SELECT m.medicine_name, SUM(p.quantity) AS total_quantity
FROM Medicines m
JOIN Prescriptions p ON m.medicine_id = p.medicine_id
GROUP BY m.medicine_id, m.medicine_name
ORDER BY total_quantity DESC;

-- 9. Business Problem: What is the running total of hospital revenue by month?
WITH Monthly_Revenue AS (
    SELECT DATE_FORMAT(bill_date,'%Y-%m') AS revenue_month,
           SUM(final_amount) AS revenue
    FROM Hospital_Bills
    GROUP BY DATE_FORMAT(bill_date,'%Y-%m')
)
SELECT revenue_month, revenue,
       SUM(revenue) OVER (ORDER BY revenue_month) AS running_revenue
FROM Monthly_Revenue;

-- 10. Business Problem: How many days passed between each patient's appointments?
SELECT patient_id, appointment_date,
       LAG(appointment_date) OVER (
           PARTITION BY patient_id ORDER BY appointment_date
       ) AS previous_appointment
FROM Appointments
ORDER BY patient_id, appointment_date;

-- 11. Business Problem: Which medicines contribute the most to medicine consumption value?
WITH Medicine_Value AS (
    SELECT m.medicine_id, m.medicine_name, m.unit_price,
           SUM(p.quantity) AS quantity_used,
           m.unit_price * SUM(p.quantity) AS consumption_value
    FROM Medicines m
    JOIN Prescriptions p ON m.medicine_id = p.medicine_id
    GROUP BY m.medicine_id, m.medicine_name, m.unit_price
),
Ranked AS (
    SELECT *, SUM(consumption_value) OVER () AS total_value,
           SUM(consumption_value) OVER (
               ORDER BY consumption_value DESC
               ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
           ) AS cumulative_value
    FROM Medicine_Value
)
SELECT medicine_name, quantity_used, consumption_value,
       ROUND(cumulative_value / total_value * 100,2) AS cumulative_percentage,
       CASE
           WHEN cumulative_value / total_value <= 0.70 THEN 'A'
           WHEN cumulative_value / total_value <= 0.90 THEN 'B'
           ELSE 'C'
       END AS abc_category
FROM Ranked
ORDER BY consumption_value DESC;

-- 12. Business Problem: Which medicines have the most stable or variable monthly demand?
WITH Monthly_Demand AS (
    SELECT m.medicine_id, m.medicine_name,
           DATE_FORMAT(p.prescription_date,'%Y-%m') AS demand_month,
           SUM(p.quantity) AS monthly_quantity
    FROM Medicines m
    JOIN Prescriptions p ON m.medicine_id = p.medicine_id
    GROUP BY m.medicine_id, m.medicine_name,
             DATE_FORMAT(p.prescription_date,'%Y-%m')
),
Demand_Stats AS (
    SELECT medicine_id, medicine_name,
           AVG(monthly_quantity) AS avg_demand,
           STDDEV_POP(monthly_quantity) AS demand_sd
    FROM Monthly_Demand
    GROUP BY medicine_id, medicine_name
)
SELECT medicine_name,
       ROUND(avg_demand,2) AS average_demand,
       ROUND(demand_sd,2) AS demand_sd,
       ROUND(demand_sd / NULLIF(avg_demand,0),2) AS coefficient_of_variation
FROM Demand_Stats
ORDER BY coefficient_of_variation;

-- 13. Business Problem: Which medicines have the largest inventory variance and estimated loss?
SELECT m.medicine_name, ia.system_stock, ia.physical_stock,
       ia.variance,
       ABS(ia.variance) * m.unit_price AS estimated_loss,
       ia.remarks
FROM Inventory_Audit ia
JOIN Medicines m ON ia.medicine_id = m.medicine_id
ORDER BY estimated_loss DESC;

-- 14. Business Problem: Which suppliers have the highest purchase value and delivery performance?
SELECT s.supplier_name,
       COUNT(po.purchase_order_id) AS total_orders,
       SUM(po.total_amount) AS total_purchase_value,
       AVG(s.supplier_rating) AS supplier_rating,
       ROUND(AVG(
           CASE WHEN de.delivery_date <= po.expected_delivery_date
                THEN 1 ELSE 0 END
       ) * 100,2) AS on_time_delivery_percentage
FROM Suppliers s
LEFT JOIN Purchase_Orders po ON s.supplier_id = po.supplier_id
LEFT JOIN Deliveries de ON po.purchase_order_id = de.purchase_order_id
GROUP BY s.supplier_id, s.supplier_name
ORDER BY total_purchase_value DESC;

-- 15. Business Problem: Which diagnoses are most common and what is their treatment cost?
SELECT diagnosis, COUNT(*) AS diagnosis_count,
       AVG(treatment_cost) AS average_treatment_cost,
       SUM(treatment_cost) AS total_treatment_cost
FROM Medical_Records
GROUP BY diagnosis
ORDER BY diagnosis_count DESC;

-- 16. Business Problem: Which five medicines have the highest prescription volume?
SELECT m.medicine_name, SUM(p.quantity) AS total_consumption
FROM Medicines m
JOIN Prescriptions p ON m.medicine_id = p.medicine_id
GROUP BY m.medicine_id, m.medicine_name
ORDER BY total_consumption DESC
LIMIT 5;

-- 17. Business Problem: Which departments generate the highest treatment revenue?
SELECT dp.department_name,
       SUM(mr.treatment_cost) AS treatment_revenue
FROM Departments dp
JOIN Doctors d ON dp.department_id = d.department_id
JOIN Medical_Records mr ON d.doctor_id = mr.doctor_id
GROUP BY dp.department_id, dp.department_name
ORDER BY treatment_revenue DESC;

-- 18. Business Problem: Which patients have the largest pending hospital bills?
SELECT p.patient_name, SUM(b.final_amount) AS outstanding_amount
FROM Patients p
JOIN Hospital_Bills b ON p.patient_id = b.patient_id
WHERE b.payment_status = 'Pending'
GROUP BY p.patient_id, p.patient_name
ORDER BY outstanding_amount DESC;

-- 19. Business Problem: Which medicines are approaching their expiry date?
SELECT medicine_name, expiry_date,
       DATEDIFF(expiry_date, CURDATE()) AS days_to_expiry
FROM Medicines
WHERE expiry_date >= CURDATE()
  AND DATEDIFF(expiry_date, CURDATE()) <= 180
ORDER BY expiry_date;

-- 20. Business Problem: Which patients have never had an appointment?
SELECT p.patient_id, p.patient_name
FROM Patients p
LEFT JOIN Appointments a ON p.patient_id = a.patient_id
WHERE a.appointment_id IS NULL
ORDER BY p.patient_name;

-- 21. Business Problem: Which doctors have never received an appointment?
SELECT d.doctor_id, d.doctor_name
FROM Doctors d
LEFT JOIN Appointments a ON d.doctor_id = a.doctor_id
WHERE a.appointment_id IS NULL
ORDER BY d.doctor_name;

-- 22. Business Problem: Which departments have the largest number of doctors?
SELECT dp.department_name, COUNT(d.doctor_id) AS doctor_count
FROM Departments dp
LEFT JOIN Doctors d ON dp.department_id = d.department_id
GROUP BY dp.department_id, dp.department_name
ORDER BY doctor_count DESC;

-- 23. Business Problem: Which doctors have the highest consultation fees?
SELECT doctor_name, specialization, consultation_fee
FROM Doctors
ORDER BY consultation_fee DESC
LIMIT 10;

-- 24. Business Problem: Which doctors have the most years of experience?
SELECT doctor_name, specialization, experience_years
FROM Doctors
ORDER BY experience_years DESC
LIMIT 10;

-- 25. Business Problem: What is the average consultation fee by department?
SELECT dp.department_name,
       ROUND(AVG(d.consultation_fee),2) AS average_consultation_fee
FROM Departments dp
JOIN Doctors d ON dp.department_id = d.department_id
GROUP BY dp.department_id, dp.department_name
ORDER BY average_consultation_fee DESC;

-- 26. Business Problem: Which appointment statuses are most common?
SELECT appointment_status, COUNT(*) AS appointment_count
FROM Appointments
GROUP BY appointment_status
ORDER BY appointment_count DESC;

-- 27. Business Problem: Which doctors have the highest number of completed appointments?
SELECT d.doctor_name, COUNT(a.appointment_id) AS completed_appointments
FROM Doctors d
JOIN Appointments a ON d.doctor_id = a.doctor_id
WHERE a.appointment_status = 'Completed'
GROUP BY d.doctor_id, d.doctor_name
ORDER BY completed_appointments DESC;

-- 28. Business Problem: Which patients have had multiple appointments?
SELECT p.patient_name, COUNT(a.appointment_id) AS appointment_count
FROM Patients p
JOIN Appointments a ON p.patient_id = a.patient_id
GROUP BY p.patient_id, p.patient_name
HAVING COUNT(a.appointment_id) > 1
ORDER BY appointment_count DESC;

-- 29. Business Problem: Which insurance providers cover the largest number of patients?
SELECT insurance_provider, COUNT(*) AS patient_count
FROM Patients
WHERE insurance_provider IS NOT NULL
GROUP BY insurance_provider
ORDER BY patient_count DESC;

-- 30. Business Problem: What is the patient distribution by gender?
SELECT gender, COUNT(*) AS patient_count
FROM Patients
GROUP BY gender
ORDER BY patient_count DESC;

-- 31. Business Problem: Which blood groups are most common among patients?
SELECT blood_group, COUNT(*) AS patient_count
FROM Patients
GROUP BY blood_group
ORDER BY patient_count DESC;

-- 32. Business Problem: Which suppliers have the highest ratings?
SELECT supplier_name, city, supplier_rating
FROM Suppliers
ORDER BY supplier_rating DESC
LIMIT 10;

-- 33. Business Problem: Which cities have the largest number of suppliers?
SELECT city, COUNT(*) AS supplier_count
FROM Suppliers
GROUP BY city
ORDER BY supplier_count DESC;

-- 34. Business Problem: Which medicine categories contain the most medicines?
SELECT category, COUNT(*) AS medicine_count
FROM Medicines
GROUP BY category
ORDER BY medicine_count DESC;

-- 35. Business Problem: Which medicine categories have the highest average price?
SELECT category, ROUND(AVG(unit_price),2) AS average_price
FROM Medicines
GROUP BY category
ORDER BY average_price DESC;

-- 36. Business Problem: Which suppliers provide the largest number of different medicines?
SELECT s.supplier_name, COUNT(m.medicine_id) AS medicine_count
FROM Suppliers s
JOIN Medicines m ON s.supplier_id = m.supplier_id
GROUP BY s.supplier_id, s.supplier_name
ORDER BY medicine_count DESC;

-- 37. Business Problem: Which purchase orders have the highest total value?
SELECT purchase_order_id, supplier_id, order_date,
       total_amount, order_status
FROM Purchase_Orders
ORDER BY total_amount DESC
LIMIT 10;

-- 38. Business Problem: Which suppliers receive the highest total purchase spending?
SELECT s.supplier_name, SUM(po.total_amount) AS total_spending
FROM Suppliers s
JOIN Purchase_Orders po ON s.supplier_id = po.supplier_id
GROUP BY s.supplier_id, s.supplier_name
ORDER BY total_spending DESC;

-- 39. Business Problem: Which purchase orders are still pending?
SELECT purchase_order_id, supplier_id, order_date,
       expected_delivery_date, total_amount
FROM Purchase_Orders
WHERE order_status = 'Pending'
ORDER BY expected_delivery_date;

-- 40. Business Problem: Which purchase orders were delivered late?
SELECT po.purchase_order_id, s.supplier_name,
       po.expected_delivery_date, d.delivery_date
FROM Purchase_Orders po
JOIN Suppliers s ON po.supplier_id = s.supplier_id
JOIN Deliveries d ON po.purchase_order_id = d.purchase_order_id
WHERE d.delivery_date > po.expected_delivery_date
ORDER BY d.delivery_date;

-- 41. Business Problem: Which medicines have never been prescribed?
SELECT m.medicine_id, m.medicine_name
FROM Medicines m
LEFT JOIN Prescriptions p ON m.medicine_id = p.medicine_id
WHERE p.prescription_id IS NULL
ORDER BY m.medicine_name;

-- 42. Business Problem: Which doctors prescribe the largest number of different medicines?
SELECT d.doctor_name, COUNT(DISTINCT p.medicine_id) AS different_medicines
FROM Doctors d
JOIN Prescriptions p ON d.doctor_id = p.doctor_id
GROUP BY d.doctor_id, d.doctor_name
ORDER BY different_medicines DESC;

-- 43. Business Problem: Which patients receive the largest number of prescriptions?
SELECT p.patient_name, COUNT(pr.prescription_id) AS prescription_count
FROM Patients p
JOIN Prescriptions pr ON p.patient_id = pr.patient_id
GROUP BY p.patient_id, p.patient_name
ORDER BY prescription_count DESC;

-- 44. Business Problem: Which diagnoses have the highest average treatment cost?
SELECT diagnosis, ROUND(AVG(treatment_cost),2) AS average_cost
FROM Medical_Records
GROUP BY diagnosis
ORDER BY average_cost DESC;

-- 45. Business Problem: Which doctors generate the highest total treatment revenue?
SELECT d.doctor_name, SUM(mr.treatment_cost) AS treatment_revenue
FROM Doctors d
JOIN Medical_Records mr ON d.doctor_id = mr.doctor_id
GROUP BY d.doctor_id, d.doctor_name
ORDER BY treatment_revenue DESC;

-- 46. Business Problem: Which lab tests are the most expensive?
SELECT test_name, test_category, test_cost
FROM Lab_Tests
ORDER BY test_cost DESC
LIMIT 10;

-- 47. Business Problem: Which lab test categories have the highest average test cost?
SELECT test_category, ROUND(AVG(test_cost),2) AS average_test_cost,
       COUNT(*) AS number_of_tests
FROM Lab_Tests
GROUP BY test_category
ORDER BY average_test_cost DESC;

-- 48. Business Problem: Which lab tests are requested most frequently?
SELECT lt.test_name, COUNT(lr.result_id) AS test_count
FROM Lab_Tests lt
JOIN Lab_Results lr ON lt.test_id = lr.test_id
GROUP BY lt.test_id, lt.test_name
ORDER BY test_count DESC;

-- 49. Business Problem: Which lab result statuses are most common?
SELECT result_status, COUNT(*) AS result_count
FROM Lab_Results
GROUP BY result_status
ORDER BY result_count DESC;

-- 50. Business Problem: Which doctors have the highest number of lab tests associated with their patients?
SELECT d.doctor_name, COUNT(lr.result_id) AS lab_test_count
FROM Doctors d
JOIN Lab_Results lr ON d.doctor_id = lr.doctor_id
GROUP BY d.doctor_id, d.doctor_name
ORDER BY lab_test_count DESC;

-- 51. Business Problem: What is the average hospital bill by payment status?
SELECT payment_status, ROUND(AVG(final_amount),2) AS average_bill
FROM Hospital_Bills
GROUP BY payment_status
ORDER BY average_bill DESC;

-- 52. Business Problem: How much revenue comes from consultation, medicine, laboratory and treatment charges?
SELECT SUM(consultation_amount) AS consultation_revenue,
       SUM(medicine_amount) AS medicine_revenue,
       SUM(lab_amount) AS lab_revenue,
       SUM(treatment_amount) AS treatment_revenue
FROM Hospital_Bills;

-- 53. Business Problem: Which patients have the highest total medicine spending?
SELECT p.patient_name, SUM(b.medicine_amount) AS medicine_spending
FROM Patients p
JOIN Hospital_Bills b ON p.patient_id = b.patient_id
GROUP BY p.patient_id, p.patient_name
ORDER BY medicine_spending DESC
LIMIT 10;

-- 54. Business Problem: Which bills have the largest insurance contribution?
SELECT bill_id, patient_id, final_amount, insurance_amount,
       ROUND(insurance_amount / NULLIF(final_amount,0) * 100,2) AS insurance_percentage
FROM Hospital_Bills
ORDER BY insurance_amount DESC
LIMIT 10;

-- 55. Business Problem: Which patients have both medical records and hospital bills?
SELECT DISTINCT p.patient_id, p.patient_name
FROM Patients p
JOIN Medical_Records mr ON p.patient_id = mr.patient_id
JOIN Hospital_Bills b ON p.patient_id = b.patient_id
ORDER BY p.patient_name;

-- 56. Business Problem: Which patients have medical records but no hospital bill?
SELECT DISTINCT p.patient_id, p.patient_name
FROM Patients p
JOIN Medical_Records mr ON p.patient_id = mr.patient_id
LEFT JOIN Hospital_Bills b ON p.patient_id = b.patient_id
WHERE b.bill_id IS NULL
ORDER BY p.patient_name;

-- 57. Business Problem: Which medicines have stock shortages according to inventory audits?
SELECT m.medicine_name, ia.system_stock, ia.physical_stock, ia.variance
FROM Medicines m
JOIN Inventory_Audit ia ON m.medicine_id = ia.medicine_id
WHERE ia.variance < 0
ORDER BY ia.variance;

-- 58. Business Problem: Which medicines have excess physical stock compared with system stock?
SELECT m.medicine_name, ia.system_stock, ia.physical_stock, ia.variance
FROM Medicines m
JOIN Inventory_Audit ia ON m.medicine_id = ia.medicine_id
WHERE ia.variance > 0
ORDER BY ia.variance DESC;

-- 59. Business Problem: Which medicines have the highest number of stock issues recorded?
SELECT m.medicine_name,
       SUM(sma.quantity_issued) AS total_quantity_issued,
       COUNT(sma.movement_id) AS movement_count
FROM Medicines m
JOIN Stock_Movement_Audit sma ON m.medicine_id = sma.medicine_id
GROUP BY m.medicine_id, m.medicine_name
ORDER BY total_quantity_issued DESC;

-- 60. Business Problem: What is the monthly value of hospital bills?
SELECT DATE_FORMAT(bill_date,'%Y-%m') AS bill_month,
       SUM(final_amount) AS monthly_revenue,
       COUNT(bill_id) AS bill_count
FROM Hospital_Bills
GROUP BY DATE_FORMAT(bill_date,'%Y-%m')
ORDER BY bill_month;

-- 61. Business Problem: Which month had the highest hospital revenue?
SELECT DATE_FORMAT(bill_date,'%Y-%m') AS bill_month,
       SUM(final_amount) AS monthly_revenue
FROM Hospital_Bills
GROUP BY DATE_FORMAT(bill_date,'%Y-%m')
ORDER BY monthly_revenue DESC
LIMIT 1;

-- 62. Business Problem: Which departments have doctors with above-average experience?
SELECT dp.department_name, d.doctor_name, d.experience_years
FROM Departments dp
JOIN Doctors d ON dp.department_id = d.department_id
WHERE d.experience_years > (SELECT AVG(experience_years) FROM Doctors)
ORDER BY d.experience_years DESC;

-- 63. Business Problem: Which patients have visited more than one doctor?
SELECT p.patient_name, COUNT(DISTINCT a.doctor_id) AS doctor_count
FROM Patients p
JOIN Appointments a ON p.patient_id = a.patient_id
GROUP BY p.patient_id, p.patient_name
HAVING COUNT(DISTINCT a.doctor_id) > 1
ORDER BY doctor_count DESC;

-- 64. Business Problem: Which doctors have treated patients from more than one diagnosis?
SELECT d.doctor_name, COUNT(DISTINCT mr.diagnosis) AS diagnosis_count
FROM Doctors d
JOIN Medical_Records mr ON d.doctor_id = mr.doctor_id
GROUP BY d.doctor_id, d.doctor_name
HAVING COUNT(DISTINCT mr.diagnosis) > 1
ORDER BY diagnosis_count DESC;

-- 65. Business Problem: Which patients have prescriptions from more than one doctor?
SELECT p.patient_name, COUNT(DISTINCT pr.doctor_id) AS doctor_count
FROM Patients p
JOIN Prescriptions pr ON p.patient_id = pr.patient_id
GROUP BY p.patient_id, p.patient_name
HAVING COUNT(DISTINCT pr.doctor_id) > 1
ORDER BY doctor_count DESC;

-- 66. Business Problem: Which departments have the highest annual budget?
SELECT department_name, location, annual_budget
FROM Departments
ORDER BY annual_budget DESC;

-- 67. Business Problem: Which departments have low budget compared with the average department budget?
SELECT department_name, annual_budget
FROM Departments
WHERE annual_budget < (SELECT AVG(annual_budget) FROM Departments)
ORDER BY annual_budget;

-- 68. Business Problem: Which patients registered most recently?
SELECT patient_id, patient_name, registration_date
FROM Patients
ORDER BY registration_date DESC
LIMIT 10;

-- 69. Business Problem: Which medicines will expire first?
SELECT medicine_name, expiry_date
FROM Medicines
WHERE expiry_date IS NOT NULL
ORDER BY expiry_date
LIMIT 10;

-- 70. Business Problem: What is the average medicine price by supplier?
SELECT s.supplier_name, ROUND(AVG(m.unit_price),2) AS average_medicine_price
FROM Suppliers s
JOIN Medicines m ON s.supplier_id = m.supplier_id
GROUP BY s.supplier_id, s.supplier_name
ORDER BY average_medicine_price DESC;

-- 71. Business Problem: Which suppliers have medicines priced above the overall average?
SELECT DISTINCT s.supplier_name
FROM Suppliers s
JOIN Medicines m ON s.supplier_id = m.supplier_id
WHERE m.unit_price > (SELECT AVG(unit_price) FROM Medicines)
ORDER BY s.supplier_name;

-- 72. Business Problem: Which appointment dates have the highest patient demand?
SELECT appointment_date, COUNT(*) AS appointment_count
FROM Appointments
GROUP BY appointment_date
ORDER BY appointment_count DESC
LIMIT 10;

-- 73. Business Problem: What is the average treatment cost by doctor specialization?
SELECT d.specialization, ROUND(AVG(mr.treatment_cost),2) AS average_treatment_cost
FROM Doctors d
JOIN Medical_Records mr ON d.doctor_id = mr.doctor_id
GROUP BY d.specialization
ORDER BY average_treatment_cost DESC;

-- 74. Business Problem: Which doctors have treatment revenue above the average doctor revenue?
SELECT d.doctor_name, SUM(mr.treatment_cost) AS treatment_revenue
FROM Doctors d
JOIN Medical_Records mr ON d.doctor_id = mr.doctor_id
GROUP BY d.doctor_id, d.doctor_name
HAVING SUM(mr.treatment_cost) > (
    SELECT AVG(doctor_revenue)
    FROM (
        SELECT SUM(treatment_cost) AS doctor_revenue
        FROM Medical_Records
        GROUP BY doctor_id
    ) x
)
ORDER BY treatment_revenue DESC;

-- 75. Business Problem: How does each doctor's treatment revenue compare with the previous doctor in revenue ranking?
WITH Doctor_Revenue AS (
    SELECT d.doctor_id, d.doctor_name, SUM(mr.treatment_cost) AS revenue
    FROM Doctors d
    JOIN Medical_Records mr ON d.doctor_id = mr.doctor_id
    GROUP BY d.doctor_id, d.doctor_name
)
SELECT doctor_name, revenue,
       LAG(revenue) OVER (ORDER BY revenue DESC) AS previous_rank_revenue
FROM Doctor_Revenue
ORDER BY revenue DESC;

-- 76. Business Problem: Which medicines have the highest prescription quantity within each category?
WITH Medicine_Usage AS (
    SELECT m.medicine_id, m.medicine_name, m.category,
           SUM(p.quantity) AS total_quantity
    FROM Medicines m
    JOIN Prescriptions p ON m.medicine_id = p.medicine_id
    GROUP BY m.medicine_id, m.medicine_name, m.category
)
SELECT medicine_name, category, total_quantity,
ROW_NUMBER() OVER (PARTITION BY category ORDER BY total_quantity DESC) AS category_rank
FROM Medicine_Usage
ORDER BY category, category_rank;

-- 77. Business Problem: Which doctors have more appointments than other doctors in the same department?
WITH Doctor_Appointments AS (
    SELECT d.doctor_id, d.doctor_name, d.department_id,
           COUNT(a.appointment_id) AS appointment_count
    FROM Doctors d
    LEFT JOIN Appointments a ON d.doctor_id = a.doctor_id
    GROUP BY d.doctor_id, d.doctor_name, d.department_id
)
SELECT doctor_name, department_id, appointment_count,
       RANK() OVER (
           PARTITION BY department_id ORDER BY appointment_count DESC
       ) AS department_rank
FROM Doctor_Appointments
ORDER BY department_id, department_rank;

