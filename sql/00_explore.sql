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

-- procedures: (PATIENT, ENCOUNTER, CODE) NOT unique -> 103 groups (some with 10+ rows)
SELECT PATIENT, ENCOUNTER, CODE, COUNT(*) AS n
FROM procedures
GROUP BY PATIENT, ENCOUNTER, CODE
HAVING COUNT(*) > 1;

-- procedures: (PATIENT, ENCOUNTER, CODE, STOP) verified unique -> 0 rows
-- Repeats are the same procedure performed multiple times in one encounter
SELECT PATIENT, ENCOUNTER, CODE, STOP, COUNT(*) AS n
FROM procedures
GROUP BY PATIENT, ENCOUNTER, CODE, STOP
HAVING COUNT(*) > 1;

-- procedures: most-repeated codes are oxygen by mask and prone positioning;
-- each code maps to exactly one description
SELECT DISTINCT CODE, DESCRIPTION
FROM procedures
WHERE CODE IN (371908008, 431182000);

-- procedures: encounters with oxygen/prone procedures, by class and reason (first join)
-- Result: CHF 84 emergency + 84 inpatient; COVID-19 21 inpatient; 2 ambulatory one-offs.
-- COUNT(DISTINCT e.Id) prevents inflation from repeated procedure rows per encounter.
SELECT e.ENCOUNTERCLASS, e.REASONDESCRIPTION, COUNT(DISTINCT e.Id) AS n_encounters
FROM procedures p
JOIN encounters e ON p.ENCOUNTER = e.Id
WHERE p.CODE IN (371908008, 431182000)
GROUP BY e.ENCOUNTERCLASS, e.REASONDESCRIPTION
ORDER BY n_encounters DESC;

-- Same, split by procedure code.
-- Result: matching encounter counts (CHF 84/84, COVID 21/20) SUGGEST the two procedures
-- co-occur, but this is NOT yet verified per encounter (equal totals could be different encounters).
-- If confirmed, prone positioning in CHF encounters is likely a Synthea modeling artifact.
SELECT e.ENCOUNTERCLASS, e.REASONDESCRIPTION, p.CODE, COUNT(DISTINCT e.Id) AS n_encounters
FROM procedures p
JOIN encounters e ON p.ENCOUNTER = e.Id
WHERE p.CODE IN (371908008, 431182000)
GROUP BY e.ENCOUNTERCLASS, e.REASONDESCRIPTION, p.CODE
ORDER BY n_encounters DESC;

-- procedures: duplicate groups rolled up by code (replaces guessing from 40 visible rows)
-- Result: oxygen (40 groups) and prone positioning (39) dominate; remaining repeats are
-- ICU/inpatient procedures (IV fluids, stepdown, ICU admit, ventilation, hemodialysis).
-- n_groups sums to 97, NOT 103: grouping by DESCRIPTION split groups for codes with
-- multiple descriptions (see next check).
WITH dupes AS (
    SELECT PATIENT, ENCOUNTER, CODE, DESCRIPTION, COUNT(*) AS n
    FROM procedures
    GROUP BY PATIENT, ENCOUNTER, CODE, DESCRIPTION
    HAVING COUNT(*) > 1
)
SELECT CODE, DESCRIPTION, COUNT(*) AS n_groups, SUM(n) AS n_rows
FROM dupes
GROUP BY CODE, DESCRIPTION
ORDER BY n_groups DESC;

-- procedures: code consistency -> 6 codes have more than one DESCRIPTION
SELECT CODE, COUNT(DISTINCT DESCRIPTION) AS n_descriptions
FROM procedures
GROUP BY CODE
HAVING COUNT(DISTINCT DESCRIPTION) > 1;

-- procedures: the descriptions for those 6 codes (14 rows)
-- 5 codes are cosmetic (suffix or short/full name); 5880005 has 4 context-specific labels.
-- Conclusion: group and count by CODE, not DESCRIPTION.
SELECT DISTINCT CODE, DESCRIPTION
FROM procedures
WHERE CODE IN (
    SELECT CODE
    FROM procedures
    GROUP BY CODE
    HAVING COUNT(DISTINCT DESCRIPTION) > 1
)
ORDER BY CODE;
