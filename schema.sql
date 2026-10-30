-- Hospital Management System starter schema (MySQL 8.0+)
-- Run as a MySQL user allowed to create databases.
CREATE DATABASE IF NOT EXISTS hospital_management
  CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE hospital_management;

CREATE TABLE IF NOT EXISTS departments (
  department_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  name VARCHAR(100) NOT NULL,
  description VARCHAR(500) NULL,
  PRIMARY KEY (department_id),
  UNIQUE KEY uq_departments_name (name)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS patients (
  patient_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  medical_record_no VARCHAR(24) NOT NULL,
  first_name VARCHAR(80) NOT NULL,
  last_name VARCHAR(80) NOT NULL,
  date_of_birth DATE NOT NULL,
  sex ENUM('female','male','intersex','unspecified') NOT NULL DEFAULT 'unspecified',
  phone VARCHAR(30) NULL,
  email VARCHAR(254) NULL,
  address VARCHAR(500) NULL,
  emergency_contact_name VARCHAR(160) NULL,
  emergency_contact_phone VARCHAR(30) NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (patient_id),
  UNIQUE KEY uq_patients_mrn (medical_record_no),
  KEY ix_patients_name (last_name, first_name),
  KEY ix_patients_phone (phone)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS doctors (
  doctor_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  department_id BIGINT UNSIGNED NOT NULL,
  first_name VARCHAR(80) NOT NULL,
  last_name VARCHAR(80) NOT NULL,
  specialty VARCHAR(120) NOT NULL,
  license_no VARCHAR(40) NOT NULL,
  phone VARCHAR(30) NULL,
  email VARCHAR(254) NULL,
  active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (doctor_id),
  UNIQUE KEY uq_doctors_license (license_no),
  KEY ix_doctors_department (department_id, active),
  CONSTRAINT fk_doctors_department FOREIGN KEY (department_id)
    REFERENCES departments (department_id) ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS appointments (
  appointment_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  patient_id BIGINT UNSIGNED NOT NULL,
  doctor_id BIGINT UNSIGNED NOT NULL,
  starts_at DATETIME NOT NULL,
  ends_at DATETIME NOT NULL,
  reason VARCHAR(500) NULL,
  status ENUM('scheduled','completed','cancelled','no_show') NOT NULL DEFAULT 'scheduled',
  notes TEXT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (appointment_id),
  KEY ix_appointments_patient_time (patient_id, starts_at),
  KEY ix_appointments_doctor_time (doctor_id, starts_at),
  CONSTRAINT chk_appointment_time CHECK (ends_at > starts_at),
  CONSTRAINT fk_appointments_patient FOREIGN KEY (patient_id)
    REFERENCES patients (patient_id) ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT fk_appointments_doctor FOREIGN KEY (doctor_id)
    REFERENCES doctors (doctor_id) ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS beds (
  bed_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  ward VARCHAR(80) NOT NULL,
  room_no VARCHAR(20) NOT NULL,
  bed_no VARCHAR(20) NOT NULL,
  bed_type ENUM('general','semi_private','private','icu','maternity','pediatric') NOT NULL DEFAULT 'general',
  active BOOLEAN NOT NULL DEFAULT TRUE,
  PRIMARY KEY (bed_id),
  UNIQUE KEY uq_beds_location (ward, room_no, bed_no)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS admissions (
  admission_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  patient_id BIGINT UNSIGNED NOT NULL,
  attending_doctor_id BIGINT UNSIGNED NOT NULL,
  bed_id BIGINT UNSIGNED NOT NULL,
  admitted_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  discharged_at DATETIME NULL,
  admission_reason VARCHAR(500) NOT NULL,
  discharge_notes TEXT NULL,
  active_bed_id BIGINT UNSIGNED GENERATED ALWAYS AS
    (CASE WHEN discharged_at IS NULL THEN bed_id ELSE NULL END) STORED,
  PRIMARY KEY (admission_id),
  UNIQUE KEY uq_admissions_active_bed (active_bed_id),
  KEY ix_admissions_patient (patient_id, admitted_at),
  CONSTRAINT chk_admission_dates CHECK (discharged_at IS NULL OR discharged_at >= admitted_at),
  CONSTRAINT fk_admissions_patient FOREIGN KEY (patient_id)
    REFERENCES patients (patient_id) ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT fk_admissions_doctor FOREIGN KEY (attending_doctor_id)
    REFERENCES doctors (doctor_id) ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT fk_admissions_bed FOREIGN KEY (bed_id)
    REFERENCES beds (bed_id) ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS bills (
  bill_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  patient_id BIGINT UNSIGNED NOT NULL,
  appointment_id BIGINT UNSIGNED NULL,
  admission_id BIGINT UNSIGNED NULL,
  issued_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  due_at DATE NULL,
  status ENUM('draft','unpaid','part_paid','paid','void') NOT NULL DEFAULT 'unpaid',
  notes VARCHAR(500) NULL,
  PRIMARY KEY (bill_id),
  KEY ix_bills_patient_date (patient_id, issued_at),
  KEY ix_bills_status_due (status, due_at),
  CONSTRAINT fk_bills_patient FOREIGN KEY (patient_id)
    REFERENCES patients (patient_id) ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT fk_bills_appointment FOREIGN KEY (appointment_id)
    REFERENCES appointments (appointment_id) ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT fk_bills_admission FOREIGN KEY (admission_id)
    REFERENCES admissions (admission_id) ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS bill_items (
  bill_item_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  bill_id BIGINT UNSIGNED NOT NULL,
  description VARCHAR(240) NOT NULL,
  quantity DECIMAL(10,2) NOT NULL DEFAULT 1.00,
  unit_price DECIMAL(12,2) NOT NULL,
  PRIMARY KEY (bill_item_id),
  KEY ix_bill_items_bill (bill_id),
  CONSTRAINT chk_bill_item_quantity CHECK (quantity > 0),
  CONSTRAINT chk_bill_item_price CHECK (unit_price >= 0),
  CONSTRAINT fk_bill_items_bill FOREIGN KEY (bill_id)
    REFERENCES bills (bill_id) ON UPDATE CASCADE ON DELETE CASCADE
) ENGINE=InnoDB;

-- Optional, fictional starter records. Remove this section if a blank database is preferred.
INSERT IGNORE INTO departments (name, description) VALUES
  ('General Medicine', 'Primary and general medical care'),
  ('Cardiology', 'Heart and cardiovascular care'),
  ('Pediatrics', 'Healthcare for children');

INSERT IGNORE INTO doctors (department_id, first_name, last_name, specialty, license_no, email)
SELECT department_id, 'Asha', 'Menon', 'General Physician', 'DEMO-LIC-001', 'asha.menon@example.test'
FROM departments WHERE name = 'General Medicine';
INSERT IGNORE INTO doctors (department_id, first_name, last_name, specialty, license_no, email)
SELECT department_id, 'Ravi', 'Shah', 'Cardiologist', 'DEMO-LIC-002', 'ravi.shah@example.test'
FROM departments WHERE name = 'Cardiology';

INSERT IGNORE INTO beds (ward, room_no, bed_no, bed_type) VALUES
  ('General Ward', 'G-101', '1', 'general'),
  ('General Ward', 'G-101', '2', 'general'),
  ('Critical Care', 'ICU-01', '1', 'icu');

