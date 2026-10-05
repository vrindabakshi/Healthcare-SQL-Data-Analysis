-- ============================================================
-- HEALTHCARE ANALYTICS
-- CREATE TABLES + CSV IMPORT WIZARD
-- ============================================================

CREATE DATABASE Healthcare_Analytics;
USE Healthcare_Analytics;

CREATE TABLE Departments (
    department_id INT PRIMARY KEY,
    department_name VARCHAR(100) NOT NULL,
    location VARCHAR(100),
    annual_budget DECIMAL(12,2)
);

select * from departments;


CREATE TABLE Doctors (
    doctor_id INT PRIMARY KEY,
    doctor_name VARCHAR(100) NOT NULL,
    specialization VARCHAR(100),
    department_id INT,
    experience_years INT,
    consultation_fee DECIMAL(10,2),
    FOREIGN KEY (department_id) REFERENCES Departments(department_id)
);

select * from doctors;


CREATE TABLE Patients (
    patient_id INT PRIMARY KEY,
    patient_name VARCHAR(100) NOT NULL,
    gender VARCHAR(20),
    date_of_birth DATE,
    blood_group VARCHAR(10),
    registration_date DATE,
    insurance_provider VARCHAR(100)
);

select * from patients;


CREATE TABLE Suppliers (
    supplier_id INT PRIMARY KEY,
    supplier_name VARCHAR(100) NOT NULL,
    city VARCHAR(100),
    contact_person VARCHAR(100),
    supplier_rating DECIMAL(3,2)
);

select * from suppliers;


CREATE TABLE Medicines (
    medicine_id INT PRIMARY KEY,
    medicine_name VARCHAR(100) NOT NULL,
    category VARCHAR(100),
    unit_price DECIMAL(10,2),
    reorder_level INT,
    expiry_date DATE,
    supplier_id INT,
    FOREIGN KEY (supplier_id) REFERENCES Suppliers(supplier_id)
);

select * from medicines;

CREATE TABLE Lab_Tests (
    test_id INT PRIMARY KEY,
    test_name VARCHAR(100) NOT NULL,
    test_category VARCHAR(100),
    test_cost DECIMAL(10,2)
);

select * from lab_tests;

CREATE TABLE Appointments (
    appointment_id INT PRIMARY KEY,
    patient_id INT,
    doctor_id INT,
    appointment_date DATE,
    appointment_status VARCHAR(30),
    FOREIGN KEY (patient_id) REFERENCES Patients(patient_id),
    FOREIGN KEY (doctor_id) REFERENCES Doctors(doctor_id)
);

select * from appointments;

CREATE TABLE Medical_Records (
    record_id INT PRIMARY KEY,
    patient_id INT,
    doctor_id INT,
    diagnosis VARCHAR(150),
    treatment VARCHAR(255),
    record_date DATE,
    treatment_cost DECIMAL(10,2),
    FOREIGN KEY (patient_id) REFERENCES Patients(patient_id),
    FOREIGN KEY (doctor_id) REFERENCES Doctors(doctor_id)
);

select * from medical_records;

CREATE TABLE Prescriptions (
    prescription_id INT PRIMARY KEY,
    patient_id INT,
    doctor_id INT,
    medicine_id INT,
    prescription_date DATE,
    quantity INT,
    dosage VARCHAR(100),
    FOREIGN KEY (patient_id) REFERENCES Patients(patient_id),
    FOREIGN KEY (doctor_id) REFERENCES Doctors(doctor_id),
    FOREIGN KEY (medicine_id) REFERENCES Medicines(medicine_id)
);

select * from prescriptions;

CREATE TABLE Purchase_Orders (
    purchase_order_id INT PRIMARY KEY,
    supplier_id INT,
    order_date DATE,
    expected_delivery_date DATE,
    total_amount DECIMAL(12,2),
    order_status VARCHAR(30),
    FOREIGN KEY (supplier_id) REFERENCES Suppliers(supplier_id)
);

select * from purchase_orders;


CREATE TABLE Purchase_Order_Items (
    purchase_order_id INT,
    medicine_id INT,
    quantity_ordered INT,
    unit_cost DECIMAL(10,2),
    PRIMARY KEY (purchase_order_id, medicine_id),
    FOREIGN KEY (purchase_order_id) REFERENCES Purchase_Orders(purchase_order_id),
    FOREIGN KEY (medicine_id) REFERENCES Medicines(medicine_id)
);

select * from purchase_order_items;

CREATE TABLE Deliveries (
    delivery_id INT PRIMARY KEY,
    purchase_order_id INT,
    delivery_date DATE,
    quantity_received INT,
    delivery_status VARCHAR(30),
    FOREIGN KEY (purchase_order_id) REFERENCES Purchase_Orders(purchase_order_id)
);

select * from deliveries;

CREATE TABLE Inventory_Audit (
    audit_id INT PRIMARY KEY,
    medicine_id INT,
    audit_date DATE,
    system_stock INT,
    physical_stock INT,
    variance INT,
    auditor_name VARCHAR(100),
    remarks VARCHAR(255),
    FOREIGN KEY (medicine_id) REFERENCES Medicines(medicine_id)
);

select * from inventory_audit;

CREATE TABLE Lab_Results (
    result_id INT PRIMARY KEY,
    patient_id INT,
    test_id INT,
    doctor_id INT,
    test_date DATE,
    result_value VARCHAR(100),
    result_status VARCHAR(50),
    FOREIGN KEY (patient_id) REFERENCES Patients(patient_id),
    FOREIGN KEY (test_id) REFERENCES Lab_Tests(test_id),
    FOREIGN KEY (doctor_id) REFERENCES Doctors(doctor_id)
);

select * from lab_results;

CREATE TABLE Hospital_Bills (
    bill_id INT PRIMARY KEY,
    patient_id INT,
    bill_date DATE,
    consultation_amount DECIMAL(10,2),
    medicine_amount DECIMAL(10,2),
    lab_amount DECIMAL(10,2),
    treatment_amount DECIMAL(10,2),
    insurance_amount DECIMAL(10,2),
    final_amount DECIMAL(10,2),
    payment_status VARCHAR(30),
    FOREIGN KEY (patient_id) REFERENCES Patients(patient_id)
);

select * from hospital_bills;

CREATE TABLE Stock_Movement_Audit (
    movement_id INT AUTO_INCREMENT PRIMARY KEY,
    medicine_id INT,
    prescription_id INT,
    quantity_issued INT,
    movement_date DATETIME,
    movement_type VARCHAR(30)
);

select * from stock_movement_audit;



-- ============================================================
-- PROCEDURES AND TRIGGERS
-- ============================================================

DELIMITER //

CREATE PROCEDURE GetPatientSummary(IN p_patient_id INT)
BEGIN
    SELECT
        p.patient_id,
        p.patient_name,
        p.gender,
        p.blood_group,
        p.insurance_provider,
        COUNT(DISTINCT a.appointment_id) AS total_appointments,
        COUNT(DISTINCT mr.record_id) AS medical_records,
        COALESCE(SUM(b.final_amount),0) AS total_billed,
        COALESCE(SUM(b.insurance_amount),0) AS insurance_covered,
        COALESCE(SUM(b.final_amount - b.insurance_amount),0) AS patient_payable
    FROM Patients p
    LEFT JOIN Appointments a
        ON p.patient_id = a.patient_id
    LEFT JOIN Medical_Records mr
        ON p.patient_id = mr.patient_id
    LEFT JOIN Hospital_Bills b
        ON p.patient_id = b.patient_id
    WHERE p.patient_id = p_patient_id
    GROUP BY
        p.patient_id,
        p.patient_name,
        p.gender,
        p.blood_group,
        p.insurance_provider;
END //

DELIMITER //

CREATE PROCEDURE GetMedicineInventoryStatus(IN p_medicine_id INT)
BEGIN
    SELECT
        m.medicine_id,
        m.medicine_name,
        m.category,
        m.unit_price,
        m.reorder_level,
        ia.system_stock,
        ia.physical_stock,
        ia.variance,
        CASE
            WHEN ia.physical_stock <= m.reorder_level THEN 'REORDER'
            WHEN ia.physical_stock <= m.reorder_level * 1.5 THEN 'WATCH'
            ELSE 'SUFFICIENT'
        END AS inventory_status
    FROM Medicines m
    LEFT JOIN Inventory_Audit ia
        ON m.medicine_id = ia.medicine_id
    WHERE m.medicine_id = p_medicine_id;
END //


DELIMITER //

CREATE TRIGGER After_Prescription_Insert
AFTER INSERT ON Prescriptions
FOR EACH ROW
BEGIN
    INSERT INTO Stock_Movement_Audit
    (
        medicine_id,
        prescription_id,
        quantity_issued,
        movement_date,
        movement_type
    )
    VALUES
    (
        NEW.medicine_id,
        NEW.prescription_id,
        NEW.quantity,
        NOW(),
        'ISSUED'
    );
END //


