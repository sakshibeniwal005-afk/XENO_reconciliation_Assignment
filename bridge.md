# Reconciliation Bridge

Goal: match Finance's target_base of 22, for merchant 501's Diwali campaigns in Oct 2026.

| Step | Description | Result | Reason |
|---|---|---|---|
| 0 | Naive count of communication_log rows for merchant 501, no filters | 30 | this is what you get if you just count rows without knowing anything about the business rules |
| 1 | Before touching the query, grouped by creation_status and processing_status just to see what values show up in the data | 30, no change | found 4 rows sitting under campaign 9004, which is still `approval_awaiting` even though processing_status already says `processed`. So messages went out before the campaign was technically approved |
| 2 | Excluded rows where the campaign isn't both approved and processed | 26 | README says a campaign only counts once it's cleared approval AND finished processing. 9004 fails that even though real sends happened under it |
| 3 | Checked parent_id across campaigns to see which ones are retries of each other. Some chains are 2 levels deep (9001 to 9002 to 9003), so wrote a recursive query to group them into families | 26, no change | needed to know which rows are really the same communication being retried vs. actually separate campaigns, before I could decide how to count them(family = a campaign plus everything that retries off it) |
| 4 | For real retry chains, counted each customer once if they got delivered anywhere in the chain. For the one standalone campaign (9101), counted every row separately, even C20 who shows up twice | 22 | a chain = one message getting re-attempted, so someone shouldn't count 3 times just because they failed twice before it went through. 9101 has no chain, so C20's two sends (10 days apart) are genuinely two different events, not the same thing retried. tested this: if I dedupe C20 the same way I dedupe a chain, I get 21, not 22 |
| final | | 22 | matches Finance's reported target_base |

## breakdown
- 9101: 7 (C20 x2, C21-C25)
- 9001 family: 10 distinct customers (C1-C10)
- 9201 family: 5 distinct customers (D1-D5)
- 7 + 10 + 5 = 22


