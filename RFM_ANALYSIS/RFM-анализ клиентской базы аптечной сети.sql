--1. Подготовка базовых метрик RFM
--рассчитываем ключевые метрики для каждого клиента:
-- Recency — сколько дней прошло с последней покупки;
-- Frequency — количество покупок;
--Monetary — общая сумма трат.  and card != '2000200189985'
SELECT card,
EXTRACT(DAY FROM '2022-06-09'::timestamp - MAX(datetime)) AS recency,
COUNT(*) AS frequency,
SUM(summ) AS monetary
FROM bonuscheques
WHERE card LIKE '2000%' 
AND card != '2000200189985'
GROUP BY card
ORDER BY Frequency desc, Monetary desc, recency;

--Основные показатели
SELECT 
SUM(summ) AS "Общая выручка",
AVG(summ) AS "Средний чек",
COUNT(DISTINCT card) AS "Общее количество клиентов"
FROM bonuscheques
WHERE card LIKE '2000%'
AND card NOT IN ('2000200189985', '2000200170860', '2000200196556');

-- Шаг 2. Анализ распределения с помощью NTILE(3)
--**Задача:** понять, где находятся «естественные» границы между сегментами, не прибегая к субъективным оценкам.
--AVG-MAX-MIN-PERCENTILE СЕГМЕНТОВ
WITH rfm_base AS (
  SELECT
    card, 
    EXTRACT(DAY FROM '2022-06-09'::timestamp - MAX(datetime)) AS recency,
    COUNT(*) AS frequency,
    SUM(summ) AS monetary
  FROM bonuscheques
  WHERE card LIKE '2000%' and card not in ('2000200189985', '2000200170860', '2000200196556')
  GROUP BY card
),
rfm_stats AS (
  SELECT
    ROUND(PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY recency)::numeric, 2) AS recency_p25,
    ROUND(PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY recency)::numeric, 2) AS recency_p50,
    ROUND(PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY recency)::numeric, 2) AS recency_p75,
    ROUND(AVG(recency)::numeric, 2) AS recency_avg,
    MAX(recency) AS recency_max,
    MIN(recency) AS recency_min,
    ROUND(PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY frequency)::numeric, 2) AS frequency_p25,
    ROUND(PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY frequency)::numeric, 2) AS frequency_p50,
    ROUND(PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY frequency)::numeric, 2) AS frequency_p75,
    ROUND(AVG(frequency)::numeric, 2) AS frequency_avg,
    MAX(frequency) AS frequency_max,
    MIN(frequency) AS frequency_min,
    ROUND(PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY monetary)::numeric, 2) AS monetary_p25,
    ROUND(PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY monetary)::numeric, 2) AS monetary_p50,
    ROUND(PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY monetary)::numeric, 2) AS monetary_p75,
    ROUND(AVG(monetary)::numeric, 2) AS monetary_avg,
    MAX(monetary) AS monetary_max,
    MIN(monetary) AS monetary_min
  FROM rfm_base
),
transposed_data AS (
  SELECT
    'Recency' AS metric,
    1 AS sort_order,
    recency_p25 AS p25,
    recency_p50 AS p50,
    recency_p75 AS p75,
    recency_avg AS average,
    recency_max AS maximum,
    recency_min AS minimum
  FROM rfm_stats
  UNION ALL
  SELECT
    'Frequency' AS metric,
    2 AS sort_order,
    frequency_p25 AS p25,
    frequency_p50 AS p50,
    frequency_p75 AS p75,
    frequency_avg AS average,
    frequency_max AS maximum,
    frequency_min AS minimum
  FROM rfm_stats
  UNION ALL
  SELECT
    'Monetary' AS metric,
    3 AS sort_order,
    monetary_p25 AS p25,
    monetary_p50 AS p50,
    monetary_p75 AS p75,
    monetary_avg AS average,
    monetary_max AS maximum,
    monetary_min AS minimum
  FROM rfm_stats
)
SELECT
  metric,
  p25,
  p50,
  p75,
  average,
  maximum,
  minimum
FROM transposed_data
ORDER BY sort_order;

--recency
WITH rfm_base AS (
  SELECT
    card,
    ('2022-06-09'::DATE - MAX(datetime)::DATE) AS recency
  FROM bonuscheques
  WHERE card LIKE '2000%'
    AND card NOT IN ('2000200189985', '2000200170860', '2000200196556')
  GROUP BY card
),
rfm_scores AS (
  SELECT
    card,
    CASE
      WHEN recency <= 30 THEN 3
      WHEN recency <= 90 THEN 2
      ELSE 1
    END AS recency_score
  FROM rfm_base
)
SELECT
  recency_score,
  COUNT(*) AS customer_count,
  (SELECT COUNT(*) FROM rfm_scores) AS total_customers  -- Общее количество клиентов
FROM rfm_scores
GROUP BY recency_score;

--frequency
WITH rfm_base AS (
  SELECT
    card,
    COUNT(*) AS frequency
  FROM bonuscheques
  WHERE card LIKE '2000%'
    AND card NOT IN ('2000200189985', '2000200170860', '2000200196556')
  GROUP BY card
),
rfm_scores AS (
  SELECT
    card,
    CASE
      WHEN frequency >= 7 THEN 3
      WHEN frequency >= 3 THEN 2
      ELSE 1
    END AS frequency_score
  FROM rfm_base
)
SELECT
  frequency_score,
  COUNT(*) AS customer_count,
  (SELECT COUNT(*) FROM rfm_scores) AS total_customers  -- Общее количество клиентов
FROM rfm_scores
GROUP BY frequency_score;

--АВС-анализ 
WITH rfm_base AS (
  SELECT card AS client, SUM(summ) AS total_revenue
  FROM bonuscheques
  WHERE card LIKE '2000%'
    AND card NOT IN ('2000200189985', '2000200170860', '2000200196556')
  GROUP BY card
),
abc_segmentation AS (
  SELECT
    client,
    total_revenue,
    CASE
      WHEN SUM(total_revenue) OVER (ORDER BY total_revenue DESC) / SUM(total_revenue) OVER () <= 0.8 THEN 'A'
      WHEN SUM(total_revenue) OVER (ORDER BY total_revenue DESC) / SUM(total_revenue) OVER () <= 0.95 THEN 'B'
      ELSE 'C'
    END AS revenue_abc
  FROM rfm_base
),
-- Предварительный расчёт итоговых значений
totals AS (
  SELECT COUNT(*) AS total_client_count, SUM(total_revenue) AS total_revenue_sum
  FROM rfm_base
)
-- Основной запрос
SELECT
  abc.revenue_abc,
  COUNT(abc.client) AS количество_клиентов,
  SUM(abc.total_revenue) AS сумма_выручки,
  ROUND((SUM(abc.total_revenue) * 100.0) / t.total_revenue_sum, 2) AS доля_выручки_процент,
  ROUND((COUNT(abc.client) * 100.0) / t.total_client_count, 2) AS доля_клиентов_процент
FROM abc_segmentation abc
CROSS JOIN totals t
GROUP BY abc.revenue_abc, t.total_client_count, t.total_revenue_sum
ORDER BY
  CASE abc.revenue_abc
    WHEN 'A' THEN 1
    WHEN 'B' THEN 2
    WHEN 'C' THEN 3
  END;
  
--monetary
WITH rfm_base AS (
  SELECT
    card,
     SUM(summ) AS monetary
  FROM bonuscheques
  WHERE card LIKE '2000%'
    AND card NOT IN ('2000200189985', '2000200170860', '2000200196556')
  GROUP BY card
),
rfm_scores AS (
  SELECT
    card,
    CASE
      WHEN monetary > 2200 THEN 3
      WHEN monetary > 900 THEN 2
      ELSE 1
    END AS monetary_score
  FROM rfm_base
)
SELECT
  monetary_score,
  COUNT(*) AS customer_count,
  (SELECT COUNT(*) FROM rfm_scores) AS total_customers  -- Общее количество клиентов
FROM rfm_scores
GROUP BY monetary_score;  

-- Шаг 3. Финальная сегментация с фиксированными порогами
WITH rfm_base AS (
  SELECT
    card,
    ('2022-06-09'::DATE - MAX(datetime)::DATE) AS recency,
    COUNT(*) AS frequency,
    SUM(summ) AS monetary
  FROM bonuscheques
  WHERE card LIKE '2000%'
    AND card NOT IN ('2000200189985', '2000200170860', '2000200196556')
  GROUP BY card
),
rfm_scores AS (
  SELECT
    card,
    recency,
    frequency,
    monetary,
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
)
SELECT
  CASE
    -- Группа 1: Recency = 3 (Высокая активность)
    WHEN recency_score = 3 AND frequency_score = 3 AND monetary_score = 3 THEN 'VIP'
    WHEN recency_score = 3 AND frequency_score = 3 AND monetary_score = 2 THEN 'Постоянные со средним чеком'
    WHEN recency_score = 3 AND frequency_score = 3 AND monetary_score = 1 THEN 'Постоянные с маленьким чеком'
    WHEN recency_score = 3 AND frequency_score = 2 AND monetary_score = 3 THEN 'Постоянные с высоким чеком'
    WHEN recency_score = 3 AND frequency_score = 2 AND monetary_score = 2 THEN 'Постоянные со средним чеком'
    WHEN recency_score = 3 AND frequency_score = 2 AND monetary_score = 1 THEN 'Постоянные с маленьким чеком'
    WHEN recency_score = 3 AND frequency_score = 1 AND monetary_score = 3 THEN 'Новички с высоким чеком. Потенциальные VIP'
    WHEN recency_score = 3 AND frequency_score = 1 AND monetary_score = 2 THEN 'Новички со средним чеком'
    WHEN recency_score = 3 AND frequency_score = 1 AND monetary_score = 1 THEN 'Новички с маленьким чеком'
    -- Группа 2: Recency = 2 (Средняя активность)
    WHEN recency_score = 2 AND frequency_score = 3 AND monetary_score = 3 THEN 'Спящие постоянные с высоким чеком'
    WHEN recency_score = 2 AND frequency_score = 3 AND monetary_score = 2 THEN 'Спящие постоянные со средним чеком'
    WHEN recency_score = 2 AND frequency_score = 3 AND monetary_score = 1 THEN 'Спящие постоянные с маленьким чеком'
    WHEN recency_score = 2 AND frequency_score = 2 AND monetary_score = 3 THEN 'Спящие редкие с высоким чеком'
    WHEN recency_score = 2 AND frequency_score = 2 AND monetary_score = 2 THEN 'Спящие редкие со средним чеком'
    WHEN recency_score = 2 AND frequency_score = 2 AND monetary_score = 1 THEN 'Спящие редкие с маленьким чеком'
    WHEN recency_score = 2 AND frequency_score = 1 AND monetary_score = 3 THEN 'Спящие разовые с высоким чеком'
    WHEN recency_score = 2 AND frequency_score = 1 AND monetary_score = 2 THEN 'Спящие разовые со средним чеком'
    WHEN recency_score = 2 AND frequency_score = 1 AND monetary_score = 1 THEN 'Спящие разовые с маленьким чеком'
    -- Группа 3: Recency = 1 (Низкая активность)
    WHEN recency_score = 1 AND frequency_score = 3 AND monetary_score = 3 THEN 'Уходящие VIP'
    WHEN recency_score = 1 AND frequency_score = 3 AND monetary_score = 2 THEN 'Уходящие хорошие постоянные'
    WHEN recency_score = 1 AND frequency_score = 3 AND monetary_score = 1 THEN 'Уходящие постоянные'
    WHEN recency_score = 1 AND frequency_score = 2 AND monetary_score = 3 THEN 'Уходящие редкие с высоким чеком'
    WHEN recency_score = 1 AND frequency_score = 2 AND monetary_score = 2 THEN 'Уходящие редкие со средним чеком'
    WHEN recency_score = 1 AND frequency_score = 2 AND monetary_score = 1 THEN 'Уходящие редкие с маленьким чеком'
    WHEN recency_score = 1 AND frequency_score = 1 AND monetary_score = 3 THEN 'Одноразовые с высоким чеком'
    WHEN recency_score = 1 AND frequency_score = 1 AND monetary_score = 2 THEN 'Одноразовые со средним чеком'
    WHEN recency_score = 1 AND frequency_score = 1 AND monetary_score = 1 THEN 'Потерянные экономные'
  END AS customer_segment,
  CONCAT(recency_score, frequency_score, monetary_score) AS bisnes_segment,
  COUNT(card) AS количество_клиентов,
  recency_score,
  frequency_score,
  monetary_score
FROM rfm_scores
GROUP BY
  recency_score,
  frequency_score,
  monetary_score,
  customer_segment
ORDER BY
  recency_score DESC,
  frequency_score DESC,
  monetary_score DESC;  
   
--Укрупнение до 7 групп  
WITH rfm_base AS (
  SELECT
    card,
    ('2022-06-09'::DATE - MAX(datetime)::DATE) AS recency,
    COUNT(*) AS frequency,
    SUM(summ) AS monetary
  FROM bonuscheques
  WHERE card LIKE '2000%'
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
      WHEN (recency_score = 3 AND frequency_score = 3 AND monetary_score = 3) THEN 'VIP'
      WHEN (recency_score = 3 AND frequency_score IN (2, 3) AND monetary_score IN (1, 2, 3)) THEN 'Развивающиеся'
      WHEN (recency_score = 3 AND frequency_score = 1 AND monetary_score IN (1, 2, 3)) THEN 'Новички'
      WHEN (recency_score = 2 AND frequency_score = 3 AND monetary_score IN (1, 2, 3)) THEN 'Лояльные спящие'
      WHEN (recency_score = 2 AND frequency_score IN (1, 2) AND monetary_score IN (1, 2, 3)) THEN 'Спящие'
      WHEN (recency_score = 1 AND frequency_score IN (2, 3) AND monetary_score IN (1, 2, 3)) THEN 'Лояльные, потерявшие активность'
      WHEN (recency_score = 1 AND frequency_score = 1 AND monetary_score IN (1, 2, 3)) THEN 'Потерянные'
    END AS customer_segment
  FROM rfm_scores
)
SELECT customer_segment, COUNT(card) AS customer_count
FROM rfm_segments
GROUP BY customer_segment
ORDER BY
CASE customer_segment
    WHEN 'VIP' THEN 1
    WHEN 'Развивающиеся' THEN 2
    WHEN 'Новички' THEN 3
    WHEN 'Лояльные спящие' THEN 4
    WHEN 'Спящие' THEN 5
    WHEN 'Лояльные, потерявшие активность' THEN 6
    WHEN 'Потерянные' THEN 7
  END;
