# Retirement Checklist: `sp_load_order_profitability`

Companion to `legacy_sp_load_order_profitability_migration_plan.md`. That doc covered
the migration; this one covers safely turning the legacy stored procedure off once the
dbt DAG has proven itself in production.

## Status as of this checklist

- ✅ `feat/order-profitability-staging-intermediate` merged to `main`
- ✅ Prod Job (`job_id 1132295`) run `512640361` succeeded off `main` — 11 models built,
  53/53 tests + unit test passed, into `DBT_LEARN.PROD_WORKSHOP_CMOWBRAY_094C7F`
- ✅ Parity confirmed twice pre-merge (audit_helper sample + full `EXCEPT`/`EXCEPT`,
  0 row diffs across 75,000 orders)
- ⬜ Everything below

## 1. Observation window

- [ ] Decide observation window length (recommend at least one full business cycle —
  e.g. a week if the proc ran daily, a month if monthly — so you catch any
  period-boundary logic the parity check might have missed on a single snapshot)
- [ ] Enable the Prod Job's schedule (currently off; job ran on-demand only so far) —
  or confirm an orchestrator/cron is calling it on the cadence the legacy proc used
- [ ] Confirm `fct_order_profitability` is landing on schedule with fresh `loaded_at`
  timestamps for each run in the window
- [ ] Re-run the parity audit (`analyses/audit_fct_order_profitability_parity.sql`) at
  least once more mid-window against a fresh legacy proc run, to catch drift under
  real incremental data rather than the one-time backfill snapshot

## 2. Consumer check (repeat before cutting over)

- [ ] Re-confirm no views, tasks, or scheduled queries reference
  `legacy_fct_order_profitability` (checked once already during migration — re-check
  in case something new was pointed at it during the observation window)
- [ ] Re-check query history on `legacy_fct_order_profitability` for any ad hoc/BI
  traffic that showed up during the window
- [ ] If any consumers are found, repoint them to `fct_order_profitability` and confirm
  with their owners before proceeding

## 3. Sign-off

- [ ] Identify and get explicit sign-off from the observation window owner (open item
  from the migration — needs a named owner, not just "the team")
- [ ] Circulate the parity results and this checklist for final go/no-go

## 4. Decommission the legacy procedure

- [ ] Disable (don't drop yet) any schedule/task that calls
  `sp_load_order_profitability`
- [ ] `DROP PROCEDURE DBT_LEARN.DBT_WORKSHOP_CMOWBRAY_094C7F.sp_load_order_profitability()`
  — only after sign-off, and only the dev-schema copy I deployed for the audit; confirm
  whether a separate prod-schema copy of the proc exists and needs its own decommission
- [ ] Archive or drop `legacy_fct_order_profitability` (the manually-DDL'd output table
  used for the parity audit) once the window has closed and no further comparisons are
  needed
- [ ] Remove `analyses/audit_fct_order_profitability_parity.sql` from active use (keep
  it in git history for audit trail — no need to delete the file)

## 5. Post-retirement cleanup

- [ ] Update any runbooks/wikis that reference the legacy proc to point at
  `fct_order_profitability` and the new job
- [ ] Confirm `dbt-labs/audit_helper` is still needed (used elsewhere) or can be
  removed from `packages.yml` if it was only added for this migration
- [ ] Close out the migration plan doc with a final status note and link to this
  checklist
