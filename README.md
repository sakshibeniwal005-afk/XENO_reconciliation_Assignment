# XENO_reconciliation_Assessment

Take-Home: Comm-Log Send Reconciliation

Finance tracks a metric called target_base: the total number of qualifying sends for a merchant's campaigns over a period. For merchant 501, October 2026, across all Diwali campaigns, Finance says: The true target_base is 22.
You've been asked to reproduce this number from the raw data and explain any gap between it and a straightforward query.

## Result

Final target_base: **22** — matches Finance's reported number.

See `bridge.md` for the step-by-step reconciliation and `Queries.sql` for
every query used to get there.

## Files

- `bridge.md` — the reconciliation bridge: naive count through to 22, one
  row per adjustment, with the reason for each.
- `Queries.sql` — all queries in the order they were run, ending with the
  final query that outputs 22. Run against `data/comm_log.db`.
- `xeno_assignment.ipynb` — the Colab notebook with the same queries run
  step by step, with output shown at each stage.

## How to run

```bash
sqlite3 data/comm_log.db < Queries.sql
```

The last query in the file outputs `standalone_rows`, `chain_distinct_customers`,
and `target_base` (22).

## Approach, briefly

1. Started from a naive row count for merchant 501 — 30.
2. Found 4 rows under a campaign still in `approval_awaiting`, despite sends
   already being processed. Excluded rows unless the campaign is both
   `approved` and `processed` — 26.
3. Traced `parent_id` to find retry chains (some 2 levels deep) and grouped
   campaigns into families using a recursive query.
4. For real retry chains, counted each customer once (delivered anywhere in
   the chain). For the one standalone campaign, counted every row as its
   own event, since a repeated send there isn't a retry — 22.
