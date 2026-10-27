CREATE OR REPLACE TABLE patients AS
SELECT * FROM read_csv_auto('data/patients.csv');

CREATE OR REPLACE TABLE encounters AS
SELECT * FROM read_csv_auto('data/encounters.csv');

CREATE OR REPLACE TABLE conditions AS
SELECT * FROM read_csv_auto('data/conditions.csv');

CREATE OR REPLACE TABLE medications AS 
SELECT * FROM read_csv_auto('data/medications.csv');

CREATE OR REPLACE TABLE procedures AS
SELECT * FROM read_csv_auto('data/procedures.csv');

CREATE OR REPLACE TABLE observations AS
SELECT * FROM read_csv_auto('data/observations.csv');

SELECT 'patients' AS table_name, COUNT(*) AS n FROM patients
UNION ALL
SELECT 'encounters', COUNT(*) FROM encounters
UNION ALL
SELECT 'conditions', COUNT(*) FROM conditions
UNION ALL
SELECT 'medications', COUNT(*) FROM medications
UNION ALL
SELECT 'procedures', COUNT(*) FROM procedures
UNION ALL
SELECT 'observations', COUNT(*) FROM observations;
