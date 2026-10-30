"""Small educational console client for the Hospital Management System."""
from __future__ import annotations

import os
from datetime import datetime, timedelta
from decimal import Decimal, InvalidOperation

import mysql.connector
from mysql.connector import Error


def connect_db():
    return mysql.connector.connect(
        host=os.getenv("HMS_DB_HOST", "127.0.0.1"),
        port=int(os.getenv("HMS_DB_PORT", "3306")),
        user=os.getenv("HMS_DB_USER", "root"),
        password=os.getenv("HMS_DB_PASSWORD", ""),
        database=os.getenv("HMS_DB_NAME", "hospital_management"),
    )


def ask_int(prompt: str, minimum: int = 1) -> int:
    while True:
        try:
            value = int(input(prompt).strip())
            if value < minimum:
                raise ValueError
            return value
        except ValueError:
            print(f"Enter a whole number of at least {minimum}.")


def show_patients():
    with connect_db() as db:
        cur = db.cursor()
        cur.execute("""SELECT patient_id, medical_record_no, first_name, last_name,
                              date_of_birth, phone
                       FROM patients ORDER BY last_name, first_name""")
        rows = cur.fetchall()
    print("\nID | MRN | Patient | Date of birth | Phone")
    for row in rows:
        print(f"{row[0]} | {row[1]} | {row[2]} {row[3]} | {row[4]} | {row[5] or '-'}")
    if not rows:
        print("No patients recorded.")


def add_patient():
    mrn = input("Medical record number: ").strip()
    first = input("First name: ").strip()
    last = input("Last name: ").strip()
    dob = input("Date of birth (YYYY-MM-DD): ").strip()
    sex = input("Sex (female/male/intersex/unspecified) [unspecified]: ").strip().lower() or "unspecified"
    phone = input("Phone (optional): ").strip() or None
    email = input("Email (optional): ").strip() or None
    if not mrn or not first or not last:
        print("MRN, first name, and last name are required.")
        return
    if sex not in {"female", "male", "intersex", "unspecified"}:
        print("Invalid sex value.")
        return
    try:
        datetime.strptime(dob, "%Y-%m-%d")
        with connect_db() as db:
            cur = db.cursor()
            cur.execute("""INSERT INTO patients
                (medical_record_no, first_name, last_name, date_of_birth, sex, phone, email)
                VALUES (%s, %s, %s, %s, %s, %s, %s)""",
                (mrn, first, last, dob, sex, phone, email))
            db.commit()
            print(f"Patient added (ID {cur.lastrowid}).")
    except ValueError:
        print("Use YYYY-MM-DD for date of birth.")
    except Error as exc:
        print(f"Could not add patient: {exc}")


def show_doctors():
    with connect_db() as db:
        cur = db.cursor()
        cur.execute("""SELECT d.doctor_id, d.first_name, d.last_name, d.specialty,
                              dep.name, d.phone
                       FROM doctors d JOIN departments dep USING (department_id)
                       WHERE d.active = TRUE ORDER BY dep.name, d.last_name""")
        rows = cur.fetchall()
    print("\nID | Doctor | Specialty | Department | Phone")
    for row in rows:
        print(f"{row[0]} | Dr. {row[1]} {row[2]} | {row[3]} | {row[4]} | {row[5] or '-'}")
    if not rows:
        print("No active doctors recorded.")


def book_appointment():
    patient_id = ask_int("Patient ID: ")
    doctor_id = ask_int("Doctor ID: ")
    start_text = input("Start date/time (YYYY-MM-DD HH:MM): ").strip()
    reason = input("Reason for visit: ").strip() or None
    try:
        starts = datetime.strptime(start_text, "%Y-%m-%d %H:%M")
    except ValueError:
        print("Use YYYY-MM-DD HH:MM for the appointment time.")
        return
    ends = starts + timedelta(minutes=30)
    db = connect_db()
    try:
        db.start_transaction()
        cur = db.cursor()
        # Lock both records so simultaneous bookings for this patient/doctor serialize.
        cur.execute("SELECT patient_id FROM patients WHERE patient_id=%s FOR UPDATE", (patient_id,))
        if not cur.fetchone():
            raise ValueError("Patient not found.")
        cur.execute("SELECT doctor_id FROM doctors WHERE doctor_id=%s AND active=TRUE FOR UPDATE", (doctor_id,))
        if not cur.fetchone():
            raise ValueError("Active doctor not found.")
        cur.execute("""SELECT 1 FROM appointments
            WHERE status='scheduled' AND starts_at < %s AND ends_at > %s
              AND (doctor_id=%s OR patient_id=%s) LIMIT 1""",
            (ends, starts, doctor_id, patient_id))
        if cur.fetchone():
            raise ValueError("The doctor or patient already has an appointment in that time range.")
        cur.execute("""INSERT INTO appointments
            (patient_id, doctor_id, starts_at, ends_at, reason)
            VALUES (%s, %s, %s, %s, %s)""",
            (patient_id, doctor_id, starts, ends, reason))
        db.commit()
        print(f"Appointment booked (ID {cur.lastrowid}) for {starts:%Y-%m-%d %H:%M}.")
    except (Error, ValueError) as exc:
        db.rollback()
        print(f"Could not book appointment: {exc}")
    finally:
        db.close()


def show_appointments():
    with connect_db() as db:
        cur = db.cursor()
        cur.execute("""SELECT a.appointment_id, a.starts_at, a.status,
                              p.medical_record_no, p.first_name, p.last_name,
                              d.first_name, d.last_name, a.reason
                       FROM appointments a
                       JOIN patients p USING (patient_id)
                       JOIN doctors d USING (doctor_id)
                       ORDER BY a.starts_at DESC LIMIT 100""")
        rows = cur.fetchall()
    print("\nID | Starts | Status | Patient (MRN) | Doctor | Reason")
    for r in rows:
        print(f"{r[0]} | {r[1]} | {r[2]} | {r[4]} {r[5]} ({r[3]}) | Dr. {r[6]} {r[7]} | {r[8] or '-'}")
    if not rows:
        print("No appointments recorded.")


def update_appointment_status():
    appointment_id = ask_int("Appointment ID: ")
    status = input("New status (completed/cancelled/no_show): ").strip().lower()
    if status not in {"completed", "cancelled", "no_show"}:
        print("Choose completed, cancelled, or no_show.")
        return
    with connect_db() as db:
        cur = db.cursor()
        cur.execute("UPDATE appointments SET status=%s WHERE appointment_id=%s AND status='scheduled'",
                    (status, appointment_id))
        db.commit()
        print("Appointment status updated." if cur.rowcount else "No scheduled appointment found with that ID.")


def show_bills():
    with connect_db() as db:
        cur = db.cursor()
        cur.execute("""SELECT b.bill_id, b.issued_at, b.status,
                              p.medical_record_no, p.first_name, p.last_name,
                              COALESCE(SUM(i.quantity * i.unit_price), 0) AS total
                       FROM bills b JOIN patients p USING (patient_id)
                       LEFT JOIN bill_items i USING (bill_id)
                       GROUP BY b.bill_id, b.issued_at, b.status, p.medical_record_no,
                                p.first_name, p.last_name
                       ORDER BY b.issued_at DESC LIMIT 100""")
        rows = cur.fetchall()
    print("\nID | Issued | Status | Patient (MRN) | Total")
    for r in rows:
        print(f"{r[0]} | {r[1]} | {r[2]} | {r[4]} {r[5]} ({r[3]}) | {r[6]:.2f}")
    if not rows:
        print("No bills recorded.")


def create_bill():
    patient_id = ask_int("Patient ID: ")
    description = input("Charge description: ").strip()
    try:
        quantity = Decimal(input("Quantity: ").strip())
        unit_price = Decimal(input("Unit price: ").strip())
        if quantity <= 0 or unit_price < 0 or not description:
            raise InvalidOperation
    except InvalidOperation:
        print("Enter a description, quantity above zero, and a non-negative unit price.")
        return
    db = connect_db()
    try:
        db.start_transaction()
        cur = db.cursor()
        cur.execute("SELECT patient_id FROM patients WHERE patient_id=%s FOR UPDATE", (patient_id,))
        if not cur.fetchone():
            raise ValueError("Patient not found.")
        cur.execute("INSERT INTO bills (patient_id, status) VALUES (%s, 'unpaid')", (patient_id,))
        bill_id = cur.lastrowid
        cur.execute("INSERT INTO bill_items (bill_id, description, quantity, unit_price) VALUES (%s, %s, %s, %s)",
                    (bill_id, description, quantity, unit_price))
        db.commit()
        print(f"Bill {bill_id} created; total {quantity * unit_price:.2f}.")
    except (Error, ValueError) as exc:
        db.rollback()
        print(f"Could not create bill: {exc}")
    finally:
        db.close()


def main():
    actions = {
        "1": ("List patients", show_patients),
        "2": ("Add patient", add_patient),
        "3": ("List doctors", show_doctors),
        "4": ("Book appointment", book_appointment),
        "5": ("List appointments", show_appointments),
        "6": ("Update appointment status", update_appointment_status),
        "7": ("List bills", show_bills),
        "8": ("Create bill", create_bill),
    }
    while True:
        print("\nHOSPITAL MANAGEMENT SYSTEM")
        for key, (label, _) in actions.items():
            print(f"{key}. {label}")
        print("0. Exit")
        choice = input("Choose an option: ").strip()
        if choice == "0":
            print("Goodbye.")
            return
        action = actions.get(choice)
        if not action:
            print("Invalid option.")
            continue
        try:
            action[1]()
        except Error as exc:
            print(f"Database error: {exc}")
        except (EOFError, KeyboardInterrupt):
            print("\nGoodbye.")
            return


if __name__ == "__main__":
    main()

