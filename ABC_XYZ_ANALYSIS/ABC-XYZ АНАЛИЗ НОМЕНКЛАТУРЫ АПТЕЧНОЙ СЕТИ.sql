--Общее количество уникальных товаров
SELECT
  COUNT(DISTINCT DR_CDrugs) AS unique_products
FROM
  sales
   WHERE {{DR_Dat}} 
   AND  {{DR_apt}};

--Общая выручка от продаж
SELECT ROUND(SUM(DR_Kol * DR_CRoz)::NUMERIC, 0) AS total_sales_revenue 
FROM sales
 WHERE {{DR_Dat}} 
   AND  {{DR_apt}};

--Доля топ‑20 % товаров в выручке
WITH top_products AS (
  SELECT
    DR_CDrugs,
    SUM(DR_Kol * DR_CRoz) AS revenue
  FROM sales
   WHERE {{DR_Dat}} 
   AND  {{DR_apt}}
  GROUP BY DR_CDrugs
  ORDER BY revenue DESC
  LIMIT (SELECT (COUNT(DISTINCT DR_CDrugs) * 0.2)::INTEGER FROM sales)  -- Приведение к INTEGER для LIMIT
)
SELECT
  ROUND(
    (SUM(revenue) * 100.0 /
     (SELECT SUM(DR_Kol * DR_CRoz) FROM sales)
    )::NUMERIC,
    2
  ) AS pareto_index
FROM top_products;

--Средний объём продаж на товар
SELECT ROUND(AVG(total_quantity)::INTEGER, 2) AS avg_sales_per_product
    FROM (
      SELECT DR_CDrugs, SUM(DR_Kol) AS total_quantity
      FROM sales
      WHERE {{DR_Dat}} AND  {{DR_apt}}
      GROUP BY DR_CDrugs
    ) t;

--Распределение выручки по группам ABC
WITH abc_data AS (
      WITH product_revenue AS (
  SELECT
    DR_CDrugs AS product_id,
    DR_NDrugs AS product_name,
    SUM(DR_Kol * DR_CRoz) AS total_revenue,
    SUM(DR_Kol) AS total_quantity
  FROM sales
  WHERE {{DR_Dat}} AND  {{DR_apt}}
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
  ROUND(CAST(cumulative_revenue * 1.0 / total_sum AS numeric), 4) AS cumulative_percentage,
  CASE
    WHEN cumulative_revenue / total_sum <= 0.8 THEN 'A'
    WHEN cumulative_revenue / total_sum <= 0.95 THEN 'B'
    ELSE 'C'
  END AS abc_group
FROM abc_segmentation
ORDER BY total_revenue DESC
    )
    SELECT abc_group, SUM(total_revenue) AS revenue_by_group
    FROM abc_data
    GROUP BY abc_group;

--Распределение количества товаров по группам ABC
WITH abc_data AS (
      WITH product_revenue AS (
  SELECT
    DR_CDrugs AS product_id,
    DR_NDrugs AS product_name,
    SUM(DR_Kol * DR_CRoz) AS total_revenue,
    SUM(DR_Kol) AS total_quantity
  FROM sales
  WHERE {{DR_Dat}} AND  {{DR_apt}}
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
  ROUND(CAST(cumulative_revenue * 1.0 / total_sum AS numeric), 4) AS cumulative_percentage,
  CASE
    WHEN cumulative_revenue / total_sum <= 0.8 THEN 'A'
    WHEN cumulative_revenue / total_sum <= 0.95 THEN 'B'
    ELSE 'C'
  END AS abc_group
FROM abc_segmentation
ORDER BY total_revenue DESC
    )
    SELECT abc_group, COUNT(*) AS product_count
    FROM abc_data
    GROUP BY abc_group;

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
      WHERE {{DR_Dat}} AND  {{DR_apt}}
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
    a.product_id AS "Код товара",
    a.product_name AS "Название товара",
    a.total_revenue AS "Общая выручка",
    a.total_quantity AS "Общее количество",
    a.abc_group AS "ABC‑группа",
    x.xyz_group AS "XYZ‑группа",
    a.abc_group || '_' || x.xyz_group AS "ABC_XYZ‑сегмент"
  FROM abc_data a
  JOIN xyz_data x ON a.product_id = x.product_id
  ORDER BY a.total_revenue DESC
)
SELECT
  "ABC_XYZ‑сегмент" AS "Сегмент ABC‑XYZ",
  COUNT("Код товара") AS "Количество товаров в сегменте",
  ROUND(AVG("Общая выручка")::NUMERIC, 2) AS "Средняя выручка на товар",
  ROUND(SUM("Общая выручка")::NUMERIC, 2) AS "Общая выручка сегмента",
  ROUND(SUM("Общее количество")::NUMERIC, 0) AS "Общее количество проданного"
FROM combined_analysis
GROUP BY "ABC_XYZ‑сегмент"
ORDER BY
  CASE "ABC_XYZ‑сегмент"
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

-- Матрица с количеством товаров и долей выручки
WITH combined_analysis AS (
  WITH abc_data AS (
    WITH product_revenue AS (
      SELECT
        DR_CDrugs AS product_id,
        DR_NDrugs AS product_name,
        SUM(DR_Kol * DR_CRoz) AS total_revenue,
        SUM(DR_Kol) AS total_quantity
      FROM sales
      WHERE {{DR_Dat}} AND  {{DR_apt}}
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
  COUNT(*) AS product_count,
  ROUND(
    (SUM(total_revenue) * 100.0 /
     (SELECT SUM(total_revenue) FROM combined_analysis)
    )::NUMERIC,
    2
  ) AS revenue_percentage  -- Исправлено: приведение к NUMERIC
FROM combined_analysis
GROUP BY abc_xyz_segment;

--Выручка по сегментам ABC XYZ
WITH segment_revenue AS (
      WITH combined_analysis AS (
  WITH abc_data AS (
    WITH product_revenue AS (
      SELECT
        DR_CDrugs AS product_id,
        DR_NDrugs AS product_name,
        SUM(DR_Kol * DR_CRoz) AS total_revenue,
        SUM(DR_Kol) AS total_quantity
      FROM sales
      WHERE {{DR_Dat}} AND  {{DR_apt}}
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
  ROUND(AVG(total_revenue)::NUMERIC, 2) AS avg_revenue_per_product,  -- Исправлено: приведение к NUMERIC
  ROUND(SUM(total_revenue)::NUMERIC, 2) AS total_segment_revenue,  -- Исправлено: приведение к NUMERIC
  ROUND(SUM(total_quantity)::NUMERIC, 0) AS total_quantity_sold  -- Исправлено: приведение к NUMERIC
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
  END
    )
    SELECT abc_xyz_segment, total_segment_revenue
    FROM segment_revenue;

--Количество проданных единиц
WITH segment_quantity AS (
      WITH combined_analysis AS (
  WITH abc_data AS (
    WITH product_revenue AS (
      SELECT
        DR_CDrugs AS product_id,
        DR_NDrugs AS product_name,
        SUM(DR_Kol * DR_CRoz) AS total_revenue,
        SUM(DR_Kol) AS total_quantity
      FROM sales
      WHERE {{DR_Dat}} AND  {{DR_apt}}
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
  ROUND(AVG(total_revenue)::NUMERIC, 2) AS avg_revenue_per_product,  -- Исправлено: приведение к NUMERIC
  ROUND(SUM(total_revenue)::NUMERIC, 2) AS total_segment_revenue,  -- Исправлено: приведение к NUMERIC
  ROUND(SUM(total_quantity)::NUMERIC, 0) AS total_quantity_sold  -- Исправлено: приведение к NUMERIC
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
  END
    )
    SELECT abc_xyz_segment, total_quantity_sold
    FROM segment_quantity;

--Маржинальность по сегментам ABC XYZ
WITH combined_analysis AS (
  WITH abc_data AS (
    WITH product_revenue AS (
      SELECT
        DR_CDrugs AS product_id,
        DR_NDrugs AS product_name,
        SUM(DR_Kol * DR_CRoz) AS total_revenue,
        SUM(DR_Kol) AS total_quantity
      FROM sales
      WHERE {{DR_Dat}} AND  {{DR_apt}}
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
),
product_margin AS (
  SELECT
    DR_CDrugs AS product_id,
    AVG(DR_CRoz - DR_CZak) AS avg_margin_per_unit,
    SUM(DR_Kol * (DR_CRoz - DR_CZak)) AS total_margin
  FROM sales
  GROUP BY DR_CDrugs
)
SELECT
  c.abc_xyz_segment AS "Сегмент ABC-XYZ",
  ROUND(AVG(m.avg_margin_per_unit)::NUMERIC, 2) AS "Средняя маржинальность",  
  ROUND(SUM(m.total_margin)::NUMERIC, 2) AS "Маржинальность сегманта"  
FROM combined_analysis c
JOIN product_margin m ON c.product_id = m.product_id
GROUP BY c.abc_xyz_segment
ORDER BY 3 DESC;

--Динамика выручки по группам ABC
WITH product_abc AS (
  WITH product_revenue AS (
    SELECT
      DR_CDrugs AS product_id,
      DR_NDrugs AS product_name,
      SUM(DR_Kol * DR_CRoz) AS total_revenue,
      SUM(DR_Kol) AS total_quantity
    FROM sales
    WHERE  {{DR_Dat}} AND  {{DR_apt}}
      AND DR_Dat >= '2022-05-01'::DATE
      AND DR_Dat <= '2022-06-09'::DATE
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
    ROUND(CAST(cumulative_revenue * 1.0 / total_sum AS numeric), 4) AS cumulative_percentage,
    CASE
      WHEN cumulative_revenue / total_sum <= 0.8 THEN 'A'
      WHEN cumulative_revenue / total_sum <= 0.95 THEN 'B'
      ELSE 'C'
    END AS abc_group
  FROM abc_segmentation
  ORDER BY total_revenue DESC
),
weekly_product_revenue AS (
  SELECT
    DATE_TRUNC('week', s.DR_Dat)::DATE AS week_start,
    s.DR_CDrugs AS product_id,
    SUM(s.DR_Kol * s.DR_CRoz) AS weekly_revenue
  FROM sales s
  WHERE s.DR_Dat >= '2022-05-01'::DATE
    AND s.DR_Dat <= '2022-06-09'::DATE
  GROUP BY DATE_TRUNC('week', s.DR_Dat), s.DR_CDrugs
)
SELECT
  TO_CHAR(w.week_start, 'DD.MM.YYYY') || ' — ' ||
  TO_CHAR(
    LEAST(w.week_start + INTERVAL '6 days', '2026-09-06'::DATE),
    'DD.MM.YYYY'
  ) AS "Период недели",
  COALESCE(p.abc_group, 'Не определена') AS "Группа ABC",
  SUM(w.weekly_revenue) AS "Выручка"
FROM weekly_product_revenue w
LEFT JOIN product_abc p ON w.product_id = p.product_id
GROUP BY w.week_start, p.abc_group
ORDER BY w.week_start, p.abc_group;

-- Динамика количества проданных единиц по группам ABC
WITH product_abc AS (
  WITH product_revenue AS (
    SELECT
      DR_CDrugs AS product_id,
      DR_NDrugs AS product_name,
      SUM(DR_Kol * DR_CRoz) AS total_revenue,
      SUM(DR_Kol) AS total_quantity
    FROM sales
    WHERE {{DR_Dat}} AND {{DR_apt}} 
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
    ROUND(CAST(cumulative_revenue * 1.0 / total_sum AS numeric), 4) AS cumulative_percentage,
    CASE
      WHEN cumulative_revenue / total_sum <= 0.8 THEN 'A'
      WHEN cumulative_revenue / total_sum <= 0.95 THEN 'B'
      ELSE 'C'
    END AS abc_group
  FROM abc_segmentation
  ORDER BY total_revenue DESC
),
weekly_product_quantity AS (
  SELECT
    DATE_TRUNC('week', s.DR_Dat)::DATE AS week_start,
    s.DR_CDrugs AS product_id,
    SUM(s.DR_Kol) AS weekly_quantity
  FROM sales s
  WHERE {{DR_Dat}} AND {{DR_apt}}  
  GROUP BY DATE_TRUNC('week', s.DR_Dat), s.DR_CDrugs
)
SELECT
  TO_CHAR(w.week_start, 'DD.MM.YYYY') || ' — ' ||
  TO_CHAR(
    LEAST(w.week_start + INTERVAL '6 days',
      (SELECT MAX(DR_Dat) FROM sales WHERE {{DR_Dat}} AND {{DR_apt}})::DATE
    ),
    'DD.MM.YYYY'
  ) AS "Период недели",
  COALESCE(p.abc_group, 'Не определена') AS "Группа ABC",
  SUM(w.weekly_quantity) AS "Количество проданных единиц"
FROM weekly_product_quantity w
LEFT JOIN product_abc p ON w.product_id = p.product_id
GROUP BY w.week_start, p.abc_group
ORDER BY w.week_start, p.abc_group;

-- Топ‑10 товаров группы A
WITH abc_data AS (
  WITH product_revenue AS (
    SELECT
      DR_CDrugs,
      SUM(DR_Kol * DR_CRoz) AS total_revenue,
      SUM(DR_Kol) AS total_quantity
    FROM sales
    WHERE {{DR_Dat}} AND  {{DR_apt}}
    GROUP BY DR_CDrugs
  ),
  abc_segmentation AS (
    SELECT
      DR_CDrugs,
      total_revenue,
      total_quantity,
      SUM(total_revenue) OVER (ORDER BY total_revenue DESC) AS cumulative_revenue,
      SUM(total_revenue) OVER () AS total_sum
    FROM product_revenue
  )
  SELECT
    DR_CDrugs,
    total_revenue,
    total_quantity,
    ROUND(CAST(cumulative_revenue * 1.0 / total_sum AS numeric), 4) AS cumulative_percentage,
    CASE
      WHEN cumulative_revenue / total_sum <= 0.8 THEN 'A'
      WHEN cumulative_revenue / total_sum <= 0.95 THEN 'B'
      ELSE 'C'
    END AS abc_group
  FROM abc_segmentation
  ORDER BY total_revenue DESC
)
SELECT
  DR_CDrugs,
  ROUND(total_revenue::NUMERIC, 0)
  total_quantity,
  ROUND((total_revenue / total_quantity)::NUMERIC, 2) AS avg_price_per_unit  -- Исправлено: приведение к NUMERIC
FROM abc_data
WHERE abc_group = 'A'
ORDER BY total_revenue DESC
LIMIT 10;

--10 cамых не популярных товаров группы Z
WITH monthly_product_sales AS (
  SELECT
    DR_CDrugs AS product_id,
    DATE_TRUNC('month', DR_Dat) AS month,
    SUM(DR_Kol) AS monthly_quantity
  FROM sales
  WHERE {{DR_Dat}} AND  {{DR_apt}}
  GROUP BY DR_CDrugs, DATE_TRUNC('month', DR_Dat)
),
product_variation AS (
  SELECT
    product_id,
    AVG(monthly_quantity) AS avg_monthly_quantity,
    COALESCE(STDDEV(monthly_quantity), 0) AS stddev_monthly_quantity
  FROM monthly_product_sales
  GROUP BY product_id
),
xyz_data AS (
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
)
SELECT
  x.product_id AS "Id товара",
  x.xyz_group AS "XYZ группа",
  x.avg_monthly_quantity AS "Среднее кол-во в месяц",
  ROUND(x.coefficient_of_variation::NUMERIC, 4) AS "Коэффициент вариации"
FROM xyz_data x
WHERE x.xyz_group = 'Z'
ORDER BY x.coefficient_of_variation DESC
LIMIT 10;
