-- ####################################################################################
-- PROJECT   : LOGISTICS DATABASE ANALYSIS
-- Author    : Ayomide Folorunsho
-- Database  : PostgreSQL (logistics)
-- Description: End-to-end SQL analysis of a logistics company covering driver
--              performance, route profitability, fleet utilization, maintenance,
--              fuel efficiency, customer analysis, safety metrics, and seasonal patterns.
-- ####################################################################################



-- ====================================================================================
-- SECTION 1: DRIVER PERFORMANCE ANALYSIS
-- Description: Evaluating drivers based on reliability, fuel efficiency, and revenue.
-- Tables Used: drivers (drv), driver_monthly_metrics (dmm)
-- Metrics:
--        1: Weighted On-Time Delivery Rate
--        2: Overall Miles Per Gallon (MPG)
--        3: Revenue Per Mile
-- ====================================================================================

SELECT
    drv.driver_id,
    CONCAT(drv.first_name, ' ', drv.last_name)                  AS driver_name,
    ROUND(SUM(dmm.trips_completed * dmm.on_time_delivery_rate)
          / NULLIF(SUM(dmm.trips_completed), 0), 4)             AS overall_on_time_rate,
    ROUND(SUM(dmm.total_miles)
          / NULLIF(SUM(dmm.total_fuel_gallons), 0), 4)          AS overall_mpg,
    ROUND(SUM(dmm.total_revenue)
          / NULLIF(SUM(dmm.total_miles), 0), 4)                 AS revenue_per_mile
FROM drivers AS drv
LEFT JOIN driver_monthly_metrics AS dmm
    ON drv.driver_id = dmm.driver_id
GROUP BY
    drv.driver_id,
    CONCAT(drv.first_name, ' ', drv.last_name)
ORDER BY overall_on_time_rate DESC NULLS LAST;


-- ====================================================================================
-- SECTION 2: ROUTE PROFITABILITY ANALYSIS
-- Description: Evaluating lane margins by comparing customer revenue vs operational
--              expenses (fuel cost) to identify the most and least profitable routes.
-- Tables Used: routes (rte), loads (ld), trips (trp), fuel_purchases (fp)
-- ====================================================================================

SELECT
    rte.route_id,
    CONCAT(rte.origin_city, ' to ', rte.destination_city)                   AS lane_name,
    rte.typical_distance_miles                                              AS distance_in_miles,
    ROUND(SUM(ld.revenue + ld.fuel_surcharge + ld.accessorial_charges), 2)  AS total_revenue,
    ROUND(SUM(trp.fuel_gallons_used * fp.price_per_gallon), 2)              AS total_fuel_cost,
    ROUND(SUM(ld.revenue + ld.fuel_surcharge + ld.accessorial_charges)
          - SUM(trp.fuel_gallons_used * fp.price_per_gallon), 2)            AS gross_revenue_after_fuel,
    ROUND(
        (SUM(ld.revenue + ld.fuel_surcharge + ld.accessorial_charges)
         - SUM(trp.fuel_gallons_used * fp.price_per_gallon))
        / NULLIF(SUM(ld.revenue + ld.fuel_surcharge + ld.accessorial_charges), 0)
        * 100, 2)                                                           AS fuel_cost_as_pct_of_revenue
FROM routes AS rte
LEFT JOIN loads AS ld
    ON rte.route_id = ld.route_id
LEFT JOIN trips AS trp
    ON ld.load_id = trp.load_id
LEFT JOIN fuel_purchases AS fp
    ON trp.trip_id = fp.trip_id
GROUP BY
    rte.route_id,
    CONCAT(rte.origin_city, ' to ', rte.destination_city),
    rte.typical_distance_miles
ORDER BY gross_revenue_after_fuel DESC;


-- ====================================================================================
-- SECTION 3: FLEET UTILIZATION ANALYSIS
-- Description: Evaluating physical and financial asset performance to identify
--              under-utilised trucks and maximise fleet ROI.
-- Tables Used: trucks (trk), truck_utilization_metrics (tum)
-- ====================================================================================

SELECT
    trk.truck_id,
    CONCAT(trk.model_year, ' / ', trk.make, ' - ', trk.unit_number) AS truck_name,
    trk.home_terminal,
    ROUND(SUM(tum.total_miles), 2)                                  AS total_miles_per_truck,
    ROUND(SUM(tum.total_revenue), 2)                                AS total_revenue_per_truck,
    ROUND(SUM(tum.total_revenue)
          / NULLIF(SUM(tum.total_miles), 0), 4)                     AS revenue_per_mile
FROM trucks AS trk
LEFT JOIN truck_utilization_metrics AS tum
    ON trk.truck_id = tum.truck_id
GROUP BY
    trk.truck_id,
    CONCAT(trk.model_year, ' / ', trk.make, ' - ', trk.unit_number),
    trk.home_terminal
ORDER BY total_miles_per_truck DESC NULLS LAST;


-- ====================================================================================
-- SECTION 4: MAINTENANCE ANALYSIS
-- Description: Evaluating asset reliability by analysing maintenance costs per mile
--              and the operational revenue impact of truck downtime.
-- Tables Used: trucks (trk), maintenance_records (mr), truck_utilization_metrics (tum)
-- ====================================================================================

SELECT
    trk.truck_id,
    CONCAT(trk.model_year, ' / ', trk.make, ' - ', trk.unit_number) AS truck_name,
    ROUND(SUM(mr.total_cost), 2)                                    AS total_maintenance_cost,
    ROUND(SUM(mr.total_cost)
          / NULLIF(SUM(tum.total_miles), 0), 4)                     AS cost_per_mile,
    ROUND(SUM(mr.downtime_hours), 2)                                AS total_downtime_hours,
    COUNT(mr.maintenance_id)                                        AS maintenance_events
FROM trucks AS trk
LEFT JOIN maintenance_records AS mr
    ON trk.truck_id = mr.truck_id
LEFT JOIN truck_utilization_metrics AS tum
    ON trk.truck_id = tum.truck_id
GROUP BY
    trk.truck_id,
    CONCAT(trk.model_year, ' / ', trk.make, ' - ', trk.unit_number)
ORDER BY total_maintenance_cost DESC NULLS LAST;


-- ====================================================================================
-- SECTION 5: FUEL EFFICIENCY ANALYSIS
-- Description: Tracking monthly fleet MPG trends to isolate fuel waste and
--              aggregating total fuel expenditure by route.
-- Tables Used: truck_utilization_metrics (tum), routes (rte),
--              loads (ld), trips (trp), fuel_purchases (fp)
-- ====================================================================================

-- ------------------------------------------------------------------------------------
-- Query 5a: Monthly fleet MPG trend
-- ------------------------------------------------------------------------------------

SELECT
    TO_CHAR(tum.month, 'MM - YYYY') AS month,
    ROUND(AVG(tum.average_mpg), 4)  AS monthly_average_mpg
FROM truck_utilization_metrics AS tum
GROUP BY tum.month
ORDER BY tum.month;

-- ------------------------------------------------------------------------------------
-- Query 5b: Fuel cost by route
-- ------------------------------------------------------------------------------------

SELECT
    rte.route_id,
    CONCAT(rte.origin_city, ' to ', rte.destination_city) AS lane_name,
    rte.typical_distance_miles                            AS distance_in_miles,
    ROUND(AVG(fp.total_cost), 2)                          AS average_fuel_cost,
    ROUND(AVG(fp.total_cost)
          / NULLIF(rte.typical_distance_miles, 0), 4)     AS average_fuel_cost_per_mile
FROM routes AS rte
LEFT JOIN loads AS ld
    ON rte.route_id = ld.route_id
LEFT JOIN trips AS trp
    ON ld.load_id = trp.load_id
LEFT JOIN fuel_purchases AS fp
    ON trp.trip_id = fp.trip_id
GROUP BY
    rte.route_id,
    CONCAT(rte.origin_city, ' to ', rte.destination_city),
    rte.typical_distance_miles
ORDER BY average_fuel_cost_per_mile DESC;


-- ====================================================================================
-- SECTION 6: CUSTOMER ANALYSIS
-- Description: Analysing revenue contribution by customer type and measuring
--              service levels through on-time delivery and detention performance.
-- Tables Used: customers (cst), loads (ld), delivery_events (de)
-- ====================================================================================

-- ------------------------------------------------------------------------------------
-- Query 6a: Revenue by customer type
-- ------------------------------------------------------------------------------------

SELECT
    cst.customer_type,
    COUNT(DISTINCT cst.customer_id) AS total_customers,
    ROUND(SUM(ld.revenue), 2)       AS total_revenue,
    ROUND(AVG(ld.revenue), 2)       AS average_revenue_per_load
FROM customers AS cst
INNER JOIN loads AS ld
    ON cst.customer_id = ld.customer_id
GROUP BY cst.customer_type
ORDER BY total_revenue DESC;

-- ------------------------------------------------------------------------------------
-- Query 6b: Service levels by customer type (on-time delivery rate)
-- ------------------------------------------------------------------------------------

SELECT
    cst.customer_type,
    COUNT(de.event_id)                                                     AS total_deliveries,
    SUM(CASE WHEN de.on_time_flag = true  THEN 1 ELSE 0 END)               AS on_time_deliveries,
    SUM(CASE WHEN de.on_time_flag = false THEN 1 ELSE 0 END)               AS late_deliveries,
    ROUND(
        SUM(CASE WHEN de.on_time_flag = true THEN 1 ELSE 0 END)::NUMERIC
        / NULLIF(COUNT(de.event_id), 0) * 100, 2)                          AS on_time_pct,
    ROUND(AVG(de.detention_minutes), 2)                                    AS avg_detention_minutes
FROM customers AS cst
LEFT JOIN loads AS ld
    ON cst.customer_id = ld.customer_id
INNER JOIN delivery_events AS de
    ON ld.load_id = de.load_id
WHERE de.event_type = 'Delivery'
GROUP BY cst.customer_type
ORDER BY on_time_pct DESC;


-- ====================================================================================
-- SECTION 7: SAFETY METRICS ANALYSIS
-- Description: Analysing incident frequency, preventability, and cost by incident
--              type to identify the highest-risk areas for the fleet.
-- Tables Used: safety_incidents (si)
-- ====================================================================================

SELECT
    COALESCE(si.incident_type, 'TOTAL')                          AS incident_type,
    COUNT(si.incident_id)                                        AS incident_count,
    ROUND(COUNT(si.incident_id) * 100.0
          / (SELECT COUNT(*) FROM safety_incidents), 2)          AS pct_of_total,
    SUM(CASE WHEN si.preventable_flag = false THEN 1 ELSE 0 END) AS non_preventable,
    SUM(CASE WHEN si.preventable_flag = true  THEN 1 ELSE 0 END) AS preventable,
    ROUND(SUM(si.claim_amount), 2)                               AS total_claim_amount,
    ROUND(AVG(si.claim_amount), 2)                               AS avg_claim_per_incident
FROM safety_incidents AS si
GROUP BY ROLLUP(si.incident_type)
ORDER BY COALESCE(si.incident_type, 'TOTAL');


-- ====================================================================================
-- SECTION 8: SEASONAL PATTERNS ANALYSIS
-- Description: Tracking monthly load volume and revenue fluctuations to identify
--              peak and off-peak periods for operational planning.
-- Tables Used: loads (ld)
-- ====================================================================================
SELECT
    DATE_TRUNC('month', ld.load_date)                        AS month,
    COUNT(ld.load_id)                                        AS total_loads_per_month,
    ROUND(SUM(ld.revenue), 2)                                AS monthly_revenue,
    ROUND(AVG(ld.revenue), 2)                                AS avg_revenue
FROM loads AS ld
GROUP BY DATE_TRUNC('month', ld.load_date)
ORDER BY month;



-- ####################################################################################