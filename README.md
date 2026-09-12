# 📊 Comm-Log Send Reconciliation

> Reproducing Finance's `target_base` metric from raw send-log data.

## The Problem

Finance tracks a metric called **`target_base`**: the total number of
qualifying sends for a merchant's campaigns over a period.

For **merchant 501, October 2026, Diwali campaigns**, Finance says:

> **The true target_base is 22.**

The task: reproduce this number from raw data, and explain the gap between
it and a naive, straightforward query.

## ✅ Result

| Metric | Value |
|---|---|
| Naive count | 30 |
| Final `target_base` | **22** |
| Matches Finance's number? | Yes |

Full reasoning is in [`bridge.md`](./bridge.md).

## 📁 What's in this repo

| File | What it is |
|---|---|
| [`bridge.md`](./bridge.md) | The reconciliation bridge; naive count through to 22, one row per adjustment, with the reason for each |
| [`Queries.sql`](./Queries.sql) | Every query, in the order it was actually run, ending with the final query that outputs 22 |
| [`xeno_assignment.ipynb`](./xeno_assignment.ipynb) | The Colab notebook; same queries, run step by step, with live output at each stage |

## ▶️ How to run

```bash
sqlite3 data/comm_log.db < Queries.sql
```

The final query in the file returns three columns:

```
standalone_rows | chain_distinct_customers | target_base
       7         |            15            |     22
```

## 🔍 Approach, in brief

1. **Naive count**: every `communication_log` row for merchant 501, no business rules applied → **30**
2. **Approval/processing filter**: found 4 rows under a campaign still `approval_awaiting` despite already being `processed`; excluded anything not both `approved` and `processed` → **26**
3. **Retry-chain detection**: traced `parent_id` links (some chains 2 levels deep) and grouped campaigns into families using a recursive query
4. **Chain-aware counting**: for real retry chains, counted each customer once (delivered anywhere in the chain); for the one standalone campaign, counted every row as its own event, since a repeat there isn't a retry → **22**

## 💡 What surprised me

Two things stood out during the investigation. A campaign (9004) had already
been processed and delivered to 4 customers despite still sitting in
`approval_awaiting`: the send pipeline had clearly run ahead of the approval
workflow. Separately, a customer (C20) appeared twice under a standalone
campaign 10 days apart; my first instinct was to treat it as a duplicate, but
testing it showed de-duping it would drop the final number to 21: confirming
it was two genuinely separate events, not a data error.
