--ltv
SELECT ROUND(AVG(total_spent), 2) AS avg_ltv
FROM (
  SELECT card, SUM(summ) AS total_spent
  FROM bonuscheques
  WHERE {{datetime}}
    AND card LIKE '2000%'
    AND card NOT IN ('2000200189985', '2000200170860', '2000200196556')
  GROUP BY card
) t;

--ltv по аптекам
  SELECT shop, ROUND(AVG(total_spent), 2) AS avg_ltv
FROM (
  SELECT card, shop, SUM(summ) AS total_spent
  FROM bonuscheques
  WHERE {{datetime}}
    AND card LIKE '2000%'
    AND card NOT IN ('2000200189985', '2000200170860', '2000200196556')
  GROUP BY card, shop
) t
GROUP BY shop;

--RFM
WITH rfm_base AS (
  SELECT
    card,
    ('2022-06-09'::DATE - MAX(datetime)::DATE) AS recency,
    COUNT(*) AS frequency,
    SUM(summ) AS monetary
  FROM bonuscheques
  WHERE {{datetime}}
    AND card LIKE '2000%'
    AND card NOT IN ('2000200189985', '2000200170860', '2000200196556')
  GROUP BY card
),
rfm_scores AS (
  SELECT
    card,
    CASE
      WHEN recency <= 30 THEN 3
      WHEN recency <= 80 THEN 2
      ELSE 1
    END AS recency_score,
    CASE
      WHEN frequency >= 7 THEN 3
      WHEN frequency >= 3 THEN 2
      ELSE 1
    END AS frequency_score,
    CASE
      WHEN monetary > 2200 THEN 3
      WHEN monetary > 900 THEN 2
      ELSE 1
    END AS monetary_score
  FROM rfm_base
),
rfm_segments AS (
  SELECT
    card,
    recency_score,
    frequency_score,
    monetary_score,
    CONCAT(recency_score, frequency_score, monetary_score) AS bisnes_segment,
    CASE
      WHEN (recency_score = 3 AND frequency_score = 3 AND monetary_score = 3) THEN 'vip'
      WHEN (recency_score = 3 AND frequency_score IN (2, 3) AND monetary_score IN (1, 2, 3)) THEN 'развивающиеся'
      WHEN (recency_score = 3 AND frequency_score = 1 AND monetary_score IN (1, 2, 3)) THEN 'новички'
      WHEN (recency_score = 2 AND frequency_score = 3 AND monetary_score IN (1, 2, 3)) THEN 'лояльные спящие'
      WHEN (recency_score = 2 AND frequency_score IN (1, 2) AND monetary_score IN (1, 2, 3)) THEN 'спящие'
      WHEN (recency_score = 1 AND frequency_score IN (2, 3) AND monetary_score IN (1, 2, 3)) THEN 'лояльные, потерявшие активность'
      WHEN (recency_score = 1 AND frequency_score = 1 AND monetary_score IN (1, 2, 3)) THEN 'потерянные'
    END AS customer_segment
  FROM rfm_scores
)
SELECT customer_segment, COUNT(card) AS customer_count
FROM rfm_segments
GROUP BY customer_segment;

--RFM по аптекам
WITH rfm_base AS (
  SELECT
    card,
    shop,
    ('2022-06-09'::DATE - MAX(datetime)::DATE) AS recency,
    COUNT(*) AS frequency,
    SUM(summ) AS monetary
  FROM bonuscheques
  WHERE {{datetime}}
    AND card LIKE '2000%'
    AND card NOT IN ('2000200189985', '2000200170860', '2000200196556')
  GROUP BY shop, card
),
rfm_scores AS (
  SELECT
    card,
    shop,
    CASE
      WHEN recency <= 30 THEN 3
      WHEN recency <= 80 THEN 2
      ELSE 1
    END AS recency_score,
    CASE
      WHEN frequency >= 7 THEN 3
      WHEN frequency >= 3 THEN 2
      ELSE 1
    END AS frequency_score,
    CASE
      WHEN monetary > 2200 THEN 3
      WHEN monetary > 900 THEN 2
      ELSE 1
    END AS monetary_score
  FROM rfm_base
),
rfm_segments AS (
  SELECT
    shop,
    card,
    recency_score,
    frequency_score,
    monetary_score,
    CONCAT(recency_score, frequency_score, monetary_score) AS bisnes_segment,
    CASE
      WHEN (recency_score = 3 AND frequency_score = 3 AND monetary_score = 3) THEN 'vip'
      WHEN (recency_score = 3 AND frequency_score IN (2, 3) AND monetary_score IN (1, 2, 3)) THEN 'развивающиеся'
      WHEN (recency_score = 3 AND frequency_score = 1 AND monetary_score IN (1, 2, 3)) THEN 'новички'
      WHEN (recency_score = 2 AND frequency_score = 3 AND monetary_score IN (1, 2, 3)) THEN 'лояльные спящие'
      WHEN (recency_score = 2 AND frequency_score IN (1, 2) AND monetary_score IN (1, 2, 3)) THEN 'спящие'
      WHEN (recency_score = 1 AND frequency_score IN (2, 3) AND monetary_score IN (1, 2, 3)) THEN 'лояльные, потерявшие активность'
      WHEN (recency_score = 1 AND frequency_score = 1 AND monetary_score IN (1, 2, 3)) THEN 'потерянные'
    END AS customer_segment
  FROM rfm_scores
)
SELECT shop, customer_segment, COUNT(card) AS customer_count
FROM rfm_segments
GROUP BY customer_segment, shop
ORDER BY customer_count;

--rfm + ltv
WITH rfm_base AS (
  SELECT
    card,
    ('2022-06-09'::DATE - MAX(datetime)::DATE) AS recency,
    COUNT(*) AS frequency,
    SUM(summ) AS monetary,
    SUM(summ) AS ltv
  FROM bonuscheques
  WHERE {{datetime}}
    AND card LIKE '2000%'
    AND card NOT IN ('2000200189985', '2000200170860', '2000200196556')
  GROUP BY card
),
rfm_scores AS (
  SELECT
    card, recency, frequency, monetary, ltv,
    CASE
      WHEN recency <= 30 THEN 3
      WHEN recency <= 80 THEN 2
      ELSE 1
    END AS recency_score,
    CASE
      WHEN frequency >= 7 THEN 3
      WHEN frequency >= 3 THEN 2
      ELSE 1
    END AS frequency_score,
    CASE
      WHEN monetary > 2200 THEN 3
      WHEN monetary > 900 THEN 2
      ELSE 1
    END AS monetary_score
  FROM rfm_base
),
rfm_segments AS (
  SELECT
    card, recency_score, frequency_score, monetary_score, ltv,
    CONCAT(recency_score, frequency_score, monetary_score) AS bisnes_segment,
    CASE
      WHEN (recency_score = 3 AND frequency_score = 3 AND monetary_score = 3) THEN 'vip'
      WHEN (recency_score = 3 AND frequency_score IN (2, 3) AND monetary_score IN (1, 2, 3)) THEN 'развивающиеся'
      WHEN (recency_score = 3 AND frequency_score = 1 AND monetary_score IN (1, 2, 3)) THEN 'новички'
      WHEN (recency_score = 2 AND frequency_score = 3 AND monetary_score IN (1, 2, 3)) THEN 'лояльные спящие'
      WHEN (recency_score = 2 AND frequency_score IN (1, 2) AND monetary_score IN (1, 2, 3)) THEN 'спящие'
      WHEN (recency_score = 1 AND frequency_score IN (2, 3) AND monetary_score IN (1, 2, 3)) THEN 'лояльные, потерявшие активность'
      WHEN (recency_score = 1 AND frequency_score = 1 AND monetary_score IN (1, 2, 3)) THEN 'потерянные'
    END AS customer_segment
  FROM rfm_scores
)
SELECT
  customer_segment,
  COUNT(card) AS customer_count,
  ROUND(AVG(ltv), 2) AS avg_ltv,
  ROUND(MIN(ltv), 2) AS min_ltv,
  ROUND(MAX(ltv), 2) AS max_ltv,
  ROUND(SUM(ltv), 2) AS total_ltv
FROM rfm_segments
GROUP BY customer_segment
ORDER BY
  CASE customer_segment
    WHEN 'vip' THEN 1
    WHEN 'развивающиеся' THEN 2
    WHEN 'новички' THEN 3
    WHEN 'лояльные спящие' THEN 4
    WHEN 'спящие' THEN 5
    WHEN 'лояльные, потерявшие активность' THEN 6
    WHEN 'потерянные' THEN 7
  END;
  
--rolling retention
WITH first_purchase AS (
  SELECT card, MIN(datetime) AS first_purchase_date
  FROM bonuscheques
  WHERE {{datetime}}
    AND card LIKE '2000%'
    AND card NOT IN ('2000200189985', '2000200170860', '2000200196556')
  GROUP BY card
),
cohort_data AS (
  SELECT
    fp.card,
    fp.first_purchase_date,
    TO_CHAR(fp.first_purchase_date, 'mm') AS cohort_month,
    b.datetime AS purchase_date,
    EXTRACT(DAY FROM b.datetime - fp.first_purchase_date) AS days_since_first_purchase
  FROM bonuscheques b
  JOIN first_purchase fp ON b.card = fp.card
),
retention_calculation AS (
  SELECT
    cohort_month,
    COUNT(DISTINCT CASE WHEN days_since_first_purchase >= 0 THEN card END) AS day0_users,
    COUNT(DISTINCT CASE WHEN days_since_first_purchase >= 5 THEN card END) AS day5_users,
    COUNT(DISTINCT CASE WHEN days_since_first_purchase >= 15 THEN card END) AS day15_users,
    COUNT(DISTINCT CASE WHEN days_since_first_purchase >= 20 THEN card END) AS day20_users,
    COUNT(DISTINCT CASE WHEN days_since_first_purchase >= 25 THEN card END) AS day25_users,
    COUNT(DISTINCT CASE WHEN days_since_first_purchase >= 30 THEN card END) AS day30_users,
    COUNT(DISTINCT CASE WHEN days_since_first_purchase >= 90 THEN card END) AS day90_users
  FROM cohort_data
  GROUP BY cohort_month
)
SELECT
  cohort_month,
  ROUND(day0_users * 100.0 / day0_users, 2) AS "day0",
  ROUND(day5_users * 100.0 / day0_users, 2) AS "day5",
  ROUND(day15_users * 100.0 / day0_users, 2) AS "day15",
  ROUND(day20_users * 100.0 / day0_users, 2) AS "day20",
  ROUND(day25_users * 100.0 / day0_users, 2) AS "day25",
  ROUND(day30_users * 100.0 / day0_users, 2) AS "day30",
  ROUND(day90_users * 100.0 / day0_users, 2) AS "day90"
FROM retention_calculation
GROUP BY cohort_month, day0_users, day5_users, day15_users, day20_users, day25_users, day30_users, day90_users
ORDER BY cohort_month;

--выручка по месяцам
SELECT
  TO_CHAR(datetime, 'yyyy-mm') AS month,
  SUM(summ) AS revenue,
  COUNT(DISTINCT card) AS active_clients
FROM bonuscheques
WHERE {{datetime}}
  AND card LIKE '2000%'
  AND card NOT IN ('2000200189985', '2000200170860', '2000200196556')
GROUP BY 1
ORDER BY 1;

--динамика выручки, клиентов, среднего чека по месяцам
SELECT
  SUM(summ) AS "общая выручка",
  ROUND(AVG(summ), 0) AS "средний чек",
  COUNT(DISTINCT card) AS "общее количество клиентов",
  TO_CHAR(datetime, 'yyyy-mm') AS "месяц"
FROM bonuscheques
WHERE {{datetime}}
  AND card LIKE '2000%'
  AND card NOT IN ('2000200189985', '2000200170860', '2000200196556')
GROUP BY TO_CHAR(datetime, 'yyyy-mm')
ORDER BY TO_CHAR(datetime, 'yyyy-mm');

--общая выручка
SELECT SUM(summ)
FROM bonuscheques
WHERE {{datetime}}
  AND card LIKE '2000%'
  AND card NOT IN ('2000200189985', '2000200170860', '2000200196556');

-- общее количество клиентов
SELECT COUNT(DISTINCT card)
FROM bonuscheques
WHERE {{datetime}}
  AND card LIKE '2000%'
  AND card NOT IN ('2000200189985', '2000200170860', '2000200196556');

--распределение выручки, клиентов по аптекам
SELECT shop, COUNT(DISTINCT card), SUM(summ)
FROM bonuscheques
WHERE {{datetime}}
  AND card LIKE '2000%'
  AND card NOT IN ('2000200189985', '2000200170860', '2000200196556')
GROUP BY shop;

--распределение клиентов по rfm-сегментам + доля в общей выручке
WITH rfm_base AS (
  SELECT
    card,
    ('2022-06-09'::DATE - MAX(datetime)::DATE) AS recency,
    COUNT(*) AS frequency,
    SUM(summ) AS monetary
  FROM bonuscheques
  WHERE {{datetime}}
    AND card LIKE '2000%'
    AND card NOT IN ('200200189985', '200200170860', '200200196556')
  GROUP BY card
),
rfm_scores AS (
  SELECT
    card, recency, frequency, monetary,
    CASE
      WHEN recency <= 30 THEN 3
      WHEN recency <= 90 THEN 2
      ELSE 1
    END AS recency_score,
    CASE
      WHEN frequency >= 7 THEN 3
      WHEN frequency >= 3 THEN 2
      ELSE 1
    END AS frequency_score,
    CASE
      WHEN monetary > 2200 THEN 3
      WHEN monetary > 900 THEN 2
      ELSE 1
    END AS monetary_score
  FROM rfm_base
),
rfm_data AS (
  SELECT
    card, recency, frequency, monetary, recency_score, frequency_score, monetary_score,
    CONCAT(recency_score, frequency_score, monetary_score) AS rfm_segment,
    CASE
      WHEN (recency_score = 3 AND frequency_score = 3 AND monetary_score = 3) THEN 'vip'
      WHEN (recency_score = 3 AND frequency_score IN (2, 3) AND monetary_score IN (1, 2, 3)) THEN 'развивающиеся'
      WHEN (recency_score = 3 AND frequency_score = 1 AND monetary_score IN (1, 2, 3)) THEN 'новички'
      WHEN (recency_score = 2 AND frequency_score = 3 AND monetary_score IN (1, 2, 3)) THEN 'лояльные спящие'
      WHEN (recency_score = 2 AND frequency_score IN (1, 2) AND monetary_score IN (1, 2, 3)) THEN 'спящие'
      WHEN (recency_score = 1 AND frequency_score IN (2, 3) AND monetary_score IN (1, 2, 3)) THEN 'лояльные, потерявшие активность'
      WHEN (recency_score = 1 AND frequency_score = 1 AND monetary_score IN (1, 2, 3)) THEN 'потерянные'
    END AS customer_segment
  FROM rfm_scores
),
total_revenue AS (
  SELECT SUM(monetary) AS total_monetary
  FROM rfm_base
)
SELECT
  r.customer_segment AS "rfm_сегмент",
  COUNT(*) AS "количество_клиентов",
  ROUND(AVG(r.monetary), 0) AS "средняя_выручка",
  ROUND((SUM(r.monetary) * 100.0 / tr.total_monetary), 0) AS "доля_выручки_в_%"
FROM rfm_data r
JOIN total_revenue tr ON TRUE
GROUP BY r.customer_segment, tr.total_monetary
ORDER BY
  CASE customer_segment
    WHEN 'vip' THEN 1
    WHEN 'развивающиеся' THEN 2
    WHEN 'новички' THEN 3
    WHEN 'лояльные спящие' THEN 4
    WHEN 'спящие' THEN 5
    WHEN 'лояльные, потерявшие активность' THEN 6
    WHEN 'потерянные' THEN 7
  END;
  
--среднее количество покупок на клиента
SELECT ROUND(AVG(frequency), 2) AS avg_frequency_per_client
FROM (
  SELECT card, COUNT(*) AS frequency
  FROM bonuscheques
  WHERE {{datetime}}
    AND card LIKE '2000%'
    AND card NOT IN ('200200189985', '200200170860', '200200196556')
  GROUP BY card
) t;

--среднее количество покупок на клиента по аптекам
SELECT
  shop,
  ROUND(AVG(frequency), 2) AS avg_frequency_per_client
FROM (
  SELECT card, shop, COUNT(*) AS frequency
  FROM bonuscheques
  WHERE {{datetime}}
    AND card LIKE '2000%'
    AND card NOT IN ('200200189985', '200200170860', '200200196556')
  GROUP BY card, shop
) t
GROUP BY shop
ORDER BY 2;

--средний чек
SELECT AVG(summ)
FROM bonuscheques
WHERE {{datetime}}
  AND card LIKE '2000%'
  AND card NOT IN ('200200189985', '200200170860', '200200196556');

--средний чек по аптекам
SELECT shop, AVG(summ)
FROM bonuscheques
WHERE {{datetime}}
  AND card LIKE '2000%'
  AND card NOT IN ('200200189985', '200200170860', '200200196556')
GROUP BY shop
ORDER BY 2;

--таблица rfm - среднее
WITH rfm_base AS (
  SELECT
    card,
    ('2022-06-09'::DATE - MAX(datetime)::DATE) AS recency,
    COUNT(*) AS frequency,
    SUM(summ) AS monetary
  FROM bonuscheques
  WHERE {{datetime}}
    AND card LIKE '2000%'
    AND card NOT IN ('2000200189985', '2000200170860', '2000200196556')
  GROUP BY card
),
rfm_scores AS (
  SELECT
    card, recency, frequency, monetary,
    CASE
      WHEN recency <= 30 THEN 3
      WHEN recency <= 90 THEN 2
      ELSE 1
    END AS recency_score,
    CASE
      WHEN frequency >= 7 THEN 3
      WHEN frequency >= 3 THEN 2
      ELSE 1
    END AS frequency_score,
    CASE
      WHEN monetary > 2200 THEN 3
      WHEN monetary > 900 THEN 2
      ELSE 1
    END AS monetary_score
  FROM rfm_base
),
rfm_data AS (
  SELECT
    card, recency, frequency, monetary, recency_score, frequency_score, monetary_score,
    CONCAT(recency_score, frequency_score, monetary_score) AS bisnes_segment,
    CASE
      WHEN (recency_score = 3 AND frequency_score = 3 AND monetary_score = 3) THEN 'vip'
      WHEN (recency_score = 3 AND frequency_score IN (2, 3) AND monetary_score IN (1, 2, 3)) THEN 'развивающиеся'
      WHEN (recency_score = 3 AND frequency_score = 1 AND monetary_score IN (1, 2, 3)) THEN 'новички'
      WHEN (recency_score = 2 AND frequency_score = 3 AND monetary_score IN (1, 2, 3)) THEN 'лояльные спящие'
      WHEN (recency_score = 2 AND frequency_score IN (1, 2) AND monetary_score IN (1, 2, 3)) THEN 'спящие'
      WHEN (recency_score = 1 AND frequency_score IN (2, 3) AND monetary_score IN (1, 2, 3)) THEN 'лояльные, потерявшие активность'
      WHEN (recency_score = 1 AND frequency_score = 1 AND monetary_score IN (1, 2, 3)) THEN 'потерянные'
    END AS customer_segment
  FROM rfm_scores
)
SELECT
  customer_segment AS rfm_сегмент,
  COUNT(*) AS количество_клиентов,
  ROUND(AVG(recency), 1) AS среднее_recency,
  ROUND(AVG(frequency), 1) AS среднее_frequency,
  ROUND(AVG(monetary), 0) AS среднее_monetary,
  ROUND(SUM(monetary), 0) AS выручка
FROM rfm_data
GROUP BY customer_segment
ORDER BY
  CASE customer_segment
    WHEN 'vip' THEN 1
    WHEN 'развивающиеся' THEN 2
    WHEN 'новички' THEN 3
    WHEN 'лояльные спящие' THEN 4
    WHEN 'спящие' THEN 5
    WHEN 'лояльные, потерявшие активность' THEN 6
    WHEN 'потерянные' THEN 7
  END;
