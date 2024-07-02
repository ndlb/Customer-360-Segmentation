-- Convert Purchase_Date column from Varchar type to Date type
ALTER TABLE customer_transaction ADD COLUMN date_new DATE;
UPDATE customer_transaction SET date_new = STR_TO_DATE(Purchase_Date, '%Y-%m-%d');
ALTER TABLE customer_transaction DROP COLUMN Purchase_Date;
ALTER TABLE customer_transaction RENAME COLUMN date_new TO Purchase_Date;

-- Convert created_date, stop_date columns from Varchar type to Date type
ALTER TABLE customer_registered  ADD COLUMN created_date_new DATE;
ALTER TABLE customer_registered ADD COLUMN stop_date_new DATE;
UPDATE customer_registered 
SET created_date_new = STR_TO_DATE(created_date, '%m/%d/%Y'),
    stop_date_new = STR_TO_DATE(stopdate, '%m/%d/%Y');
UPDATE customer_registered 
SET stop_date_new = null where stop_date_new = '0000-00-00';
ALTER TABLE customer_registered DROP COLUMN created_date;
ALTER TABLE customer_registered DROP COLUMN stopdate;
ALTER TABLE customer_registered RENAME COLUMN created_date_new TO created_date;

UPDATE customer_registered 
SET created_date_new = STR_TO_DATE(created_date, '%Y-%m-%d');


SELECT * FROM customer_transaction;

SELECT * FROM customer_registered cr ;

-- Calculate Regency (R), Frequency (F) and Monetary (M)
CREATE VIEW rfm AS
SELECT CustomerID,
       DATEDIFF('2022-09-01', MAX(ct.PURCHASE_DATE)) AS RECENCY,
       1.0 * COUNT(DISTINCT Purchase_Date) / TIMESTAMPDIFF(YEAR, MAX(cr.created_date_new), '2022-09-01') AS FREQUENCY,
       1.0 * SUM(GMV)/ TIMESTAMPDIFF(YEAR, MAX(cr.created_date_new), '2022-09-01') AS MONETARY
FROM customer_registered cr
JOIN customer_transaction ct ON cr.ID = ct.CustomerID
WHERE cr.stop_date IS NULL
GROUP BY ct.CustomerID;

-- Calculate Q1, Q2, Q3 of R, F, M using IQR
	-- R
		-- Q1
		select * from rfm
		order by RECENCY desc
		limit 1 offset 28520;
		-- Q2
		select * from rfm
		order by RECENCY desc
		limit 1 offset 57040;
		-- Q3
		select * from rfm
		order by RECENCY desc
		limit 1 offset 85560;

	-- F
		-- Q1
		select * from rfm
		order by FREQUENCY asc
		limit 1 offset 28520;
		-- Q2
		select * from rfm
		order by FREQUENCY asc
		limit 1 offset 57040;
		-- Q3
		select * from rfm
		order by FREQUENCY asc
		limit 1 offset 85560;
		
	-- M
		-- Q1
		select * from rfm
		order by MONETARY asc
		limit 1 offset 28520;
		-- Q2
		select * from rfm
		order by MONETARY asc
		limit 1 offset 57040;
		-- Q3
		select * from rfm
		order by MONETARY asc
		limit 1 offset 85560;

		

-- Convert R, F, M numeric values to a scale of 1-4
CREATE VIEW rfm_temp AS 
SELECT *, CONCAT(R, F, M) AS RFM
FROM (
    SELECT 
        CustomerID, 
        CASE 
            WHEN RECENCY < 31 THEN '4'
            WHEN RECENCY >= 31 AND RECENCY < 62 THEN '3'
            WHEN RECENCY >= 62 AND RECENCY < 92 THEN '2'
            ELSE '1'
        END AS R, 
        CASE 
            WHEN FREQUENCY < 0.14 THEN '1'
            WHEN FREQUENCY >= 0.14 AND FREQUENCY < 0.20 THEN '2'
            WHEN FREQUENCY >= 0.20 AND FREQUENCY < 0.25 THEN '3'
            ELSE '4'
        END AS F, 
        CASE 
            WHEN MONETARY < 17500 THEN '1'
            WHEN MONETARY >= 17500 AND MONETARY < 21250 THEN '2'
            WHEN MONETARY >= 21250 AND MONETARY < 26250 THEN '3'
            ELSE '4'
        END AS M
    FROM rfm
) AS A;

-- Segment customers according to BCG Matrix
CREATE VIEW rfm_segment AS 
select *,case
	when RFM in ('343', '344', '443', '444', '434','433', '333', '334') then 'VIP'
	when RFM in ('311', '312', '313', '314', '411', '412', '413', '414', '321', '322', '323', '324', '421', '422', '423', '424') then 'POTENTIAL'
	when RFM in ('341','441','241','342','442','242','431','331','233','234','144','244') then 'LOYAL' 
	else 'REGULAR'
end SEGMENT
from rfm_temp;

-- Numbers of each RFM type
select RFM, count(*) as num
from rfm_temp rt 
group by RFM 
order by num DESC;

-- Calculate GMV by segment
select R.Segment, sum(D.Revenue) as GMV
from rfm_segment R
left join (
	select ct.CustomerID, sum(GMV) as Revenue
	FROM customer_registered cr
	JOIN customer_transaction ct ON cr.ID = ct.CustomerID
	WHERE cr.stop_date IS NULL
	GROUP BY ct.CustomerID) D 
on R.CustomerID = D.CustomerID
group by R.Segment;

