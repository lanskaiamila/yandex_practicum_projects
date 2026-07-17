/* Проект первого модуля: анализ данных для агентства недвижимости
 * Часть 2. Решаем ad hoc задачи
 * 
 * Автор: Мелания Ланская
 * Дата: 01.05.2026
*/



-- Задача 1: Время активности объявлений
-- Определим аномальные значения (выбросы) по значению перцентилей:
WITH limits AS (
    SELECT
        PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_CONT(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats
),
-- Найдём id объявлений, которые не содержат выбросы, также оставим пропущенные данные:
filtered_id AS(
    SELECT id
    FROM real_estate.flats
    WHERE
        total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
            AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)) OR ceiling_height IS NULL)
    ),
-- Продолжите запрос здесь
-- Используйте id объявлений (СТЕ filtered_id), которые не содержат выбросы при анализе данных
needed_data AS (
    SELECT a.id,
        a.days_exposition,
        a.last_price,
        f.total_area,
        f.rooms,
        f.balcony,
        f.floor,
        a.last_price / f.total_area AS price_per_m2,
        CASE
    		WHEN f.city_id = '6X8I' THEN 'Санкт-Петербург'
    		ELSE 'ЛенОбл'
		END AS region,
        CASE
            WHEN a.days_exposition IS NULL THEN 'non category'
            WHEN a.days_exposition <= 30 THEN '1-30 days'
            WHEN a.days_exposition <= 90 THEN '31-90 days'
            WHEN a.days_exposition <= 180 THEN '91-180 days'
            ELSE '181+ days'
        END AS exposure_group
    FROM real_estate.advertisement a
    JOIN real_estate.flats f USING(id)
    JOIN real_estate.type t USING(type_id)
    JOIN filtered_id fi USING(id)
    WHERE t.type = 'город'
    	AND EXTRACT(YEAR FROM a.first_day_exposition) BETWEEN 2015 AND 2018
)

SELECT region,
    exposure_group,
    COUNT(*) AS total_ads,
	ROUND(COUNT(*)::numeric / SUM(COUNT(*)) OVER (PARTITION BY region) * 100, 2) AS ads_share,
    ROUND(AVG(price_per_m2)::numeric, 2) AS avg_price_per_m2,
    ROUND(AVG(total_area)::numeric, 2) AS avg_total_area,
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY rooms) AS median_rooms,
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY balcony) AS median_balcony,
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY floor) AS median_floor
FROM needed_data
GROUP BY region, exposure_group;


-- Задача 2: Сезонность объявлений
-- Определим аномальные значения (выбросы) по значению перцентилей:
WITH limits AS (
    SELECT
        PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_CONT(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats
),
-- Найдём id объявлений, которые не содержат выбросы, также оставим пропущенные данные:
filtered_id AS(
    SELECT id
    FROM real_estate.flats
    WHERE
        total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
            AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)) OR ceiling_height IS NULL)
    ),
-- Продолжите запрос здесь
-- Используйте id объявлений (СТЕ filtered_id), которые не содержат выбросы при анализе данных
needed_data AS (
    SELECT a.id,
        EXTRACT(MONTH FROM a.first_day_exposition)::int AS publication_month,
        EXTRACT(MONTH FROM a.first_day_exposition + a.days_exposition::int)::int AS removal_month,
        a.last_price / f.total_area AS price_per_m2,
        f.total_area
    FROM real_estate.advertisement AS a
    JOIN real_estate.flats AS f USING(id)
    JOIN real_estate.type AS t USING(type_id)
    JOIN filtered_id AS fi USING(id)
    WHERE t.type = 'город'
    	AND EXTRACT(YEAR FROM a.first_day_exposition) BETWEEN 2015 AND 2018
    	AND (
    		a.days_exposition IS NULL
    		OR EXTRACT(YEAR FROM a.first_day_exposition + a.days_exposition::int) BETWEEN 2015 AND 2018
		)
),

publication_stats AS (
    SELECT publication_month AS month,
        COUNT(id) AS publication_count,
        ROUND(AVG(price_per_m2)::numeric, 2) AS publication_avg_price_m2,
        ROUND(AVG(total_area)::numeric, 2) AS publication_avg_area
    FROM needed_data
    GROUP BY publication_month
),

removal_stats AS (
    SELECT removal_month AS month,
        COUNT(id) AS removal_count,
        ROUND(AVG(price_per_m2)::numeric, 2) AS removal_avg_price_m2,
        ROUND(AVG(total_area)::numeric, 2) AS removal_avg_area
    FROM needed_data
    WHERE removal_month IS NOT NULL
    GROUP BY removal_month
)

SELECT COALESCE(p.month, r.month) AS month,
    p.publication_count,
    r.removal_count,
    p.publication_avg_price_m2,
    r.removal_avg_price_m2,
    p.publication_avg_area,
    r.removal_avg_area
FROM publication_stats AS p
FULL JOIN removal_stats AS r
    ON p.month = r.month
ORDER BY month;