-- The last query (bottom of this file) outputs the final target_base = 22. See bridge.md for the narrative.
-- Run against data/comm_log.db.

-- ============================================================
-- STEP 0: Naive count -- no business rules applied
-- Result: 30
-- ============================================================
SELECT COUNT(*) AS naive_count
FROM communication_log
WHERE merchant_id = 501;


-- ============================================================
-- INVESTIGATION: what campaign status values actually occur?
-- Result: approval_awaiting/processed = 4 rows, approved/processed = 26 rows
-- ============================================================
SELECT c.creation_status, c.processing_status, COUNT(*) AS row_count
FROM communication_log cl
JOIN campaign c ON cl.communication_id = c.id
WHERE cl.merchant_id = 501
GROUP BY c.creation_status, c.processing_status;


-- ============================================================
-- STEP 1: Exclude campaigns not both approved and processed
-- Result: 26
-- ============================================================
SELECT COUNT(*) AS after_status_filter
FROM communication_log cl
JOIN campaign c ON cl.communication_id = c.id
WHERE cl.merchant_id = 501
  AND c.creation_status = 'approved'
  AND c.processing_status = 'processed';


-- ============================================================
-- INVESTIGATION: raw parent_id relationships between campaigns
-- ============================================================
SELECT id, parent_id, name
FROM campaign
WHERE merchant_id = 501
ORDER BY id;


-- ============================================================
-- INVESTIGATION: group campaigns into families via recursive CTE
-- (handles chains of any depth, e.g. 9001 -> 9002 -> 9003)
-- ============================================================
WITH RECURSIVE chain AS (
  SELECT id, parent_id, id AS root_id
  FROM campaign
  WHERE parent_id IS NULL
  UNION ALL
  SELECT c.id, c.parent_id, chain.root_id
  FROM campaign c
  JOIN chain ON c.parent_id = chain.id
)
SELECT * FROM chain
ORDER BY root_id, id;


-- ============================================================
-- INVESTIGATION: how big is each family? (chain_size = 1 -> standalone)
-- Result: root 9001 -> 4, root 9101 -> 1, root 9201 -> 2
-- ============================================================
WITH RECURSIVE chain AS (
  SELECT id, parent_id, id AS root_id
  FROM campaign
  WHERE parent_id IS NULL
  UNION ALL
  SELECT c.id, c.parent_id, chain.root_id
  FROM campaign c
  JOIN chain ON c.parent_id = chain.id
)
SELECT root_id, COUNT(*) AS chain_size
FROM chain
GROUP BY root_id;


-- ============================================================
-- INVESTIGATION: inspect eligible rows labeled with family + chain size
-- (sanity check before final aggregation -- 26 rows expected)
-- ============================================================
WITH RECURSIVE chain AS (
  SELECT id, parent_id, id AS root_id
  FROM campaign
  WHERE parent_id IS NULL
  UNION ALL
  SELECT c.id, c.parent_id, chain.root_id
  FROM campaign c
  JOIN chain ON c.parent_id = chain.id
),
chain_sizes AS (
  SELECT root_id, COUNT(*) AS chain_size
  FROM chain
  GROUP BY root_id
),
eligible_logs AS (
  SELECT cl.customer_id, cl.delivery_status, ch.root_id, cs.chain_size
  FROM communication_log cl
  JOIN campaign c ON cl.communication_id = c.id
  JOIN chain ch ON c.id = ch.id
  JOIN chain_sizes cs ON ch.root_id = cs.root_id
  WHERE cl.merchant_id = 501
    AND c.creation_status = 'approved'
    AND c.processing_status = 'processed'
)
SELECT * FROM eligible_logs
ORDER BY root_id, customer_id;


-- ============================================================
-- STEP 2 / FINAL: standalone rows counted as-is, chain rows deduped
-- to distinct customers per chain
-- Result: standalone_rows = 7, chain_distinct_customers = 15, target_base = 22
-- ============================================================
WITH RECURSIVE chain AS (
  SELECT id, parent_id, id AS root_id
  FROM campaign
  WHERE parent_id IS NULL
  UNION ALL
  SELECT c.id, c.parent_id, chain.root_id
  FROM campaign c
  JOIN chain ON c.parent_id = chain.id
),
chain_sizes AS (
  SELECT root_id, COUNT(*) AS chain_size
  FROM chain
  GROUP BY root_id
),
eligible_logs AS (
  SELECT cl.customer_id, ch.root_id, cs.chain_size
  FROM communication_log cl
  JOIN campaign c ON cl.communication_id = c.id
  JOIN chain ch ON c.id = ch.id
  JOIN chain_sizes cs ON ch.root_id = cs.root_id
  WHERE cl.merchant_id = 501
    AND c.creation_status = 'approved'
    AND c.processing_status = 'processed'
    AND cl.delivery_status = 900
)
SELECT
  (SELECT COUNT(*) FROM eligible_logs WHERE chain_size = 1) AS standalone_rows,
  (SELECT COUNT(DISTINCT root_id || '-' || customer_id) FROM eligible_logs WHERE chain_size > 1) AS chain_distinct_customers,
  (SELECT COUNT(*) FROM eligible_logs WHERE chain_size = 1)
    + (SELECT COUNT(DISTINCT root_id || '-' || customer_id) FROM eligible_logs WHERE chain_size > 1) AS target_base;
