--SQL AI Assessment
--PART 1
--QUESTION: Which specialty has the highest prescription cost per day?  
--QUESTION: Which has the lowest?

-- My code: highest
SELECT 
	specialty_description,
	SUM(total_day_supply) AS daily_supply,
	SUM(total_drug_cost) AS daily_cost,
	ROUND(SUM(total_drug_cost)/SUM(total_day_supply), 2) AS cost_per_day
FROM prescriber
JOIN prescription
	ON prescriber.npi = prescription.npi
GROUP BY specialty_description
ORDER BY cost_per_day DESC
LIMIT 1;
-- My code: Lowest
SELECT 
	specialty_description,
	SUM(total_day_supply) AS daily_supply,
	SUM(total_drug_cost) AS daily_cost,
	ROUND(SUM(total_drug_cost)/SUM(total_day_supply), 2) AS cost_per_day
FROM prescriber
JOIN prescription
	ON prescriber.npi = prescription.npi
GROUP BY specialty_description
ORDER BY cost_per_day ASC
LIMIT 1;

--Claude code: Highest
SELECT 
    p.specialty_description,
    SUM(pr.total_drug_cost) / NULLIF(SUM(pr.total_day_supply), 0) AS cost_per_day
FROM prescription pr
JOIN prescriber p ON pr.npi = p.npi
GROUP BY p.specialty_description
ORDER BY cost_per_day DESC
LIMIT 1;
--Claude code: Highest AND Lowest together
SELECT 
    specialty_description,
    cost_per_day,
    ranking
FROM (
    SELECT 
        p.specialty_description,
        SUM(pr.total_drug_cost) / NULLIF(SUM(pr.total_day_supply), 0) AS cost_per_day,
        'Highest' AS ranking
    FROM prescription pr
    JOIN prescriber p ON pr.npi = p.npi
    GROUP BY p.specialty_description
    ORDER BY cost_per_day DESC
    LIMIT 1
) highest

UNION ALL

SELECT 
    specialty_description,
    cost_per_day,
    ranking
FROM (
    SELECT 
        p.specialty_description,
        SUM(pr.total_drug_cost) / NULLIF(SUM(pr.total_day_supply), 0) AS cost_per_day,
        'Lowest' AS ranking
    FROM prescription pr
    JOIN prescriber p ON pr.npi = p.npi
    GROUP BY p.specialty_description
    ORDER BY cost_per_day ASC
    LIMIT 1
) lowest;
--Claude was VERY confident and returned the same answers.

--QUESTION: How many providers are assigned to each specialty?
-- My code
SELECT 
    pr.specialty_description,
    COUNT(DISTINCT pr.npi) AS npi_count,
	CASE
		WHEN COUNT(rx.npi) >0 THEN TRUE
		ELSE FALSE
	END AS has_prescriptions
FROM prescriber pr
LEFT JOIN prescription rx
ON pr.npi = rx.npi
GROUP BY specialty_description
ORDER BY npi_count DESC;

--Claude code
SELECT 
    p.specialty_description,
    COUNT(DISTINCT p.npi) AS prescriber_count,
    CASE 
        WHEN COUNT(pr.npi) > 0 THEN TRUE 
        ELSE FALSE 
    END AS has_prescriptions
FROM prescriber p
LEFT JOIN prescription pr ON p.npi = pr.npi
GROUP BY p.specialty_description
ORDER BY prescriber_count DESC;
--Claude provided code using an EXISTS in the SELECT statement. 
--It wasfollowed by a message saying it wouldn't work correctly. 
--Then the new code was provided with HIGH confidence.

--QUESTION: Find the specialty that has written a prescription with the most 
--providers. 
--My code
SELECT
	pr.specialty_description,
	COUNT (DISTINCT pr.npi) AS provider_count
FROM prescriber pr
LEFT JOIN prescription rx
	ON pr.npi = rx.npi
GROUP BY pr.specialty_description
ORDER BY provider_count DESC
LIMIT 1;
--Then find the specialty with the most providers where none has written a 
--prescription.
--My code
SELECT
	pr.specialty_description,
	COUNT (DISTINCT pr.npi) AS non_prescriber_count
FROM prescriber pr
LEFT JOIN prescription rx
	ON pr.npi = rx.npi
WHERE rx.npi IS NULL
GROUP BY pr.specialty_description
ORDER BY non_prescriber_count DESC
LIMIT 1;

--Claude code 1 (HIGH confidence with note on the use of INNER vs LEFT JOIN)
SELECT 
    p.specialty_description,
    COUNT(DISTINCT p.npi) AS prescriber_count
FROM prescriber p
JOIN prescription pr ON p.npi = pr.npi
GROUP BY p.specialty_description
ORDER BY prescriber_count DESC
LIMIT 1;
--Claude code 2 (HIGH confidence with comment regarding standard "anti-join"
--pattern -a LEFT JOIN + WHERE IS NULL-)
SELECT 
    p.specialty_description,
    COUNT(DISTINCT p.npi) AS prescriber_count
FROM prescriber p
LEFT JOIN prescription pr ON p.npi = pr.npi
WHERE pr.npi IS NULL
GROUP BY p.specialty_description
ORDER BY prescriber_count DESC
LIMIT 1;

--Find prescribers who have witten prescriptions for a drug to a single beneficiary.

--bene_count – The total number of unique Medicare Part D beneficiaries 
--with at least one claim for the drug. 
--Counts fewer than 11 are suppressed and are indicated by a blank. 

--My code (returns 0 results)
SELECT 
	pr.npi
FROM prescriber pr
JOIN prescription rx
	ON pr.npi = rx.npi
WHERE rx.npi < 11
--Claude could not provide a query
--In addition to page 5, Claude cited from the Data Redaction and Suppression
--Section "aggregated records which are derived from 10 or fewer claims are
--excluded from the Part D Prescriber PUF"

--PART 2
--Write a query to get a list of each distinct generic_name on the drug table.
--Mycode
SELECT 
	DISTINCT generic_name
FROM drug

--PART 3
--Claude code to utilize the generic drug category csv
--I was given two options. One altered the original data, but didnt' require 
--future joins. The other safer option creates a lookup table. I chose the lookup table.
CREATE TABLE drug_category (
    generic_name VARCHAR(100) PRIMARY KEY,
    category     VARCHAR(100)
);

--Verification 1 - successful
SELECT COUNT (*)
FROM drug_category

--Verification 2 - successful
SELECT category, COUNT(*) AS drug_count
FROM drug_category
GROUP BY category
ORDER BY drug_count DESC;

--Write a query using the new table to find the total_day_supply and 
--total_cost for each specialty/drug_category combination.
--My code
SELECT 
	dc.category,
	SUM(rx.total_drug_cost) AS total_cost,
	SUM(rx.total_day_supply) AS total_supply,
	TO_CHAR (
		SUM(rx.total_drug_cost)::numeric
		/SUM(rx.total_day_supply), 
		'FM$999,999,999.00'
	) AS cost_per_day
FROM prescription rx
JOIN drug_category dc
	ON rx.drug_name = dc.generic_name
GROUP BY dc.category
ORDER BY cost_per_day DESC;

--My prompt to Claude
--I wrote a query that created a table and I want to see how you would write 
--a query for the same purpose.
--I want to create a table calculating the cost per day of drugs by category 
--using the drug_category table we already created.
--I did this by dividing the total_drug_cost by the total_supply. 
--I want the resulting cost_per_day to be displayed in dollars.

--Claude code (HIGH confidence)
CREATE TABLE category_cost_per_day AS
SELECT 
    dc.category,
    ROUND(
        (SUM(pr.total_drug_cost) / NULLIF(SUM(pr.total_day_supply), 0))::NUMERIC, 
        2
    ) AS cost_per_day
FROM prescription pr
JOIN drug d ON pr.drug_name = d.drug_name
JOIN drug_category dc ON d.generic_name = dc.generic_name
GROUP BY dc.category
ORDER BY cost_per_day DESC;

SELECT *
FROM category_cost_per_day;

--VERY different results!
--Mine shows Onocology $3.30 first
--Claude shows Vaccines at 47.55 first (oncology is second at 36.56)
--Clause suggests that my JOIN is problematic because the generic_name and the 
--drug_name (from prescription) may not actually match.