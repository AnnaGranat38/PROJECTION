--ABC анализ 
-- расчёт выручки и количества по продуктам
WITH product_revenue AS (
  SELECT
    DR_CDrugs AS product_id,          
    DR_NDrugs AS product_name,        
    SUM(DR_Kol * DR_CRoz) AS total_revenue,  
    SUM(DR_Kol) AS total_quantity     
  FROM sales                           
  GROUP BY DR_CDrugs, DR_NDrugs   
),
--расчёт накопительных показателей для ABC сегментации
abc_segmentation AS (
  SELECT
    product_id,                      
    product_name,                   
    total_revenue,                 
    total_quantity,               
    SUM(total_revenue) OVER (ORDER BY total_revenue DESC) AS cumulative_revenue,
    -- Накопительная выручка: суммируется по убыванию выручки 
    SUM(total_revenue) OVER () AS total_sum
    -- Общая сумма выручки по всем продуктам 
  FROM product_revenue               -
)
--ABC группы
SELECT
  product_id,                     
  product_name,                  
  total_revenue,                 
  total_quantity,                
  ROUND(CAST(cumulative_revenue * 1.0 / total_sum AS numeric), 4) AS cumulative_percentage,
  -- Расчёт накопительного процента
  CASE
    WHEN cumulative_revenue / total_sum <= 0.8 THEN 'A'  -- Группа A: до 80 % накопительной выручки
    WHEN cumulative_revenue / total_sum <= 0.95 THEN 'B' -- Группа B: от 80 % до 95 % накопительной выручки
    ELSE 'C'                                                  -- Группа C: оставшиеся продукты (свыше 95 %)
  END AS abc_group                  
FROM abc_segmentation             
ORDER BY total_revenue DESC;      


-- XYZ анализ стабильности продаж
WITH monthly_product_sales AS (
  --агрегация продаж по товарам и месяцам
  --Цель: получить суммарные продажи каждого товара за каждый месяц
  SELECT
    DR_CDrugs AS product_id,
    DATE_TRUNC('month', DR_Dat) AS month,
    SUM(DR_Kol) AS monthly_quantity
  FROM sales
  GROUP BY DR_CDrugs, DATE_TRUNC('month', DR_Dat)),
product_variation AS (
  --расчёт статистических показателей для каждого товара
  --Цель: вычислить среднее количество продаж и стандартное отклонение по месяцам
  --Эти данные нужны для расчёта коэффициента вариации в основном запросе
  SELECT
    product_id,
    AVG(monthly_quantity) AS avg_monthly_quantity,
    STDDEV(monthly_quantity) AS stddev_monthly_quantity
  FROM monthly_product_sales
  GROUP BY product_id)
SELECT
  product_id,
  avg_monthly_quantity,
  stddev_monthly_quantity,
  CASE
    WHEN avg_monthly_quantity = 0 THEN 0
    ELSE stddev_monthly_quantity / avg_monthly_quantity
  END AS coefficient_of_variation,
  CASE
    WHEN avg_monthly_quantity = 0 THEN 'X'
    WHEN (stddev_monthly_quantity / avg_monthly_quantity) < 0.1 THEN 'X'
    WHEN (stddev_monthly_quantity / avg_monthly_quantity) < 0.25 THEN 'Y'
    ELSE 'Z'
  END AS xyz_group
FROM product_variation
ORDER BY coefficient_of_variation;


-- ABC-XYZ анализ
WITH abc_data AS (
  WITH product_revenue AS (
    SELECT
      DR_CDrugs AS product_id,
      DR_NDrugs AS product_name,
      SUM(DR_Kol * DR_CRoz) AS total_revenue,
      SUM(DR_Kol) AS total_quantity
    FROM sales
    GROUP BY DR_CDrugs, DR_NDrugs
  ),
  abc_segmentation AS (
    SELECT
      product_id,
      product_name,
      total_revenue,
      total_quantity,
      SUM(total_revenue) OVER (ORDER BY total_revenue DESC) AS cumulative_revenue,
      SUM(total_revenue) OVER () AS total_sum
    FROM product_revenue
  )
  SELECT
    product_id,
    product_name,
    total_revenue,
    total_quantity,
    ROUND((cumulative_revenue / total_sum)::NUMERIC, 4) AS cumulative_percentage,  
    CASE
      WHEN cumulative_revenue / total_sum <= 0.8 THEN 'A'
      WHEN cumulative_revenue / total_sum <= 0.95 THEN 'B'
      ELSE 'C'
    END AS abc_group
  FROM abc_segmentation
  ORDER BY total_revenue DESC
),
xyz_data AS (
  WITH monthly_product_sales AS (
    SELECT
      DR_CDrugs AS product_id,
      DATE_TRUNC('month', DR_Dat) AS month,
      SUM(DR_Kol) AS monthly_quantity
    FROM sales
    GROUP BY DR_CDrugs, DATE_TRUNC('month', DR_Dat)
  ),
  product_variation AS (
    SELECT
      product_id,
      AVG(monthly_quantity) AS avg_monthly_quantity,
      STDDEV(monthly_quantity) AS stddev_monthly_quantity
    FROM monthly_product_sales
    GROUP BY product_id
  )
  SELECT
    product_id,
    avg_monthly_quantity,
    stddev_monthly_quantity,
    CASE
      WHEN avg_monthly_quantity = 0 THEN 0
      ELSE stddev_monthly_quantity / avg_monthly_quantity
    END AS coefficient_of_variation,
    CASE
      WHEN avg_monthly_quantity = 0 THEN 'X'
      WHEN (stddev_monthly_quantity / avg_monthly_quantity) < 0.1 THEN 'X'
      WHEN (stddev_monthly_quantity / avg_monthly_quantity) < 0.25 THEN 'Y'
      ELSE 'Z'
    END AS xyz_group
  FROM product_variation
  ORDER BY coefficient_of_variation
)
SELECT
  a.product_id,
  a.product_name,
  a.total_revenue,
  a.total_quantity,
  a.abc_group,
  x.xyz_group,
  a.abc_group || '_' || x.xyz_group AS abc_xyz_segment
FROM abc_data a
JOIN xyz_data x ON a.product_id = x.product_id
ORDER BY a.total_revenue DESC;

-- Агрегированная статистика по сегментам
WITH combined_analysis AS (
  WITH abc_data AS (
    WITH product_revenue AS (
      SELECT
        DR_CDrugs AS product_id,
        DR_NDrugs AS product_name,
        SUM(DR_Kol * DR_CRoz) AS total_revenue,
        SUM(DR_Kol) AS total_quantity
      FROM sales
      GROUP BY DR_CDrugs, DR_NDrugs
    ),
    abc_segmentation AS (
      SELECT
        product_id,
        product_name,
        total_revenue,
        total_quantity,
        SUM(total_revenue) OVER (ORDER BY total_revenue DESC) AS cumulative_revenue,
        SUM(total_revenue) OVER () AS total_sum
      FROM product_revenue
    )
    SELECT
      product_id,
      product_name,
      total_revenue,
      total_quantity,
      ROUND((cumulative_revenue / total_sum)::NUMERIC, 4) AS cumulative_percentage,
      CASE
        WHEN cumulative_revenue / total_sum <= 0.8 THEN 'A'
        WHEN cumulative_revenue / total_sum <= 0.95 THEN 'B'
        ELSE 'C'
      END AS abc_group
    FROM abc_segmentation
    ORDER BY total_revenue DESC
  ),
  xyz_data AS (
    WITH monthly_product_sales AS (
      SELECT
        DR_CDrugs AS product_id,
        DATE_TRUNC('month', DR_Dat) AS month,
        SUM(DR_Kol) AS monthly_quantity
      FROM sales
      GROUP BY DR_CDrugs, DATE_TRUNC('month', DR_Dat)
    ),
    product_variation AS (
      SELECT
        product_id,
        AVG(monthly_quantity) AS avg_monthly_quantity,
        STDDEV(monthly_quantity) AS stddev_monthly_quantity
      FROM monthly_product_sales
      GROUP BY product_id
    )
    SELECT
      product_id,
      avg_monthly_quantity,
      stddev_monthly_quantity,
      CASE
        WHEN avg_monthly_quantity = 0 THEN 0
        ELSE stddev_monthly_quantity / avg_monthly_quantity
      END AS coefficient_of_variation,
      CASE
        WHEN avg_monthly_quantity = 0 THEN 'X'
        WHEN (stddev_monthly_quantity / avg_monthly_quantity) < 0.1 THEN 'X'
        WHEN (stddev_monthly_quantity / avg_monthly_quantity) < 0.25 THEN 'Y'
        ELSE 'Z'
      END AS xyz_group
    FROM product_variation
    ORDER BY coefficient_of_variation
  )
  SELECT
    a.product_id,
    a.product_name,
    a.total_revenue,
    a.total_quantity,
    a.abc_group,
    x.xyz_group,
    a.abc_group || '_' || x.xyz_group AS abc_xyz_segment
  FROM abc_data a
  JOIN xyz_data x ON a.product_id = x.product_id
  ORDER BY a.total_revenue DESC
)
SELECT
  abc_xyz_segment,
  COUNT(product_id) AS product_count,
  ROUND(AVG(total_revenue)::NUMERIC, 2) AS avg_revenue_per_product,  
  ROUND(SUM(total_revenue)::NUMERIC, 2) AS total_segment_revenue,  
  ROUND(SUM(total_quantity)::NUMERIC, 0) AS total_quantity_sold  
FROM combined_analysis
GROUP BY abc_xyz_segment
ORDER BY
  CASE abc_xyz_segment
    WHEN 'AX' THEN 1
    WHEN 'AY' THEN 2
    WHEN 'AZ' THEN 3
    WHEN 'BX' THEN 4
    WHEN 'BY' THEN 5
    WHEN 'BZ' THEN 6
    WHEN 'CX' THEN 7
    WHEN 'CY' THEN 8
    WHEN 'CZ' THEN 9
  END;

 