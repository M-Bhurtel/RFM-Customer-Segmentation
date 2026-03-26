-- Step 1: Append all monthly sales tables together

CREATE OR REPLACE TABLE `rfm-1998.sales.sales_2025` AS
SELECT * FROM `rfm-1998.sales.202501`
UNION ALL SELECT * FROM `rfm-1998.sales.202502`
UNION ALL SELECT * FROM `rfm-1998.sales.202503`
UNION ALL SELECT * FROM `rfm-1998.sales.202504`
UNION ALL SELECT * FROM `rfm-1998.sales.202505`
UNION ALL SELECT * FROM `rfm-1998.sales.202506`
UNION ALL SELECT * FROM `rfm-1998.sales.202507`
UNION ALL SELECT * FROM `rfm-1998.sales.202508`
UNION ALL SELECT * FROM `rfm-1998.sales.202509`
UNION ALL SELECT * FROM `rfm-1998.sales.202510`
UNION ALL SELECT * FROM `rfm-1998.sales.202511`
UNION ALL SELECT * FROM `rfm-1998.sales.202512`;


-- Step 2: Calculate recency, frequency, monetary, r, f, m ranks
-- Combine views with CTEs 
CREATE OR REPLACE VIEW `rfm-1998.sales.rfm_metrics`
AS
With current_date AS (
  SELECT DATE('2026-03-25') AS  analysis_date -- todays' date
),
rfm AS (
  SELECT 
    CustomerID,
    Max(OrderDate) AS last_order_date,
    date_diff ((select analysis_date from current_date), MAX(OrderDate), DAY) AS recency,
    COUNT(*) AS frequency,
    SUM(OrderValue) AS monetary
  FROM `rfm-1998.sales.sales_2025`
  Group By CustomerID
)

SELECT 
  rfm.*, 
  ROW_NUMBER() OVER (ORDER BY recency ASC) AS r_rank,
  ROW_NUMBER() OVER (ORDER BY frequency DESC) AS f_rank,
  ROW_NUMBER() OVER (ORDER BY monetary DESC) AS m_rank
From rfm;

-- Step 3: Assing decile (10 = best, 1= wrost)

Create or replace view `rfm-1998.sales.rfm_scores`
AS
Select 
 *,
 NTILE(10) OVER (ORDER BY r_rank DESC) As r_score,
 NTILE(10) OVER (ORDER BY f_rank DESC) As f_score,
 NTILE(10) OVER (ORDER BY m_rank DESC) As m_score
From `rfm-1998.sales.rfm_metrics`;

-- Step 4: total score

CREATE OR REPLACE VIEW `rfm-1998.sales.rfm_total_scores`
AS
SELECT 
  CustomerID,
  recency,
  frequency,
  monetary,
  r_score,
  f_score,
  m_score,
  (r_score + f_score + m_score) AS frm_total_score
From `rfm-1998.sales.rfm_scores`
ORDER BY frm_total_score DESC;

-- STEP 5: BI ready frm segments table

CREATE OR REPLACE TABLE `rfm-1998.sales.rfm_segments_final`
AS
SELECT
  CustomerID,
  recency,
  frequency,
  monetary,
  r_score,
  f_score,
  m_score,
  frm_total_score,
  CASE 
    WHEN frm_total_score >= 28 THEN 'Champions' -- 28-30
    WHEN frm_total_score >= 24 THEN 'Loyal VIPs'
    WHEN frm_total_score >= 20 THEN 'Potential Loyalists'
    WHEN frm_total_score >= 16 THEN 'Promising'
    WHEN frm_total_score >= 12 THEN 'Engaged'
    WHEN frm_total_score >= 8 THEN 'Requires Attention'
    WHEN frm_total_score >= 4 THEN 'At Risk'
    Else 'Lost/Inactive'
    END AS rfm_segment
FROM `rfm-1998.sales.rfm_total_scores`;










