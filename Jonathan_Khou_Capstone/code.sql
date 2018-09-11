--1. Get familiar with the data - get data limit to 100
 SELECT *
 FROM Subscriptions
 LIMIT 1;
 
--2. Identify company operating months and available segments of users - get max and min timeframes
 SELECT MIN(subscription_start) as 'Earliest_Start',
 				MAX(subscription_end) AS 'Max_Sub_End',
				MAX(subscription_start) AS 'Max_Sub_Start',
        --'Max_Sub_Start' is useful if it is in the same month as the 'Max_Sub_End' because the business rule requires the user to hold the subscription for +31 days at minimum
        segment
 FROM subscriptions
 GROUP BY 4
 ORDER BY 1,2 DESC;

--The below statement is used to show the total pool of users per segment
SELECT segment,
       COUNT(DISTINCT Id) AS 'Count'
FROM subscriptions
GROUP BY 1;

--3.Visualize the churn trend over the first 3 month period - Start by creating a months table to reference
WITH months AS (
SELECT '2017-01-01' AS first_day,
			 '2017-01-31' AS last_day
UNION
SELECT '2017-02-01' AS first_day,
  		 '2017-02-28' AS last_day
UNION
SELECT '2017-03-01' AS first_day,
  		 '2017-03-31' AS last_day
--The below code can be uncommented in order to adjust the results (depends on what data is desired)
--UNION
--SELECT '2017-04-01' AS first_day,
--			 '2017-04-30' AS last_day
),

--4.Cross join the subscriptions and months table
cross_join AS (
SELECT * 
FROM subscriptions 
CROSS JOIN months),

--5.Create a new table that references the cross_join table to identify active users per desired segment 
status AS (
SELECT id, first_day AS month, 
CASE WHEN (subscription_start < first_day) 
  AND (subscription_end > first_day OR subscription_end IS NULL) 
  And (segment = 87)
  THEN 1
	ELSE 0
	END AS is_active_87,
CASE WHEN (subscription_start < first_day) 
  AND (subscription_end > first_day OR subscription_end IS NULL) 
  AND (segment = 30)
  THEN 1
  ELSE 0
	END AS is_active_30,

--6. Add an is_canceled_87 and is_canceled_30 column to the temporary table to identify monthly cancellations
CASE WHEN (subscription_end BETWEEN first_day AND last_day)
  AND (segment = 87)
  THEN 1
  ELSE 0
END AS is_canceled_87,
CASE WHEN (subscription_end BETWEEN first_day AND last_day)
  AND (segment = 30)
  THEN 1
  ELSE 0
END AS is_canceled_30
FROM cross_join
),

--7. Create a temporary table that sums the active users and cancellations for each segment, respectively
status_aggregate AS (
SELECT month,
  		 SUM(is_active_87) AS sum_active_87,
  		 SUM(is_active_30) AS sum_active_30,
  		 SUM(is_canceled_87) AS sum_canceled_87,
  		 SUM(is_canceled_30) AS sum_canceled_30
FROM status
GROUP BY 1
)

--8. Calculate monthly churn rate and overall churn rate
--The below statement calculates churn rates monthly
SELECT month,
			 ((status_aggregate.sum_canceled_87*1.0) / (status_aggregate.sum_active_87*1.0)) AS 'Seg_87_Churn',
       ((status_aggregate.sum_canceled_30*1.0) / (status_aggregate.sum_active_30*1.0)) AS 'Seg_30_Churn'
FROM status_aggregate;

--The below statement calculates churn rates overall (by segment) - uncomment to use
--SELECT ((SUM(status_aggregate.sum_canceled_87)*1.0) / (SUM(status_aggregate.sum_active_87)*1.0)) AS 'Overall Churn 87',
--			 ((SUM(status_aggregate.sum_canceled_30)*1.0) / (SUM(status_aggregate.sum_active_30)*1.0)) AS 'Overall Churn 30'
--FROM status_aggregate;                                                  

--------------------------------------------------------------------------------
                                                  
--9. BONUS: Below contains modified code for a large number of segments (scalability)

--3.Visualize the churn trend over the first 3 month period - Start by creating a months table to reference. Note: Dec first/last day helps with overall churn
WITH months AS (
SELECT '2016-12-01' AS first_day,
			 '2016-12-31' AS last_day
UNION
SELECT '2017-01-01' AS first_day,
			 '2017-01-31' AS last_day
UNION
SELECT '2017-02-01' AS first_day,
  		 '2017-02-28' AS last_day
UNION
SELECT '2017-03-01' AS first_day,
  		 '2017-03-31' AS last_day
),
--4.Cross join the subscriptions and months table
cross_join AS (
SELECT * 
FROM subscriptions 
CROSS JOIN months),
--9. Modified to include additional case statement (for new users per month) and grouping clause to simplify coding
status AS (
SELECT id, segment, first_day AS month, 
CASE WHEN (subscription_start < first_day) 
  AND (subscription_end > first_day OR subscription_end IS NULL)
  THEN 1
	ELSE 0
	END AS is_active,
CASE WHEN (subscription_end BETWEEN first_day AND last_day)
  THEN 1
  ELSE 0
END AS is_canceled,
CASE WHEN (subscription_start BETWEEN first_day and last_day) 
  THEN 1
  ELSE 0
END AS new_user
FROM cross_join
),
status_aggregate AS (
SELECT segment,
  		 month,
  		 SUM(new_user) as new_user_count,
  		 SUM(is_active) AS active,
  		 SUM(is_canceled) AS cancellations
FROM status
GROUP BY 1, 2
)
--8. Calculate monthly churn rate and overall churn rate (modified)
--The below statement calculates churn rates monthly
SELECT segment, 
			 month,
			 ((status_aggregate.cancellations*1.0) / (status_aggregate.active*1.0)) AS 'Churn Rate'                                             
FROM status_aggregate;

--The below statement calculates churn rates overall (by segment) - uncomment to use
--SELECT segment,
--			 ((SUM(status_aggregate.cancellations)*1.0) / (SUM(status_aggregate.new_user_count)*1.0)) AS 'Overall Churn'
--FROM status_aggregate
--GROUP BY 1;  