-- 00_explore.sql
-- Exploratory checks used to build docs/data_dictionary.md.
-- Run after 01_load.sql: duckdb synthea.duckdb < sql/00_explore.sql

-- Patients: 163 of 1,163 have a DEATHDATE (1,000 living + 163 deceased)
SELECT COUNT(*) FROM patients WHERE DEATHDATE IS NOT NULL;

-- Encounter classes: 6 values, sum = 61,459 = total encounters (no NULL class)
SELECT ENCOUNTERCLASS, COUNT(*) AS n
FROM encounters
GROUP BY ENCOUNTERCLASS
ORDER BY n DESC;

-- conditions: (PATIENT, ENCOUNTER, CODE) verified unique -> 0 rows
SELECT PATIENT, ENCOUNTER, CODE, COUNT(*) AS n
FROM conditions
GROUP BY PATIENT, ENCOUNTER, CODE
HAVING COUNT(*) > 1;

-- medications: (PATIENT, ENCOUNTER, CODE) NOT unique -> 377 groups
SELECT PATIENT, ENCOUNTER, CODE, COUNT(*) AS n
FROM medications
GROUP BY PATIENT, ENCOUNTER, CODE
HAVING COUNT(*) > 1;

-- medications: every duplicate group has exactly 2 rows -> MAX(n) = 2
WITH dupes AS (
    SELECT PATIENT, ENCOUNTER, CODE, COUNT(*) AS n
    FROM medications
    GROUP BY PATIENT, ENCOUNTER, CODE
    HAVING COUNT(*) > 1
)
SELECT MAX(n) FROM dupes;

-- medications: example of a duplicate group -> rows differ in STOP, DISPENSES, and cost
-- (one same-day dispense vs. a ~1-year prescription with 12 dispenses), which motivated adding STOP to the key
-- Also observed: TOTALCOST = BASE_COST * DISPENSES in both rows (candidate validation rule)
SELECT * FROM medications
WHERE PATIENT = 'd1ac7006-362b-cc1d-d516-f11d65055473'
  AND ENCOUNTER = 'a898e77c-f64f-eec8-ff47-c80a24cec5ed'
  AND CODE = 897718;

-- medications: adding STOP reduces duplicate groups from 377 to 24
SELECT PATIENT, ENCOUNTER, CODE, STOP, COUNT(*) AS n
FROM medications
GROUP BY PATIENT, ENCOUNTER, CODE, STOP
HAVING COUNT(*) > 1;

-- medications: 0 exact duplicate rows (56,430 distinct = 56,430 total)
WITH dist AS (
    SELECT DISTINCT * FROM medications
)
SELECT COUNT(*) FROM dist;

-- medications: example of a remaining group -> identical except BASE_COST/TOTALCOST
-- Conclusion: no natural key in medications.
SELECT * FROM medications
WHERE PATIENT = '03777c32-ed98-50e2-f75d-cbcad532c610'
  AND ENCOUNTER = '4ae64c5e-0164-b998-a5fa-c61693ae8ae0'
  AND CODE = 705129;
