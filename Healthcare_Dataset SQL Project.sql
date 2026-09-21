-- DATA PREPARATION AND DATA CLEANING

-- 1. Schema and Raw Table Creation 

-- NOTE : No natural unique identifier exists in the source data (e.g., Patient ID) 
-- and no surrogate key was added since none of the analysis questions require row referencing
          
CREATE TABLE healthcare_records(
`Name` VARCHAR(50),
`Age` INT,
`Gender` VARCHAR(10),
`Blood Type` VARCHAR(10),
`Medical Condition` VARCHAR(100),
`Date of Admission` VARCHAR(20),
`Doctor` VARCHAR(50),
`Hospital` VARCHAR(150),
`Insurance` VARCHAR(50),
`Billing Amount` DECIMAL(10, 2),
`Room Number` INT,
`Admission Type` VARCHAR(10),
`Discharge Date` VARCHAR(20),
`Medication` VARCHAR(100),
`Test Results` VARCHAR(50)
);

-- 2. Load raw CSV data into healthcare_records 

LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/healthcare_dataset.csv'
INTO TABLE healthcare_records
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(`Name`, `Age`, `Gender`, `Blood Type`, `Medical Condition`,
`Date of Admission`, `Doctor`, `Hospital`, `Insurance`, `Billing Amount`,
`Room Number`, `Admission Type` ,`Discharge Date`,`Medication` ,`Test Results`);

-- 3. Import Validation/QA

SHOW WARNINGS;          -- Check for warnings from the import (e.g., decimal truncation on Billing Amount)

SELECT COUNT(*) FROM healthcare_records;   
SELECT * FROM healthcare_records LIMIT 2;
SELECT DISTINCT `Discharge Date` FROM healthcare_records LIMIT 20;

-- 4. Create Staging Table

CREATE TABLE healthcare_records_staging(
`Name` VARCHAR(50),
`Age` INT,
`Gender` VARCHAR(10),
`Blood Type` VARCHAR(10),
`Medical Condition` VARCHAR(100),
`Date of Admission` VARCHAR(20),
`Doctor` VARCHAR(50),
`Hospital` VARCHAR(150),
`Insurance` VARCHAR(50),
`Billing Amount` DECIMAL(10, 2),
`Room Number` INT,
`Admission Type` VARCHAR(10),
`Discharge Date` VARCHAR(20),
`Medication` VARCHAR(100),
`Test Results` VARCHAR(50)
);

-- 5. Populating Staging Table from Raw Data

INSERT INTO healthcare_records_staging
SELECT * FROM healthcare_records;

-- 6. Validate staging table population (row count check)

SELECT COUNT(*) FROM healthcare_records_staging;

-- 7. Convert Date columns from VARCHAR to DATE in staging table

ALTER TABLE healthcare_records_staging
MODIFY COLUMN `Date of Admission` DATE;
ALTER TABLE healthcare_records_staging
MODIFY COLUMN `Discharge Date` DATE;

DESCRIBE healthcare_records_staging;

SELECT `Date of Admission`, `Discharge Date` FROM healthcare_records_staging LIMIT 5;

-- 8. Explore categorical columns for data quality

SELECT DISTINCT `Medical Condition` FROM healthcare_records_staging;
SELECT DISTINCT `Admission Type` FROM healthcare_records_staging;
SELECT DISTINCT `Test Results` FROM healthcare_records_staging;
SELECT DISTINCT `Blood Type` FROM healthcare_records_staging;
SELECT DISTINCT `Gender` FROM healthcare_records_staging;
SELECT DISTINCT `Insurance` FROM healthcare_records_staging;

-- All values clean, no inconsistencies found

-- 9. Check for duplicate rows

WITH duplicate_check AS (
  SELECT *,
  ROW_NUMBER() OVER(
    PARTITION BY `Name`, `Age`, `Gender`, `Blood Type`, `Medical Condition`,
    `Date of Admission`, `Doctor`, `Hospital`, `Insurance`, `Billing Amount`, `Room Number`, 
    `Admission Type`, `Discharge Date`, `Medication`, `Test Results`) AS row_num
  FROM healthcare_records_staging
  )
SELECT * FROM duplicate_check
WHERE row_num > 1;                 -- 534 duplicate rows found
 
-- Create second staging table with a new column row_num to delete the duplicate rows

CREATE TABLE healthcare_records_staging2 (
  `Name` varchar(50) DEFAULT NULL,
  `Age` int DEFAULT NULL,
  `Gender` varchar(10) DEFAULT NULL,
  `Blood Type` varchar(10) DEFAULT NULL,
  `Medical Condition` varchar(100) DEFAULT NULL,
  `Date of Admission` date DEFAULT NULL,
  `Doctor` varchar(50) DEFAULT NULL,
  `Hospital` varchar(150) DEFAULT NULL,
  `Insurance` varchar(50) DEFAULT NULL,
  `Billing Amount` decimal(10,2) DEFAULT NULL,
  `Room Number` int DEFAULT NULL,
  `Admission Type` varchar(10) DEFAULT NULL,
  `Discharge Date` date DEFAULT NULL,
  `Medication` varchar(100) DEFAULT NULL,
  `Test Results` varchar(50) DEFAULT NULL,
  `row_num` INT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

SELECT * FROM healthcare_records_staging2;          -- Confirm staging2 table structure is empty and ready before insert

INSERT INTO healthcare_records_staging2
SELECT *,
  ROW_NUMBER() OVER(
    PARTITION BY `Name`, `Age`, `Gender`, `Blood Type`, `Medical Condition`,
    `Date of Admission`, `Doctor`, `Hospital`, `Insurance`, `Billing Amount`, `Room Number`, 
    `Admission Type`, `Discharge Date`, `Medication`, `Test Results`) AS row_num
  FROM healthcare_records_staging;

SELECT * FROM healthcare_records_staging2
WHERE row_num > 1;                                 -- Re-verify duplicate count after row_num column added (cross check against earlier CTE duplicate check)

DELETE FROM healthcare_records_staging2
WHERE row_num > 1;                                 -- Duplicate deletion successful
SELECT * FROM healthcare_records_staging2;
SELECT COUNT(*) FROM healthcare_records_staging2;  -- Verify row count after duplicate removal (expect 54,966)

ALTER TABLE healthcare_records_staging2
DROP COLUMN row_num;                               -- Removing row_num column after successful deletion of duplicates

-- 10. Check for NULL/Blanks in Name column, since a row with no patient name has no usable identifier for analysis

SELECT COUNT(*) AS missing_name_count
FROM healthcare_records_staging2
WHERE `Name` IS NULL OR TRIM(`Name`) = '';

-- DATA ANALYSIS / BUSINESS QUESTIONS

-- Q1. How many total patient records are there ? 

SELECT COUNT(*) FROM healthcare_records_staging2;

-- Q2. What is the distribution of patients by gender ? 

SELECT `Gender`, COUNT(*) AS patient_count
FROM healthcare_records_staging2 
GROUP BY `Gender`;

-- Q3. What are the most common medical conditions ? 

SELECT `Medical Condition`, COUNT(*) AS medical_condition_occurrence
FROM healthcare_records_staging2 
GROUP BY `Medical Condition`
ORDER BY medical_condition_occurrence DESC;

-- Q4. What are the most common medical conditions by gender ? 

SELECT `Gender`, `Medical Condition`, COUNT(*) AS condition_count
FROM healthcare_records_staging2
GROUP BY `Gender`, `Medical Condition`
ORDER BY `Gender`, condition_count DESC; 

-- Q5. What is the average billing amount by medical condition ? 

SELECT `Medical Condition`, ROUND(AVG(`Billing Amount`), 2) AS avg_billing_amt
FROM healthcare_records_staging2 
GROUP BY `Medical Condition`
ORDER BY avg_billing_amt DESC;		

-- Q6. What is the average length of stay by admission type ? 

SELECT `Admission Type`, ROUND(AVG(DATEDIFF(`Discharge Date`, `Date of Admission`)), 2)
AS avg_length_of_stay
FROM healthcare_records_staging2
GROUP BY `Admission Type`
ORDER BY avg_length_of_stay;

-- Q7. Which hospitals have the highest number of patients ? 

SELECT `Hospital`, COUNT(*) AS patient_count
FROM healthcare_records_staging2
GROUP BY `Hospital`
ORDER BY patient_count DESC
LIMIT 10;

-- Q8. What is the average billing amount by insurance provider ? 

SELECT `Insurance`, ROUND(AVG(`Billing Amount`), 2) AS avg_billing_amt
FROM healthcare_records_staging2 
GROUP BY `Insurance`
ORDER BY avg_billing_amt DESC;

-- Q9. What are the top 3 medical conditions by average billing amount ? 

WITH avg_cte AS
(
 SELECT `Medical Condition`,
 ROUND(AVG(`Billing Amount`), 2) AS avg_billing_amt,
 DENSE_RANK() OVER(ORDER BY ROUND(AVG(`Billing Amount`), 2) DESC) AS rank_num
 FROM healthcare_records_staging2
 GROUP BY `Medical Condition`
 )
SELECT * FROM avg_cte
WHERE rank_num <= 3;
 

-- KEY FINDINGS

-- Across nearly every dimension analyzed (medical condition, admission type, insurance provider,
-- and gender), patient counts and average billing amounts show remarkably little variation. 
-- In a real world healthcare dataset, conditions like Cancer would be expected to show meaningfully
-- higher billing than Hypertension or Arthritis, and admissions would rarely be this evenly split. 
-- This uniformity strongly suggests the dataset was synthetically generated with randomized values,
-- rather than reflecting genuine real world healthcare cost and utilization patterns.
































