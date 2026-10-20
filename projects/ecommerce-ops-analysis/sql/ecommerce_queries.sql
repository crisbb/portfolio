-- ============================================================
--  参考答案 · 电商取数 SQL Day 1–4
--  先自己写完再看！每条都在 sql_practice.db 上实测跑过。
--  默认 SQLite 语法；MySQL 差异写在行尾注释。
-- ============================================================

-- ---------- Day 1 ----------
-- Q1
SELECT ROUND(SUM(amount),2) AS gmv FROM orders;                 -- 56364.27
-- Q2
SELECT COUNT(*) AS n_orders FROM orders;                         -- 600
-- Q3
SELECT COUNT(DISTINCT user_id) AS buyers FROM orders;            -- 341
-- Q4
SELECT ROUND(AVG(amount),2) AS aov FROM orders;                  -- 93.94
-- Q5
SELECT ROUND(SUM(refunded)*100.0/COUNT(*),1) AS refund_rate
FROM orders;                                                     -- 8.0

-- ---------- Day 2 ----------
-- Q6  宽表行数
SELECT COUNT(*) AS n
FROM orders o
LEFT JOIN users u    ON o.user_id  = u.user_id
LEFT JOIN products p ON o.category = p.category;                 -- 600

-- Q7  分渠道 GMV 降序
SELECT channel, ROUND(SUM(amount),2) AS gmv
FROM orders
GROUP BY channel
ORDER BY gmv DESC;

-- Q8  分渠道 GMV 占比（子查询求总量）
SELECT channel,
       ROUND(SUM(amount),2) AS gmv,
       ROUND(SUM(amount)*100.0 / (SELECT SUM(amount) FROM orders),1) AS pct
FROM orders
GROUP BY channel
ORDER BY gmv DESC;                                               -- 38.8/24.7/19.3/17.2

-- ---------- Day 3 ----------
-- Q9  分品类毛利降序
SELECT o.category,
       ROUND(SUM(o.amount*(1-p.cost_rate)),2) AS gross
FROM orders o
JOIN products p ON o.category = p.category
GROUP BY o.category
ORDER BY gross DESC;                                             -- 美妆7730.38 ... 数码3035.04

-- Q10 毛利率
SELECT o.category,
       ROUND(SUM(o.amount*(1-p.cost_rate)),2) AS gross,
       ROUND(SUM(o.amount*(1-p.cost_rate))*100.0/SUM(o.amount),0) AS margin_pct
FROM orders o
JOIN products p ON o.category = p.category
GROUP BY o.category
ORDER BY gross DESC;                                             -- 60/50/45/40/28

-- Q11 留存 D1/D7/D30
--   第几天：SQLite 用 julianday 差；MySQL 改成 DATEDIFF(a.act_date,u.reg_date)
WITH day_diff AS (
  SELECT a.user_id,
         CAST(julianday(a.act_date)-julianday(u.reg_date) AS INT) AS d
  FROM activity a
  JOIN users u ON a.user_id = u.user_id
)
SELECT
  ROUND(COUNT(DISTINCT CASE WHEN d=1  THEN user_id END)*100.0
        / COUNT(DISTINCT CASE WHEN d=0 THEN user_id END),1) AS d1,
  ROUND(COUNT(DISTINCT CASE WHEN d=7  THEN user_id END)*100.0
        / COUNT(DISTINCT CASE WHEN d=0 THEN user_id END),1) AS d7,
  ROUND(COUNT(DISTINCT CASE WHEN d=30 THEN user_id END)*100.0
        / COUNT(DISTINCT CASE WHEN d=0 THEN user_id END),1) AS d30
FROM day_diff;                                                   -- 41.2 / 29.4 / 6.0

-- ---------- Day 4 ----------
-- Q12 窗口函数重做占比（分母=对分组结果再求和）
SELECT channel,
       ROUND(SUM(amount),2) AS gmv,
       ROUND(SUM(amount)*100.0 / SUM(SUM(amount)) OVER(),1) AS pct
FROM orders
GROUP BY channel
ORDER BY gmv DESC;                                               -- 38.8/24.7/19.3/17.2

-- Q13 RANK 品类毛利排名
SELECT category, gross,
       RANK() OVER (ORDER BY gross DESC) AS rk
FROM (
  SELECT o.category AS category,
         SUM(o.amount*(1-p.cost_rate)) AS gross
  FROM orders o JOIN products p ON o.category=p.category
  GROUP BY o.category
) t
ORDER BY rk;                                                     -- 美妆1 ... 数码5

-- Q14a 整体客单价 上/下半月
SELECT CASE WHEN CAST(strftime('%d',order_date) AS INT)<=15
            THEN '1_上半月' ELSE '2_下半月' END AS half,
       ROUND(AVG(amount),2) AS aov
FROM orders
GROUP BY half
ORDER BY half;                                                   -- 96.9 → 90.98
--   MySQL: 把 CAST(strftime('%d',order_date) AS INT) 换成 DAY(order_date)

-- Q14b 分渠道客单价 上/下半月（辛普森：3涨1跌）
SELECT channel,
       ROUND(AVG(CASE WHEN CAST(strftime('%d',order_date) AS INT)<=15 THEN amount END),2) AS 上半月,
       ROUND(AVG(CASE WHEN CAST(strftime('%d',order_date) AS INT)>15  THEN amount END),2) AS 下半月
FROM orders
GROUP BY channel
ORDER BY channel;
--  付费投放121.52→149.47↑ 直播带货108.52→114.76↑ 社交裂变72.6→77.16↑ 自然流量70.36→66.33↓

-- Q14c 分渠道单量占比 上/下半月（付费投放 40.7%→15.7% 腰斩）
SELECT channel,
  ROUND(SUM(CASE WHEN CAST(strftime('%d',order_date) AS INT)<=15 THEN 1 ELSE 0 END)*100.0
        / (SELECT COUNT(*) FROM orders WHERE CAST(strftime('%d',order_date) AS INT)<=15),1) AS 上占比,
  ROUND(SUM(CASE WHEN CAST(strftime('%d',order_date) AS INT)>15  THEN 1 ELSE 0 END)*100.0
        / (SELECT COUNT(*) FROM orders WHERE CAST(strftime('%d',order_date) AS INT)>15),1)  AS 下占比
FROM orders
GROUP BY channel
ORDER BY channel;
