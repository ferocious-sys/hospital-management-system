# Hospital Management System (MySQL)

An educational, console-based hospital operations starter, modeled on the reference project's Python + MySQL structure. It includes a relational MySQL database and a Python interface for patient registration, doctor directory, appointment booking, appointment status updates, and basic billing.

## Included files

- `schema.sql` - creates the `hospital_management` database, tables, constraints, indexes, and fictional sample doctors/beds.
- `app.py` - Python menu application connected to MySQL.
- `requirements.txt` - Python dependency.

## Requirements

- MySQL Server 8.0.16 or newer, or a recent MariaDB release
- Python 3.10 or newer

## Setup

1. Start MySQL Server and open a MySQL client as a user allowed to create databases.
2. Run the schema:

   ```bash
   mysql -u root -p < schema.sql
   ```

3. Install the Python connector:

   ```bash
   python -m pip install -r requirements.txt
   ```

4. Configure connection settings. Defaults are `127.0.0.1:3306`, database `hospital_management`, and user `root`. If `HMS_DB_PASSWORD` is not set, the app asks for the MySQL password in a hidden terminal prompt and remembers it only for that app session. You can also supply connection settings through environment variables:

   **Windows PowerShell**
   ```powershell
   $env:HMS_DB_HOST="127.0.0.1"
   $env:HMS_DB_PORT="3306"
   $env:HMS_DB_USER="root"
   $env:HMS_DB_PASSWORD="your-local-password"
   $env:HMS_DB_NAME="hospital_management"
   ```

   **macOS/Linux**
   ```bash
   export HMS_DB_HOST=127.0.0.1
   export HMS_DB_PORT=3306
   export HMS_DB_USER=root
   export HMS_DB_PASSWORD='your-local-password'
   export HMS_DB_NAME=hospital_management
   ```

5. Run the application:

   ```bash
   python app.py
   ```

## Database design

- `departments` 1-to-many `doctors`
- `patients` and `doctors` each have 1-to-many `appointments`
- `beds` 1-to-many historical `admissions`; a generated unique key prevents an active bed from being assigned twice
- `patients` 1-to-many `bills`; each bill has 1-to-many `bill_items`
- Appointment booking validates overlapping appointments while holding patient and doctor row locks

## Menu

1. List patients
2. Add patient
3. List doctors
4. Book a 30-minute appointment
5. List appointments
6. Mark a scheduled appointment completed, cancelled, or no-show
7. List bills
8. Create a bill with one charge line

## Project description

**Objective:** Organize a small hospital's patient, provider, appointment, admission, bed, and billing records in a persistent database, while demonstrating CRUD, validation, foreign keys, indexes, and transaction handling.

**Technology:** Python 3, `mysql-connector-python`, and MySQL 8.0+; the console interface can be run from a terminal or Python IDE.

**Scope:** Educational starter for local demonstration. The schema includes admissions and bed tracking; the included menu focuses on patient registration, doctors, appointments, and basic billing. Add role-based access, audit logging, backups, encryption, and review by qualified privacy/security staff before any real clinical or patient use. Do not put real patient data in this sample project.

## Example flow

```text
HOSPITAL MANAGEMENT SYSTEM
1. List patients
2. Add patient
3. List doctors
4. Book appointment
5. List appointments
6. Update appointment status
7. List bills
8. Create bill
0. Exit
```

The schema includes fictional demo departments/doctors and beds. They use reserved `.test` email addresses and are not real people.


## Project report and local bundle

The project report is included at `docs/Hospital_Management_System_Report.pdf`.
To build a local ZIP containing the application, SQL schema, setup guide, and PDF, run:

```powershell
.\build_local.ps1
```

The script writes `Hospital_Management_System.zip` to the parent `outputs` folder. The build is intended for private local use; no patient data should be included.

## Troubleshooting

### `Database error: 1045 (28000): Access denied for user 'root'@'localhost' (using password: NO)`

The app did not receive a password. Run the updated `app.py` in a terminal; it will ask for the MySQL password and hide what you type. The password is kept only in the running app process. If you start the app from an IDE, run it in the IDE's terminal so it can show the password prompt.

### `Database error: 1045 (28000): Access denied for user 'root'@'localhost' (using password: YES)`

MySQL received a password but rejected it for the configured account. If the app prompted you, check that you entered the MySQL password correctly; it will prompt again after a rejected password. If you set `HMS_DB_PASSWORD`, check that it is correct and restart the app. Do not put your real password in this README or commit it to the repository.

On Windows PowerShell, you can instead set the password for that session and run the app:

```powershell
Set-Location "C:\path\to\Hospital_Management_System"
$env:HMS_DB_PASSWORD = Read-Host "MySQL root password" -AsSecureString | ForEach-Object { [System.Net.NetworkCredential]::new("", $_).Password }
python .\app.py
```

The environment variable lasts only for that PowerShell session. To verify the password independently, run `mysql -u root -p` and enter it at MySQL's prompt.

### `Database error: 1049 (42000): Unknown database 'hospital_management'`

The MySQL server accepted the connection, but the project schema has not been loaded yet. Import `schema.sql` once to create the database and its tables. In Windows Command Prompt (`cmd.exe`), run these commands from the project folder:

```cmd
cd /d "C:\path\to\Hospital_Management_System"
"C:\Program Files\MySQL\MySQL Server 8.4\bin\mysql.exe" -u root -p < schema.sql
```

Enter the MySQL root password when prompted. The schema creates `hospital_management` and inserts fictional demo departments, doctors, and beds. Then restart `app.py` and try **List patients** again.

### `ERROR 1215 (HY000) at line 84: Cannot add foreign key constraint`

Use the current `schema.sql` from this repository. The admission table has a generated active-bed column based on `bed_id`; MySQL does not allow `ON UPDATE CASCADE` on a foreign key for that base column, so the bed relationship uses `RESTRICT` instead. If an earlier import stopped at this error, rerun the full schema command above. The script uses `CREATE TABLE IF NOT EXISTS` and duplicate-safe demo inserts, so it can finish the missing tables without dropping the database.
